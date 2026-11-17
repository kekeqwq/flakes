// Consented storage-only experiment. No certificate, account pairing, HID or signing.
#import "ctk-lock-state.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#include <stdio.h>
#include <string.h>

static void Report(NSString *stage, NSInteger status, NSDictionary *extra) {
    NSMutableDictionary *row = [@{@"stage":stage, @"status":@(status), @"pid":@(getpid())} mutableCopy];
    if (extra) [row addEntriesFromDictionary:extra];
    NSData *json = [NSJSONSerialization dataWithJSONObject:row options:0 error:NULL];
    fwrite(json.bytes, 1, json.length, stdout); putchar('\n'); fflush(stdout);
}
static NSString *PublicHash(SecKeyRef key) {
    NSDictionary *a = CFBridgingRelease(SecKeyCopyAttributes(key));
    BOOL enclave = [a[(__bridge id)kSecAttrTokenID] isEqual:(__bridge id)kSecAttrTokenIDSecureEnclave];
    BOOL privateKey = [a[(__bridge id)kSecAttrKeyClass] isEqual:(__bridge id)kSecAttrKeyClassPrivate];
    if (!enclave || !privateKey || [a[(__bridge id)kSecAttrIsExtractable] boolValue]) {
        Report(@"hardware_attributes_rejected_no_fallback", -1, nil); return nil;
    }
    SecKeyRef pub = SecKeyCopyPublicKey(key);
    if (!pub) return nil;
    NSDictionary *p = CFBridgingRelease(SecKeyCopyAttributes(pub));
    if (![p[(__bridge id)kSecAttrKeyClass] isEqual:(__bridge id)kSecAttrKeyClassPublic]) {
        CFRelease(pub); return nil;
    }
    // Export ONLY the public point. No private representation API is invoked.
    CFErrorRef error = NULL;
    NSData *point = CFBridgingRelease(SecKeyCopyExternalRepresentation(pub, &error));
    CFRelease(pub);
    if (error) { Report(@"public_encoding_error", CFErrorGetCode(error), nil); CFRelease(error); }
    if (point.length != 65) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(point.bytes, (CC_LONG)point.length, digest);
    NSMutableString *hash = [NSMutableString string];
    for (size_t i = 0; i < sizeof(digest); i++) [hash appendFormat:@"%02x", digest[i]];
    return hash;
}
int main(int argc, const char *argv[]) {
    (void)argv;
    @autoreleasepool {
        if (argc != 1 || getuid() == 0 || geteuid() != getuid()) return 2;
        unsigned char input[4097]; size_t length = 0;
        ssize_t n;
        while (length < sizeof(input) && (n = read(STDIN_FILENO, input + length, sizeof(input) - length)) > 0)
            length += (size_t)n;
        if (!length || length >= sizeof(input)) return 2;
        id request = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:input length:length] options:0 error:NULL];
        if (![request isKindOfClass:NSDictionary.class]) return 2;
        NSString *operation = request[@"operation"], *tag = request[@"tag"];
        NSString *prefix = [NSString stringWithFormat:@"com.keke.flakes.se-store-test.v1.%u.", getuid()];
        if (![tag isKindOfClass:NSString.class] || ![tag hasPrefix:prefix]) return 2;
        NSString *uuid = [tag substringFromIndex:prefix.length];
        if (![[[NSUUID alloc] initWithUUIDString:uuid].UUIDString isEqual:uuid]) return 2;
        if (![@[@"create", @"read", @"delete", @"inspect"] containsObject:operation]) return 2;
        if (([operation isEqual:@"create"] || [operation isEqual:@"read"]) && !ProbeConsoleUnlocked()) {
            Report(@"unlocked_console_required", -1, nil); return 3;
        }
        LAContext *context = [[LAContext alloc] init]; context.interactionNotAllowed = YES;
        NSDictionary *query = @{
            (__bridge id)kSecClass:(__bridge id)kSecClassKey,
            (__bridge id)kSecAttrApplicationTag:[tag dataUsingEncoding:NSUTF8StringEncoding],
            (__bridge id)kSecUseDataProtectionKeychain:@YES,
            (__bridge id)kSecUseAuthenticationContext:context,
        };
        SecKeyRef key = NULL;
        CFErrorRef error = NULL;
        int result = 8;
        @try {
            if ([operation isEqual:@"delete"]) {
                OSStatus deleted = SecItemDelete((__bridge CFDictionaryRef)query);
                Report(@"own_tag_delete", deleted, nil);
                OSStatus after = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
                Report(@"own_tag_after_delete", after, nil);
                return (deleted == errSecSuccess || deleted == errSecItemNotFound) && after == errSecItemNotFound ? 0 : 9;
            }
            OSStatus before = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
            Report(@"own_tag_lookup", before, nil);
            if ([operation isEqual:@"inspect"]) return before == errSecItemNotFound ? 0 : 8;
            if ([operation isEqual:@"create"]) {
                if (before != errSecItemNotFound) return 8; // Never replace an existing tag.
                SecAccessControlRef access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                    kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, kSecAccessControlPrivateKeyUsage, &error);
                if (!access) { Report(@"access_control_error", error ? CFErrorGetCode(error) : 0, nil); return 8; }
                NSDictionary *parameters = @{
                    (__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
                    (__bridge id)kSecAttrKeySizeInBits:@256,
                    (__bridge id)kSecAttrTokenID:(__bridge id)kSecAttrTokenIDSecureEnclave,
                    (__bridge id)kSecUseDataProtectionKeychain:@YES,
                    (__bridge id)kSecUseAuthenticationContext:context,
                    (__bridge id)kSecPrivateKeyAttrs:@{
                        (__bridge id)kSecAttrIsPermanent:@YES,
                        (__bridge id)kSecAttrApplicationTag:query[(__bridge id)kSecAttrApplicationTag],
                        (__bridge id)kSecAttrLabel:@"Flakes disposable NON-LOGIN SE storage test",
                        (__bridge id)kSecAttrAccessControl:(__bridge id)access,
                    },
                    (__bridge id)kSecPublicKeyAttrs:@{(__bridge id)kSecAttrIsPermanent:@NO},
                };
                key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)parameters, &error);
                CFRelease(access);
                if (!key) { Report(@"persistent_create_error", error ? CFErrorGetCode(error) : 0, nil); return 8; }
                Report(@"persistent_create_returned_key", 0, nil);
            } else {
                NSMutableDictionary *lookup = [query mutableCopy];
                lookup[(__bridge id)kSecAttrKeyClass] = (__bridge id)kSecAttrKeyClassPrivate;
                lookup[(__bridge id)kSecAttrTokenID] = (__bridge id)kSecAttrTokenIDSecureEnclave;
                lookup[(__bridge id)kSecReturnRef] = @YES;
                OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)lookup, (CFTypeRef *)&key);
                Report(@"separate_process_reopen", status, nil);
                if (status != errSecSuccess || !key) return 8;
            }
            NSString *hash = PublicHash(key);
            if (!hash) return 8;
            OSStatus stored = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
            Report(@"own_tag_stored_lookup", stored, nil);
            if (stored != errSecSuccess) return 8;
            if ([operation isEqual:@"read"] && ![hash isEqual:request[@"public_sha256"]]) {
                Report(@"public_fingerprint_mismatch", -1, nil); return 8;
            }
            Report([operation isEqual:@"create"] ? @"created_hardware_key" : @"reopened_same_hardware_key",
                   0, @{@"public_sha256":hash, @"private_exported":@NO, @"signing_attempted":@NO});
            result = 0;
        } @finally {
            if (key) { CFRelease(key); Report(@"opaque_reference_released", 0, nil); }
            if (error) CFRelease(error);
            [context invalidate];
        }
        return result;
    }
}
