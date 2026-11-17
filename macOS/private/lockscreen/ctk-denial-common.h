// Public-only non-login fixture. No private scalar was generated or retained.
#import <CryptoTokenKit/CryptoTokenKit.h>
#import <Security/Security.h>
#include <string.h>
#include <stdlib.h>

#ifdef FLAKES_BRIDGE_PROBE
#define FLAKES_FIDO_PROBE 1
#define FLAKES_SE_PROBE 1
static NSString *const ProbeDriverID = @"com.keke.flakes.ctk-bridge-probe.driver";
#define FlakesDenialTokenDriver FlakesBridgeTokenDriver
static NSData *ProbeHardwareOptInData(void) {
    return [@"locked-bridge-opt-in-v1" dataUsingEncoding:NSUTF8StringEncoding];
}
#define ProbeSEOptInData ProbeHardwareOptInData
static NSData *ProbeBridgeDeniedData(void) {
    return [@"bridge-no-hardware-opt-in-denial-v1" dataUsingEncoding:NSUTF8StringEncoding];
}
#elif defined(FLAKES_SE_PROBE)
static NSString *const ProbeDriverID = @"com.keke.flakes.ctk-se-probe.driver";
#define FlakesDenialTokenDriver FlakesSETokenDriver
static NSData *ProbeSEOptInData(void) {
    return [@"locked-se-primitive-opt-in-v1" dataUsingEncoding:NSUTF8StringEncoding];
}
#elif defined(FLAKES_FIDO_PROBE)
static NSString *const ProbeDriverID = @"com.keke.flakes.ctk-fido-probe.driver";
#define FlakesDenialTokenDriver FlakesFidoTokenDriver
static NSData *ProbeHardwareOptInData(void) {
    return [@"locked-fido-verification-opt-in-v1" dataUsingEncoding:NSUTF8StringEncoding];
}
#else
static NSString *const ProbeDriverID = @"com.keke.flakes.ctk-denial-probe.driver";
#endif
static NSString *const ProbeObjectID = @"denial-only";
static NSString *const ProbeConstraint = @"always-deny-no-pin";
static NSData *ProbeHex(const char *hex) {
    unsigned char bytes[65];
    size_t count = strlen(hex) / 2;
    if (count > sizeof(bytes)) abort();
    for (size_t i = 0; i < count; i++) {
        char pair[3] = {hex[2*i], hex[2*i+1], 0};
        bytes[i] = (unsigned char)strtoul(pair, NULL, 16);
    }
    return [NSData dataWithBytes:bytes length:count];
}
static NSData *ProbePublicPoint(void) {
    // P-256: x = SHA256("flakes-nonlogin-denial-public-point-v1"),
    // increment x until a curve point exists; y = rhs^((p+1)/4) mod p.
    return ProbeHex("042e83e4b31ca4e4eda57fc1ea4ff9cfb77647bca175bb958b2a994b2f6de664fe2461eb2a46276839317149681b46f876a05c2b6d51f0623f7bb04a92eedd62bc");
}
static NSData *ProbeTag(NSString *instance) {
    return [[@"ctk-denial:" stringByAppendingString:instance] dataUsingEncoding:NSUTF8StringEncoding];
}
static TKTokenKeychainKey *ProbeItem(NSString *instance) {
    TKTokenKeychainKey *item = [[TKTokenKeychainKey alloc] initWithCertificate:NULL objectID:ProbeObjectID];
    item.label = @"Non-login denial probe - no certificate or private key";
    item.keyType = (__bridge NSString *)kSecAttrKeyTypeECSECPrimeRandom;
    item.keySizeInBits = 256;
    item.publicKeyData = ProbePublicPoint();
    item.publicKeyHash = ProbeHex("0165019dec470bb0f5f47a4554d191115decae80");
    item.applicationTag = ProbeTag(instance);
    item.canSign = YES; // Advertises dispatch only; backend NEVER signs.
    item.canDecrypt = NO;
    item.canPerformKeyExchange = NO;
    item.suitableForLogin = NO;
    item.constraints = @{@(TKTokenOperationSignData): ProbeConstraint};
    return item;
}
