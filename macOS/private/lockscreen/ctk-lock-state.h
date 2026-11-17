// Read-only WindowServer session observation; unknown/missing state closes gate.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <unistd.h>

static BOOL ProbeNativeLocked(void) {
    if (getuid() == 0 || geteuid() != getuid()) return NO;
    NSDictionary *session = CFBridgingRelease(CGSessionCopyCurrentDictionary());
    if (!session) return NO;
    id locked = session[@"CGSSessionScreenIsLocked"];
    id console = session[(__bridge NSString *)kCGSessionOnConsoleKey];
    id loggedIn = session[(__bridge NSString *)kCGSessionLoginDoneKey];
    NSNumber *uid = session[(__bridge NSString *)kCGSessionUserIDKey];
    NSString *name = session[(__bridge NSString *)kCGSessionUserNameKey];
    return locked == (__bridge id)kCFBooleanTrue && console == (__bridge id)kCFBooleanTrue &&
        loggedIn == (__bridge id)kCFBooleanTrue && [uid isKindOfClass:NSNumber.class] &&
        uid.unsignedIntValue == getuid() && [name isEqual:@"keke"];
}
