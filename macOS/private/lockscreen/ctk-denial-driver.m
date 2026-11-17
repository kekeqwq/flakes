#import "ctk-denial-common.h"
#import <os/log.h>

static void Trace(const char *event) {
#ifdef FLAKES_FIDO_PROBE
    os_log_t log = os_log_create("com.keke.flakes.ctk-fido", "callback");
#else
    os_log_t log = os_log_create("com.keke.flakes.ctk-denial", "callback");
#endif
    os_log(log, "%{public}s", event);
}
#ifdef FLAKES_FIDO_PROBE
#import "ctk-fido-supervisor.h"
#endif
static void Deny(NSError **error) {
    if (error) *error = [NSError errorWithDomain:TKErrorDomain
                                          code:TKErrorCodeAuthenticationFailed userInfo:nil];
}
@interface FlakesDenyOperation : TKTokenAuthOperation
#ifdef FLAKES_FIDO_PROBE
@property BOOL hardwareOptIn;
#endif
@end
@implementation FlakesDenyOperation
- (BOOL)finishWithError:(NSError **)error {
#ifdef FLAKES_FIDO_PROBE
    if (self.hardwareOptIn) ProbeFidoVerification(YES);
    else {
        Trace("hardware_not_opted_in_no_auth");
        ProbeFidoVerification(NO); // Library-loader selfcheck, never pam_start/auth.
    }
    // Even verified hardware NEVER authorizes this token.
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
    if (self) { self.delegate = self; Trace("driver_initialized"); }
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
    Trace("nonlogin_token_created");
    return [[FlakesDenyToken alloc] initWithTokenDriver:driver instanceID:configuration.instanceID];
}
@end
extern int NSExtensionMain(int argc, const char *argv[]);
int main(int argc, const char *argv[]) { return NSExtensionMain(argc, argv); }
