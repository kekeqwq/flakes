// FIDO signature verification only; no PAM service chain, enrollment or native signing.
#import "ctk-lock-state.h"
#import <os/log.h>
#include <fido.h>
#include <fido/es256.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static const char *RP = "pam://keke-flakes";
static NSArray<NSDictionary *> *ReadWhitelist(NSString *path) {
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!text || error || text.length > 32768 || ![text hasSuffix:@"\n"]) return nil;
    NSString *line = [text substringToIndex:text.length - 1];
    if ([line containsString:@"\n"] || [line containsString:@"\r"]) return nil;
    NSArray *parts = [line componentsSeparatedByString:@":"];
    if (parts.count < 2 || parts.count > 17 || ![parts[0] isEqual:@"keke"]) return nil;
    NSMutableArray *keys = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSUInteger i = 1; i < parts.count; i++) {
        NSArray *fields = [parts[i] componentsSeparatedByString:@","];
        if (fields.count != 4 || ![fields[2] isEqual:@"es256"] || ![fields[3] isEqual:@"+presence"]) return nil;
        NSData *idData = [[NSData alloc] initWithBase64EncodedString:fields[0] options:0];
        NSData *pubData = [[NSData alloc] initWithBase64EncodedString:fields[1] options:0];
        if (idData.length == 0 || idData.length > 1024 || pubData.length != 64 || [seen containsObject:idData]) return nil;
        // Canonical public map only; do not accept decoder-normalized aliases.
        if (![[idData base64EncodedStringWithOptions:0] isEqual:fields[0]] ||
            ![[pubData base64EncodedStringWithOptions:0] isEqual:fields[1]]) return nil;
        es256_pk_t *pk = es256_pk_new();
        int result = pk ? es256_pk_from_ptr(pk, pubData.bytes, pubData.length) : FIDO_ERR_INTERNAL;
        es256_pk_free(&pk);
        if (result != FIDO_OK) return nil;
        [seen addObject:idData];
        [keys addObject:@{@"id":idData, @"public":pubData}];
    }
    return keys;
}

