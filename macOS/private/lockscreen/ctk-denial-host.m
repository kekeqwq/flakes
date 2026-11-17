#import "ctk-denial-common.h"
#import <LocalAuthentication/LocalAuthentication.h>
#include <stdio.h>
#include <string.h>
#if defined(FLAKES_FIDO_PROBE) || defined(FLAKES_SE_PROBE)
#import "ctk-lock-state.h"
#endif

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        setbuf(stdout, NULL);
#if defined(FLAKES_FIDO_PROBE) || defined(FLAKES_SE_PROBE)
        if (argc == 2 && strcmp(argv[1], "--gate-check") == 0) {
            puts(ProbeLockDiagnostic().UTF8String);
            puts(ProbeGlobalLockDiagnostic().UTF8String);
            printf("{\"native_locked_gate\":%s,\"authentication_started\":false}\n", ProbeNativeLocked() ? "true" : "false");
            return 0;
        }
#endif
        TKTokenDriverConfiguration *driver = TKTokenDriverConfiguration.driverConfigurations[ProbeDriverID];
        printf("{\"configuration_visible\":%s,\"existing_instances\":%lu}\n",
               driver ? "true" : "false", (unsigned long)driver.tokenConfigurations.count);
        if (!driver) return 3;
        if (argc == 2 && strcmp(argv[1], "--cleanup-own-fixture") == 0) {
            NSDictionary *snapshots = driver.tokenConfigurations;
            for (NSString *instance in snapshots) {
                NSArray *items = [snapshots[instance] keychainItems];
                if (![instance hasPrefix:@"nonlogin-denial-"] || items.count != 1 ||
                    ![items[0] isKindOfClass:TKTokenKeychainKey.class]) return 9;
                TKTokenKeychainKey *key = items[0];
                if (key.suitableForLogin || key.canDecrypt || key.canPerformKeyExchange ||
                    ![key.objectID isEqual:ProbeObjectID] || ![key.publicKeyData isEqual:ProbePublicPoint()]) return 9;
            }
            for (NSString *instance in snapshots) [driver removeTokenConfigurationForTokenInstanceID:instance];
            printf("{\"own_instances_after_recovery\":%lu}\n", (unsigned long)driver.tokenConfigurations.count);
            return driver.tokenConfigurations.count == 0 ? 0 : 10;
        }
        if (driver.tokenConfigurations.count) return 4;
        BOOL dispatch = argc == 2 && strcmp(argv[1], "--dispatch-denial") == 0;
#ifdef FLAKES_FIDO_PROBE
#ifdef FLAKES_BRIDGE_PROBE
        const char *hardwareFlag = "--dispatch-locked-bridge";
        BOOL bridgeDenial = argc == 2 && strcmp(argv[1], "--dispatch-bridge-denial") == 0;
        if (bridgeDenial) dispatch = YES;
#else
        const char *hardwareFlag = "--dispatch-locked-fido";
#endif
        BOOL hardwareOptIn = argc == 2 && strcmp(argv[1], hardwareFlag) == 0;
        if (hardwareOptIn) {
            if (ProbeNativeLocked()) { puts("Start unlocked; reference preparation must precede lock."); return 12; }
            puts("Preparing non-login reference while unlocked. Do NOT lock until READY_TO_LOCK.");
            dispatch = YES;
        }
#elif defined(FLAKES_SE_PROBE)
        BOOL seOptIn = argc == 2 && strcmp(argv[1], "--dispatch-locked-se") == 0;
        if (seOptIn) {
            if (ProbeNativeLocked()) { puts("Start unlocked for temporary enclave-key creation."); return 12; }
            puts("Preparing non-login Secure Enclave test; do NOT lock until READY_TO_LOCK. No YubiKey touch needed.");
            dispatch = YES;
        }
