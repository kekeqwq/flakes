#import "ctk-denial-common.h"
#import <os/log.h>

static void Trace(const char *event) {
#ifdef FLAKES_BRIDGE_PROBE
    os_log_t log = os_log_create("com.keke.flakes.ctk-bridge", "callback");
#elif defined(FLAKES_SE_PROBE)
    os_log_t log = os_log_create("com.keke.flakes.ctk-se", "callback");
#elif defined(FLAKES_FIDO_PROBE)
    os_log_t log = os_log_create("com.keke.flakes.ctk-fido", "callback");
#else
    os_log_t log = os_log_create("com.keke.flakes.ctk-denial", "callback");
#endif
    os_log(log, "%{public}s", event);
}
#ifdef FLAKES_FIDO_PROBE
#import "ctk-fido-supervisor.h"
#endif
#ifdef FLAKES_SE_PROBE
#import "ctk-se-primitive.h"
#endif
#ifdef FLAKES_BRIDGE_PROBE
#import "ctk-bridge-policy.h"
#endif
static void Deny(NSError **error) {
    if (error) *error = [NSError errorWithDomain:TKErrorDomain
                                          code:TKErrorCodeAuthenticationFailed userInfo:nil];
}
@interface FlakesDenyOperation : TKTokenAuthOperation
#ifdef FLAKES_FIDO_PROBE
@property BOOL hardwareOptIn;
#endif
#ifdef FLAKES_SE_PROBE
@property BOOL seLockedOptIn;
#endif
@end
@implementation FlakesDenyOperation
- (BOOL)finishWithError:(NSError **)error {
#ifdef FLAKES_FIDO_PROBE
    BOOL hardwareVerified = NO;
    if (self.hardwareOptIn) hardwareVerified = ProbeFidoVerification(YES);
    else {
        Trace("hardware_not_opted_in_no_auth");
        ProbeFidoVerification(NO); // Library/whitelist selfcheck, never HID enumeration/auth.
    }
    (void)hardwareVerified;
    // Even verified hardware NEVER authorizes this token.
#endif
#ifdef FLAKES_SE_PROBE
    if (self.seLockedOptIn) {
#ifdef FLAKES_BRIDGE_PROBE
        BOOL permitted = ProbeBridgeMayUseSE(hardwareVerified, ProbeNativeLocked(), ProbeSEKey.ready);
        BOOL result = NO;
        if (permitted) {
            Trace("bridge_fresh_FIDO_accepted_before_SE");
            result = [ProbeSEKey runLockedTest];
        } else Trace("bridge_rejected_SE_NOT_CALLED");
        Trace(result ? "bridge_FIDO_then_SE_PASSED_native_output_STILL_DENIED" : "bridge_no_native_output");
#else
        BOOL result = [ProbeSEKey runLockedTest];
        Trace(result ? "se_locked_primitives_PASSED_native_output_STILL_DENIED" : "se_locked_primitives_FAILED");
#endif
    } else {
        Trace(ProbeSEKey.ready ? "se_creation_selfcheck_PASSED_no_operations" : "se_creation_selfcheck_FAILED");
    }
    [ProbeSEKey invalidate];
#endif
    Trace("finish_without_pin_CANCELLED");
    // AuthenticationFailed means retry to CTK. This no-UI negative probe must
    // terminate, not spin asking for another credential that it will never use.
    if (error) *error = [NSError errorWithDomain:TKErrorDomain
                                          code:TKErrorCodeCanceledByUser userInfo:nil];
    return NO;
}
@end

@interface FlakesDenySession : TKTokenSession <TKTokenSessionDelegate>
@end
@implementation FlakesDenySession
- (instancetype)initWithToken:(TKToken *)token {
    self = [super initWithToken:token];
    if (self) { self.delegate = self; Trace("session_created"); }
    return self;
}
- (BOOL)tokenSession:(TKTokenSession *)session supportsOperation:(TKTokenOperation)operation
           usingKey:(TKTokenObjectID)key algorithm:(TKTokenKeyAlgorithm *)algorithm {
    (void)session; (void)algorithm;
    return operation == TKTokenOperationSignData && [key isEqual:ProbeObjectID];
}
- (NSData *)tokenSession:(TKTokenSession *)session signData:(NSData *)data
               usingKey:(TKTokenObjectID)key algorithm:(TKTokenKeyAlgorithm *)algorithm
                  error:(NSError **)error {
    (void)session; (void)data; (void)key; (void)algorithm;
    Trace("sign_refused_authentication_needed");
    if (error) *error = [NSError errorWithDomain:TKErrorDomain
                                          code:TKErrorCodeAuthenticationNeeded userInfo:nil];
    return nil; // There is no private key, and never any signature output.
}
- (TKTokenAuthOperation *)tokenSession:(TKTokenSession *)session
               beginAuthForOperation:(TKTokenOperation)operation
                          constraint:(TKTokenOperationConstraint)constraint error:(NSError **)error {
    (void)session;
    Trace("begin_auth_no_password_operation");
    if (operation != TKTokenOperationSignData || ![constraint isEqual:ProbeConstraint]) {
        Deny(error); return nil;
    }
    FlakesDenyOperation *auth = [[FlakesDenyOperation alloc] init];
#ifdef FLAKES_FIDO_PROBE
    auth.hardwareOptIn = [self.token.configuration.configurationData isEqual:ProbeHardwareOptInData()];
#endif
#ifdef FLAKES_SE_PROBE
    auth.seLockedOptIn = [self.token.configuration.configurationData isEqual:ProbeSEOptInData()];
#ifdef FLAKES_BRIDGE_PROBE
    auth.seLockedOptIn |= [self.token.configuration.configurationData isEqual:ProbeBridgeDeniedData()];
#endif
#endif
    return auth; // Not a PIN/password operation.
}
@end

