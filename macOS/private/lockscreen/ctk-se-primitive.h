// Owner-approved, ephemeral Secure Enclave experiment. No certificate/account identity.
#import "ctk-lock-state.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>
#import <dispatch/dispatch.h>
#include <stdio.h>

static void SEError(const char *stage, CFErrorRef error) {
    char event[120];
    snprintf(event, sizeof(event), "%s_error_%ld", stage, error ? (long)CFErrorGetCode(error) : 0L);
    Trace(event); // Codes only; never key blobs, signatures, exchange secrets or context objects.
}
@interface FlakesSEPrimitive : NSObject {
    SecKeyRef _key;
    NSLock *_mutex;
    LAContext *_context;
    NSData *_tag;
}
- (BOOL)ready;
- (BOOL)runLockedTest;
- (void)invalidate;
@end
@implementation FlakesSEPrimitive
- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _mutex = [[NSLock alloc] init];
    if (!ProbeConsoleUnlocked()) { Trace("se_creation_gate_not_unlocked"); return self; }
    CFErrorRef error = NULL;
    SecAccessControlRef access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, kSecAccessControlPrivateKeyUsage, &error);
    if (!access) { SEError("se_access_control", error); if (error) CFRelease(error); return self; }
    LAContext *context = [[LAContext alloc] init];
    context.interactionNotAllowed = YES;
    NSData *tag = [[@"com.keke.flakes.nonlogin-se-test." stringByAppendingString:NSUUID.UUID.UUIDString]
                   dataUsingEncoding:NSUTF8StringEncoding];
    _tag = tag;
    NSDictionary *parameters = @{
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrKeySizeInBits: @256,
        (__bridge id)kSecAttrTokenID: (__bridge id)kSecAttrTokenIDSecureEnclave,
        (__bridge id)kSecUseDataProtectionKeychain: @YES,
        (__bridge id)kSecUseAuthenticationContext: context,
        (__bridge id)kSecPrivateKeyAttrs: @{
            (__bridge id)kSecAttrIsPermanent: @NO,
            (__bridge id)kSecAttrApplicationTag: tag,
            (__bridge id)kSecAttrAccessControl: (__bridge id)access,
        },
    };
    _key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)parameters, &error);
    CFRelease(access);
    if (!_key) { [context invalidate]; SEError("se_create", error); if (error) CFRelease(error); return self; }
    _context = context;
    if (error) CFRelease(error);
    NSDictionary *attributes = CFBridgingRelease(SecKeyCopyAttributes(_key));
    BOOL enclave = [attributes[(__bridge id)kSecAttrTokenID] isEqual:(__bridge id)kSecAttrTokenIDSecureEnclave];
    BOOL persistent = [attributes[(__bridge id)kSecAttrIsPermanent] boolValue];
    char attrEvent[160];
    snprintf(attrEvent, sizeof(attrEvent), "se_attributes enclave=%d token_id_present=%d reported_permanent=%d extractable=%d",
        enclave, attributes[(__bridge id)kSecAttrTokenID] != nil, persistent,
        [attributes[(__bridge id)kSecAttrIsExtractable] boolValue]);
    Trace(attrEvent);
    NSDictionary *query = @{
        (__bridge id)kSecClass:(__bridge id)kSecClassKey,
        (__bridge id)kSecAttrApplicationTag:tag,
        (__bridge id)kSecAttrTokenID:(__bridge id)kSecAttrTokenIDSecureEnclave,
        (__bridge id)kSecUseDataProtectionKeychain:@YES,
        (__bridge id)kSecUseAuthenticationContext:context,
    };
    OSStatus lookup = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
    char itemEvent[100];
    snprintf(itemEvent, sizeof(itemEvent), "se_own_tag_keychain_lookup_status_%d", (int)lookup);
    Trace(itemEvent);
    if (lookup == errSecSuccess) {
        OSStatus deleted = SecItemDelete((__bridge CFDictionaryRef)query);
        snprintf(itemEvent, sizeof(itemEvent), "se_UNEXPECTED_persistent_own_tag_cleanup_status_%d", (int)deleted);
        Trace(itemEvent);
    }
    // SecCTKKeyCopyAttributeDictionary marks ALL token keys permanent (@YES),
    // independently of keychain insertion. Require the requested nonpersistent
    // creation plus an actual no-item lookup for this unique test tag instead.
    if (!enclave || [attributes[(__bridge id)kSecAttrIsExtractable] boolValue] || lookup != errSecItemNotFound) {
        Trace("se_attributes_REJECTED_no_software_fallback");
        [self invalidate]; return self;
    }
    Trace("se_ephemeral_enclave_key_created_no_private_export");
    // If the client disappears before its callback, bound this test key's lifetime.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ [self invalidate]; });
    return self;
}
- (BOOL)ready {
    [_mutex lock]; BOOL result = _key != NULL; [_mutex unlock]; return result;
}
- (void)invalidate {
    [_mutex lock]; SecKeyRef key = _key; _key = NULL;
    LAContext *context = _context; _context = nil; [_mutex unlock];
    [context invalidate];
    if (key) {
        CFRelease(key);
        Trace("se_test_key_reference_released");
        LAContext *check = [[LAContext alloc] init];
        check.interactionNotAllowed = YES;
        NSDictionary *query = @{
            (__bridge id)kSecClass:(__bridge id)kSecClassKey,
            (__bridge id)kSecAttrApplicationTag:_tag,
            (__bridge id)kSecAttrTokenID:(__bridge id)kSecAttrTokenIDSecureEnclave,
            (__bridge id)kSecUseDataProtectionKeychain:@YES,
            (__bridge id)kSecUseAuthenticationContext:check,
        };
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
        char event[100];
        snprintf(event, sizeof(event), "se_released_own_tag_lookup_status_%d", (int)status);
        Trace(event);
        [check invalidate];
    }
}
- (void)dealloc { [_context invalidate]; if (_key) CFRelease(_key); }
- (BOOL)runLockedTest {
    if (!ProbeNativeLocked()) { Trace("se_operation_gate_CLOSED"); return NO; }
    [_mutex lock]; SecKeyRef key = _key ? (SecKeyRef)CFRetain(_key) : NULL; [_mutex unlock];
    if (!key) { Trace("se_key_not_available_no_fallback"); return NO; }
    BOOL success = NO;
    SecKeyRef publicKey = NULL, peer = NULL;
    CFDataRef signature = NULL, raw = NULL, repeated = NULL, kdf = NULL;
    CFErrorRef error = NULL;
    @try {
        publicKey = SecKeyCopyPublicKey(key);
        if (!publicKey) { Trace("se_public_key_unavailable"); return NO; }
        NSData *message = [@"non-login Secure Enclave primitive test" dataUsingEncoding:NSUTF8StringEncoding];
        signature = SecKeyCreateSignature(key, kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                         (__bridge CFDataRef)message, &error);
        if (!signature) { SEError("se_sign", error); return NO; }
        if (error) { CFRelease(error); error = NULL; }
        BOOL valid = SecKeyVerifySignature(publicKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                           (__bridge CFDataRef)message, signature, &error);
        if (!valid) { SEError("se_self_verify", error); return NO; }
        if (error) { CFRelease(error); error = NULL; }
        NSData *wrong = [@"different message" dataUsingEncoding:NSUTF8StringEncoding];
        BOOL wrongAccepted = SecKeyVerifySignature(publicKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                                    (__bridge CFDataRef)wrong, signature, &error);
        if (error) { CFRelease(error); error = NULL; }
        if (wrongAccepted) { Trace("se_wrong_message_UNEXPECTED_success"); return NO; }
        Trace("se_sign_and_self_verify_PASSED_no_signature_export");
        NSDictionary *pubAttrs = @{
            (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
            (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPublic,
            (__bridge id)kSecAttrKeySizeInBits: @256,
        };
        // Public-only fixed curve point: no peer private key is generated.
        peer = SecKeyCreateWithData((__bridge CFDataRef)ProbePublicPoint(), (__bridge CFDictionaryRef)pubAttrs, &error);
        if (!peer) { SEError("se_peer_public", error); return NO; }
        if (error) { CFRelease(error); error = NULL; }
        if (!ProbeNativeLocked()) { Trace("se_lock_lost_before_ecdh"); return NO; }
        raw = SecKeyCopyKeyExchangeResult(key, kSecKeyAlgorithmECDHKeyExchangeStandard, peer,
                                         (__bridge CFDictionaryRef)@{}, &error);
        if (!raw || CFDataGetLength(raw) != 32) { SEError("se_ecdh", error); return NO; }
        if (error) { CFRelease(error); error = NULL; }
        if (!ProbeNativeLocked()) { Trace("se_lock_lost_before_ecdh_repeat"); return NO; }
        repeated = SecKeyCopyKeyExchangeResult(key, kSecKeyAlgorithmECDHKeyExchangeStandard, peer,
                                              (__bridge CFDictionaryRef)@{}, &error);
        if (!repeated || !CFEqual(raw, repeated)) { SEError("se_ecdh_repeat", error); return NO; }
        if (error) { CFRelease(error); error = NULL; }
        if (!ProbeNativeLocked()) { Trace("se_lock_lost_before_kdf"); return NO; }
        kdf = SecKeyCopyKeyExchangeResult(key, kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA256, peer,
            (__bridge CFDictionaryRef)@{(__bridge id)kSecKeyKeyExchangeParameterRequestedSize:@32}, &error);
        if (!kdf || CFDataGetLength(kdf) != 32) { SEError("se_ecdh_kdf", error); return NO; }
        if (!ProbeNativeLocked()) { Trace("se_lock_lost_result_REJECTED"); return NO; }
        Trace("se_ecdh_raw_and_kdf_PASSED_no_secret_export");
        success = YES;
        return success;
    } @finally {
        if (error) CFRelease(error);
        if (signature) CFRelease(signature);
        if (raw) CFRelease(raw);
        if (repeated) CFRelease(repeated);
        if (kdf) CFRelease(kdf);
        if (peer) CFRelease(peer);
        if (publicKey) CFRelease(publicKey);
        CFRelease(key);
        [self invalidate];
    }
}
@end
static FlakesSEPrimitive *ProbeSEKey;
static NSString *ProbeSEInstance;
