// Default: read-only discovery. Opt-in: add/remove one EMPTY configuration.
// Never creates keys, certificates, identities, sessions or login eligibility.
#import <CryptoTokenKit/CryptoTokenKit.h>
#include <stdio.h>
#include <string.h>
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        TKTokenDriverConfiguration *configuration =
            TKTokenDriverConfiguration.driverConfigurations[@"com.keke.flakes.ctk-empty-probe.driver"];
        unsigned long count = (unsigned long)configuration.tokenConfigurations.count;
        printf("{\"host_configuration_visible\":%s,\"own_token_count\":%lu,"
               "\"creates_credentials\":false}\n", configuration ? "true" : "false", count);
        if (!configuration) return 3;
        if (count != 0) return 4; // Never modify pre-existing configurations.
        if (argc == 2 && strcmp(argv[1], "--empty-instance") == 0) {
            NSString *instance = [@"empty-denial-probe-" stringByAppendingString:NSUUID.UUID.UUIDString];
            @try {
                TKTokenConfiguration *empty = [configuration addTokenConfigurationForTokenInstanceID:instance];
                empty.keychainItems = @[];
                printf("{\"empty_instance_added\":true,\"keychain_item_count\":%lu}\n",
                       (unsigned long)empty.keychainItems.count);
                [NSThread sleepForTimeInterval:5.0];
            } @finally {
                [configuration removeTokenConfigurationForTokenInstanceID:instance];
            }
            printf("{\"own_token_count_after_cleanup\":%lu}\n",
                   (unsigned long)configuration.tokenConfigurations.count);
            return configuration.tokenConfigurations.count == 0 ? 0 : 5;
        }
        return 0;
    }
}