#endif
        if (!dispatch) return argc == 1 ? 0 : 2;
        NSString *instance = [@"nonlogin-denial-" stringByAppendingString:NSUUID.UUID.UUIDString];
        TKTokenKeychainKey *item = ProbeItem(instance);
        if (!item || item.suitableForLogin) return 9;
        int outcome = 7;
        LAContext *context = [[LAContext alloc] init];
        context.interactionNotAllowed = YES; // No PIN, password or biometric dialog.
        SecKeyRef ref = NULL;
        TKTokenWatcher *watcher = [[TKTokenWatcher alloc] init];
        NSString *tokenID = nil;
        @try {
            TKTokenConfiguration *configuration = [driver addTokenConfigurationForTokenInstanceID:instance];
#ifdef FLAKES_FIDO_PROBE
#ifdef FLAKES_BRIDGE_PROBE
            if (bridgeDenial) configuration.configurationData = ProbeBridgeDeniedData();
            else
#endif
            if (hardwareOptIn) configuration.configurationData = ProbeHardwareOptInData();
#elif defined(FLAKES_SE_PROBE)
            if (seOptIn) configuration.configurationData = ProbeSEOptInData();
#endif
            configuration.keychainItems = @[item]; // No certificate or real key material.
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:8.0];
            while (!tokenID && deadline.timeIntervalSinceNow > 0) {
                for (NSString *candidate in watcher.tokenIDs) {
                    if ([candidate hasPrefix:ProbeDriverID] && [candidate containsString:instance]) {
                        tokenID = candidate; break;
                    }
                }
                if (!tokenID) [NSThread sleepForTimeInterval:0.1];
            }
            printf("{\"nonlogin_proxy_published\":%s,\"certificate_count\":0,\"proxy_private_material_created\":false}\n",
                   tokenID ? "true" : "false");
            if (tokenID) {
                NSDictionary *query = @{
                    (__bridge id)kSecClass: (__bridge id)kSecClassKey,
                    (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPrivate,
                    (__bridge id)kSecAttrApplicationLabel: item.publicKeyHash,
                    (__bridge id)kSecAttrTokenID: tokenID,
                    (__bridge id)kSecReturnRef: @YES,
                    (__bridge id)kSecUseDataProtectionKeychain: @YES,
                    (__bridge id)kSecUseAuthenticationContext: context,
                };
                OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&ref);
                printf("{\"own_key_lookup_status\":%d}\n", (int)status);
                if (status == errSecSuccess && ref) {
                    NSDictionary *attributes = CFBridgingRelease(SecKeyCopyAttributes(ref));
                    if (![attributes[(__bridge id)kSecAttrTokenID] isEqual:tokenID]) {
                        outcome = 9; // Never operate on an unrelated key.
                    } else {
                        NSData *message = [@"public denial-only test message" dataUsingEncoding:NSUTF8StringEncoding];
                        outcome = 0;
#ifdef FLAKES_FIDO_PROBE
                        if (hardwareOptIn) {
                            puts("READY_TO_LOCK: Ctrl-Cmd-Q within 90s. Touch ONLY when Key flashes. No unlock is granted; afterward use native Touch ID/password.");
                            double deadline = NSProcessInfo.processInfo.systemUptime + 90;
                            while (!ProbeNativeLocked() && NSProcessInfo.processInfo.systemUptime < deadline)
                                [NSThread sleepForTimeInterval:0.1];
                            printf("{\"native_lock_confirmed_before_request\":%s}\n", ProbeNativeLocked() ? "true" : "false");
                            if (!ProbeNativeLocked()) outcome = 12;
                        }
                        const int attempts = 1; // One physical touch request, never a second cached attempt.
#elif defined(FLAKES_SE_PROBE)
                        if (seOptIn) {
                            puts("READY_TO_LOCK: Ctrl-Cmd-Q within 90s. NO YubiKey touch. Testing enclave primitives only; recover with native Touch ID/password.");
                            double deadline = NSProcessInfo.processInfo.systemUptime + 90;
                            while (!ProbeNativeLocked() && NSProcessInfo.processInfo.systemUptime < deadline)
                                [NSThread sleepForTimeInterval:0.1];
                            printf("{\"native_lock_confirmed_before_request\":%s}\n", ProbeNativeLocked() ? "true" : "false");
                            if (!ProbeNativeLocked()) outcome = 12;
                        }
                        const int attempts = 1;
#else
                        const int attempts = 2;
#endif
                        for (int attempt = 1; attempt <= attempts && outcome == 0; attempt++) {
                            CFErrorRef error = NULL;
                            NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;
                            CFDataRef signature = SecKeyCreateSignature(ref, kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                                                      (__bridge CFDataRef)message, &error);
                            printf("{\"attempt\":%d,\"signature_produced\":%s,\"error_code\":%ld,\"elapsed_ms\":%.3f}\n",
                                   attempt, signature ? "true" : "false", error ? (long)CFErrorGetCode(error) : 0L,
                                   (NSDate.timeIntervalSinceReferenceDate - start) * 1000);
                            if (signature) { outcome = 8; CFRelease(signature); }
                            if (error) CFRelease(error);
                            if (outcome) break;
                        }
                    }
                }
            } else outcome = 6;
        } @finally {
            if (ref) CFRelease(ref);
            [context invalidate];
            [driver removeTokenConfigurationForTokenInstanceID:instance];
            NSDate *retirement = [NSDate dateWithTimeIntervalSinceNow:2.0];
            while (tokenID && [watcher.tokenIDs containsObject:tokenID] && retirement.timeIntervalSinceNow > 0)
                [NSThread sleepForTimeInterval:0.05];
            BOOL stillAdvertised = tokenID && [watcher.tokenIDs containsObject:tokenID];
            printf("{\"own_token_advertised_after_cleanup\":%s}\n", stillAdvertised ? "true" : "false");
            if (stillAdvertised) outcome = 10;
        }
        unsigned long remaining = (unsigned long)driver.tokenConfigurations.count;
        printf("{\"own_instances_after_cleanup\":%lu,\"test_exit\":%d}\n", remaining, outcome);
        return remaining ? 10 : outcome;
    }
}