static fido_assert_t *PrepareAssertion(NSData *credential, BOOL presence, BOOL supportsUV) {
    unsigned char nonce[32];
    arc4random_buf(nonce, sizeof(nonce));
    fido_assert_t *assertion = fido_assert_new();
    if (!assertion) return NULL;
    if (fido_assert_set_rp(assertion, RP) != FIDO_OK ||
        fido_assert_set_clientdata_hash(assertion, nonce, sizeof(nonce)) != FIDO_OK ||
        fido_assert_allow_cred(assertion, credential.bytes, credential.length) != FIDO_OK ||
        fido_assert_set_up(assertion, presence ? FIDO_OPT_TRUE : FIDO_OPT_FALSE) != FIDO_OK ||
        fido_assert_set_uv(assertion, presence && supportsUV ? FIDO_OPT_FALSE : FIDO_OPT_OMIT) != FIDO_OK) {
        fido_assert_free(&assertion);
    }
    return assertion;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        setbuf(stdout, NULL);
        if (argc == 2 && strcmp(argv[1], "--gate-check") == 0) {
            printf("{\"native_locked_gate\":%s,\"authentication_started\":false}\n", ProbeNativeLocked() ? "true" : "false");
            return 0;
        }
        BOOL selfcheck = argc == 3 && strcmp(argv[1], "--self-check") == 0;
        if (!selfcheck && !ProbeNativeLocked()) return 6; // Before any HID operation.
        if (argc != 3 || (!selfcheck && strcmp(argv[1], "--verify") != 0)) return 2;
        NSArray *keys = ReadWhitelist([NSString stringWithUTF8String:argv[2]]);
        if (!keys) { os_log(OS_LOG_DEFAULT, "flakes_fido_whitelist_REJECTED"); return 8; }
        fido_init(0); // No debug output or callbacks accepting secrets.
        if (selfcheck) {
            // Validate key import, fixed RP/options and fresh nonce allocation; no devices enumerated.
            for (NSDictionary *key in keys) {
                for (int uv = 0; uv <= 1; uv++) {
                    fido_assert_t *assertion = PrepareAssertion(key[@"id"], YES, uv);
                    if (!assertion) return 8;
                    fido_assert_free(&assertion);
                }
            }
            os_log(OS_LOG_DEFAULT, "flakes_fido_selfcheck_PASSED_no_device_access keys=%{public}lu", (unsigned long)keys.count);
            return 0;
        }
        if (!ProbeNativeLocked()) return 6;
        size_t count = 0;
        fido_dev_info_t *devices = fido_dev_info_new(64);
        if (!devices) return 8;
        int enumeration = fido_dev_info_manifest(devices, 64, &count);
        BOOL verified = NO;
        os_log(OS_LOG_DEFAULT, "flakes_fido_enumeration_result=%{public}d count=%{public}lu", enumeration, (unsigned long)count);
        if (enumeration == FIDO_OK) {
            for (size_t i = 0; i < count && !verified; i++) {
                if (!ProbeNativeLocked()) break;
                fido_dev_t *device = fido_dev_new();
                if (!device) continue;
                fido_dev_set_timeout(device, 12000);
                const char *path = fido_dev_info_path(fido_dev_info_ptr(devices, i));
                int opened = path ? fido_dev_open(device, path) : FIDO_ERR_INTERNAL;
                if (opened == FIDO_OK) {
                    BOOL supportsUV = fido_dev_supports_uv(device);
                    os_log(OS_LOG_DEFAULT, "flakes_fido_builtin_uv_supported=%{public}d actual_uv_option_omitted=%{public}d", supportsUV, !supportsUV);
                    for (NSDictionary *key in keys) {
                        if (!ProbeNativeLocked()) break;
                        // Same no-touch discovery convention as pam_u2f: CTAP2
                        // success or CTAP1 UP_REQUIRED locates a candidate only.
                        fido_assert_t *detect = PrepareAssertion(key[@"id"], NO, supportsUV);
                        int found = detect ? fido_dev_get_assert(device, detect, NULL) : FIDO_ERR_INTERNAL;
                        BOOL candidate = (fido_dev_is_fido2(device) && found == FIDO_OK) ||
                            (!fido_dev_is_fido2(device) && found == FIDO_ERR_USER_PRESENCE_REQUIRED);
                        fido_assert_free(&detect);
                        if (!candidate || !ProbeNativeLocked()) continue;
                        // Detection never authorizes. Fresh nonce and required UP
                        // for the actual cryptographically verified assertion.
                        fido_assert_t *assertion = PrepareAssertion(key[@"id"], YES, supportsUV);
                        es256_pk_t *pk = es256_pk_new();
                        NSData *pub = key[@"public"];
                        if (!assertion || !pk || es256_pk_from_ptr(pk, pub.bytes, pub.length) != FIDO_OK) {
                            fido_assert_free(&assertion); es256_pk_free(&pk); continue;
                        }
                        os_log(OS_LOG_DEFAULT, "flakes_fido_registered_credential_request_started_no_pin");
                        // NULL PIN: no prompt, guess, PIN change or fallback to another factor.
                        int result = fido_dev_get_assert(device, assertion, NULL);
                        BOOL attempted = result == FIDO_OK && fido_assert_count(assertion) == 1;
                        int signature = attempted ? fido_assert_verify(assertion, 0, COSE_ES256, pk) : FIDO_ERR_INVALID_SIG;
                        verified = attempted && signature == FIDO_OK && ProbeNativeLocked();
                        os_log(OS_LOG_DEFAULT, "flakes_fido_assert_result=%{public}d verification_attempted=%{public}d verify_result=%{public}d verified=%{public}d", result, attempted, signature, verified);
                        fido_assert_free(&assertion); es256_pk_free(&pk);
                        if (verified) break;
                    }
                    fido_dev_close(device);
                } else os_log(OS_LOG_DEFAULT, "flakes_fido_device_open_failed=%{public}d", opened);
                fido_dev_free(&device);
            }
        } else os_log(OS_LOG_DEFAULT, "flakes_fido_enumeration_failed=%{public}d", enumeration);
        fido_dev_info_free(&devices, 64);
        printf("{\"fido_signature_verified\":%s,\"native_signature_granted\":false}\n", verified ? "true" : "false");
        return verified ? 0 : 9;
    }
}
