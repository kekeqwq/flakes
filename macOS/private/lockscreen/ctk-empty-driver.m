// Feasibility probe only. No identities, keys, sessions or successful operations.
#import <CryptoTokenKit/CryptoTokenKit.h>
#import <os/log.h>

@interface FlakesEmptyTokenDriver : TKTokenDriver <TKTokenDriverDelegate>
@end
@implementation FlakesEmptyTokenDriver
- (instancetype)init {
    self = [super init];
    if (self) {
        self.delegate = self;
        os_log(OS_LOG_DEFAULT, "Flakes empty CTK driver initialized (no credentials)");
    }
    return self;
}
- (TKToken *)tokenDriver:(TKTokenDriver *)driver
  tokenForConfiguration:(TKTokenConfiguration *)configuration
                  error:(NSError **)error {
    (void)driver; (void)configuration;
    if (error) *error = [NSError errorWithDomain:TKErrorDomain
                                          code:TKErrorCodeNotImplemented userInfo:nil];
    return nil; // Deliberately cannot create a token or authenticate.
}
@end
extern int NSExtensionMain(int argc, const char *argv[]);
int main(int argc, const char *argv[]) { return NSExtensionMain(argc, argv); }
