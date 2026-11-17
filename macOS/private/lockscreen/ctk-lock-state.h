#pragma once
// Read-only native session observation; authoritative global state is mandatory.
// No caller-provided flag, notification or environment value can open the gate.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/IOKitLib.h>
#include <unistd.h>

typedef struct {
    BOOL ordinaryUser, sessionPresent, lockPresent, locked, console, loggedIn, uidMatches, nameMatches;
} ProbeLockObservation;

static inline ProbeLockObservation ProbeObserveLock(void) {
    ProbeLockObservation value = {0};
    value.ordinaryUser = getuid() != 0 && geteuid() == getuid();
    NSDictionary *session = CFBridgingRelease(CGSessionCopyCurrentDictionary());
    value.sessionPresent = session != nil;
    id locked = session[@"CGSSessionScreenIsLocked"];
    NSNumber *uid = session[(__bridge NSString *)kCGSessionUserIDKey];
    value.lockPresent = locked != nil;
    value.locked = locked == (__bridge id)kCFBooleanTrue;
    value.console = session[(__bridge NSString *)kCGSessionOnConsoleKey] == (__bridge id)kCFBooleanTrue;
    value.loggedIn = session[(__bridge NSString *)kCGSessionLoginDoneKey] == (__bridge id)kCFBooleanTrue;
    value.uidMatches = [uid isKindOfClass:NSNumber.class] && uid.unsignedIntValue == getuid();
    value.nameMatches = [session[(__bridge NSString *)kCGSessionUserNameKey] isEqual:@"keke"];
    return value;
}
static inline ProbeLockObservation ProbeObserveGlobalLock(NSUInteger *active, NSUInteger *owned) {
    ProbeLockObservation value = {0};
    value.ordinaryUser = getuid() != 0 && geteuid() == getuid();
    *active = 0; *owned = 0;
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    if (!root) return value;
    id entries = CFBridgingRelease(IORegistryEntryCreateCFProperty(root, CFSTR("IOConsoleUsers"), kCFAllocatorDefault, 0));
    IOObjectRelease(root);
    if (![entries isKindOfClass:NSArray.class]) return value;
    value.sessionPresent = YES;
    for (id entry in entries) {
        if (![entry isKindOfClass:NSDictionary.class]) continue;
        if (entry[(__bridge NSString *)kCGSessionOnConsoleKey] != (__bridge id)kCFBooleanTrue) continue;
        (*active)++;
        NSNumber *uid = entry[(__bridge NSString *)kCGSessionUserIDKey];
        if (![uid isKindOfClass:NSNumber.class] || uid.unsignedIntValue != getuid() ||
            ![entry[(__bridge NSString *)kCGSessionUserNameKey] isEqual:@"keke"]) continue;
        (*owned)++;
        value.uidMatches = YES; value.nameMatches = YES; value.console = YES;
        value.lockPresent = entry[@"CGSSessionScreenIsLocked"] != nil;
        value.locked = entry[@"CGSSessionScreenIsLocked"] == (__bridge id)kCFBooleanTrue;
        value.loggedIn = entry[(__bridge NSString *)kCGSessionLoginDoneKey] == (__bridge id)kCFBooleanTrue;
    }
    return value;
}
static inline NSString *ProbeGlobalLockDiagnostic(void) {
    NSUInteger active, owned;
    ProbeLockObservation v = ProbeObserveGlobalLock(&active, &owned);
    return [NSString stringWithFormat:@"global_gate_observation source=%d active=%lu owned=%lu ordinary=%d lock_field=%d locked=%d console=%d login=%d uid_match=%d name_match=%d",
        v.sessionPresent, (unsigned long)active, (unsigned long)owned, v.ordinaryUser,
        v.lockPresent, v.locked, v.console, v.loggedIn, v.uidMatches, v.nameMatches];
}
static inline BOOL ProbeObservationLocked(ProbeLockObservation v) {
    return v.ordinaryUser && v.sessionPresent && v.lockPresent && v.locked &&
        v.console && v.loggedIn && v.uidMatches && v.nameMatches;
}
static inline BOOL ProbeLockDecision(ProbeLockObservation local, ProbeLockObservation global,
                                     NSUInteger active, NSUInteger owned) {
    // The kernel registry root supplies the global console state, not the caller.
    // XPC services may have no Quartz session. If a local session IS available,
    // disagreement or incomplete local state still closes the gate.
    if (!local.ordinaryUser || active != 1 || owned != 1 || !ProbeObservationLocked(global)) return NO;
    return !local.sessionPresent || ProbeObservationLocked(local);
}
static inline BOOL ProbeNativeLocked(void) {
    NSUInteger active, owned;
    ProbeLockObservation global = ProbeObserveGlobalLock(&active, &owned);
    return ProbeLockDecision(ProbeObserveLock(), global, active, owned);
}
static inline NSString *ProbeLockDiagnostic(void) {
    ProbeLockObservation v = ProbeObserveLock();
    return [NSString stringWithFormat:@"gate_observation ordinary=%d session=%d lock_field=%d locked=%d console=%d login=%d uid_match=%d name_match=%d",
        v.ordinaryUser, v.sessionPresent, v.lockPresent, v.locked, v.console, v.loggedIn, v.uidMatches, v.nameMatches];
}