@interface FlakesDenyToken : TKToken <TKTokenDelegate>
@end
@implementation FlakesDenyToken
- (instancetype)initWithTokenDriver:(TKTokenDriver *)driver instanceID:(TKTokenInstanceID)instance {
    self = [super initWithTokenDriver:driver instanceID:instance];
    if (self) self.delegate = self;
    return self;
}
- (TKTokenSession *)token:(TKToken *)token createSessionWithError:(NSError **)error {
    (void)error;
    return [[FlakesDenySession alloc] initWithToken:token];
}
@end

@interface FlakesDenialTokenDriver : TKTokenDriver <TKTokenDriverDelegate>
@end
@implementation FlakesDenialTokenDriver
- (instancetype)init {
    self = [super init];
    if (self) {
        self.delegate = self;
        Trace("driver_initialized");
#if defined(FLAKES_FIDO_PROBE) || defined(FLAKES_SE_PROBE)
        Trace(ProbeLockDiagnostic().UTF8String);
        Trace(ProbeGlobalLockDiagnostic().UTF8String);
#endif
    }
    (void)ProbeDriverID;
    return self;
}
- (TKToken *)tokenDriver:(TKTokenDriver *)driver tokenForConfiguration:(TKTokenConfiguration *)configuration
                  error:(NSError **)error {
    NSArray *items = configuration.keychainItems;
    Trace(items.count == 0 ? "factory_received_empty_item_list" : "factory_received_items");
    if (![configuration.instanceID hasPrefix:@"nonlogin-denial-"] || items.count != 1 ||
        ![items[0] isKindOfClass:TKTokenKeychainKey.class]) { Deny(error); return nil; }
    TKTokenKeychainKey *key = items[0];
    TKTokenKeychainKey *expected = ProbeItem(configuration.instanceID);
    if (key.suitableForLogin) Trace("metadata_UNSAFE_login_eligibility");
    if (key.canDecrypt || key.canPerformKeyExchange) Trace("metadata_UNSAFE_extra_operation");
    if (![key.objectID isEqual:ProbeObjectID]) Trace("metadata_object_id_mismatch");
    if (![key.publicKeyData isEqual:expected.publicKeyData]) Trace("metadata_public_point_mismatch");
    // applicationTag is client-side SecItem metadata and is not preserved here.
    // Scope this fixture by unique instance, object ID, public point and no-login flags.
    if (![key.constraints isEqual:expected.constraints]) Trace("metadata_constraints_mismatch");
    if (key.suitableForLogin || key.canDecrypt || key.canPerformKeyExchange ||
        ![key.objectID isEqual:ProbeObjectID] || ![key.publicKeyData isEqual:expected.publicKeyData] ||
        ![key.constraints isEqual:expected.constraints]) {
        Trace("factory_metadata_validation_denied");
        Deny(error); return nil;
    }
#ifdef FLAKES_SE_PROBE
    if (![ProbeSEInstance isEqual:configuration.instanceID]) {
        [ProbeSEKey invalidate];
        ProbeSEInstance = configuration.instanceID;
        ProbeSEKey = [[FlakesSEPrimitive alloc] init];
    }
    if (!ProbeSEKey.ready) { Trace("se_key_preparation_FAILED"); Deny(error); return nil; }
#endif
    Trace("nonlogin_token_created");
    return [[FlakesDenyToken alloc] initWithTokenDriver:driver instanceID:configuration.instanceID];
}
@end
extern int NSExtensionMain(int argc, const char *argv[]);
int main(int argc, const char *argv[]) { return NSExtensionMain(argc, argv); }
