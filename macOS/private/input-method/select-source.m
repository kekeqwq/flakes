// Hammerspoon's actuator only: no policy, watcher, daemon, or keyboard injection.
// TISSelectInputSource alone can update the menu without activating a CJK IME
// in the focused app. Use the Input menu's focused-app TSM request instead.
// Protocol reference: laishulu/macism TSMUtils.swift (MIT, copyright 2023 laishulu).
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <unistd.h>

typedef int32_t (*FocusFn)(ProcessSerialNumber *, Boolean *);
typedef OSStatus (*PIDFn)(const ProcessSerialNumber *, pid_t *);
typedef CFMessagePortRef (*PortFn)(CFAllocatorRef, CFStringRef, pid_t);
typedef Boolean (*FlattenFn)(TISInputSourceRef, CFTypeRef *);

static int selectFocused(NSString *sourceID, pid_t expected) {
    FocusFn focus = (FocusFn)dlsym(RTLD_DEFAULT, "CPSGetKeyFocusProcess");
    PIDFn toPID = (PIDFn)dlsym(RTLD_DEFAULT, "GetProcessPID");
    PortFn portFn = (PortFn)dlsym(RTLD_DEFAULT, "CFMessagePortCreatePerProcessRemote");
    FlattenFn flatten = (FlattenFn)dlsym(RTLD_DEFAULT, "_CreateFlattenedInputSource");
    if (!focus || !toPID || !portFn || !flatten) return 69;
    ProcessSerialNumber psn = {0}; Boolean ignored = false; pid_t pid = -1;
    if (focus(&psn, &ignored) || toPID(&psn, &pid) || pid != expected) return 75;
    NSDictionary *filter = @{(__bridge NSString *)kTISPropertyInputSourceID: sourceID,
      (__bridge NSString *)kTISPropertyInputSourceIsSelectCapable: @YES};
    CFArrayRef sources = TISCreateInputSourceList((__bridge CFDictionaryRef)filter, false);
    if (!sources || !CFArrayGetCount(sources)) { if (sources) CFRelease(sources); return 65; }
    TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, 0);
    CFTypeRef flat = NULL;
    if (!flatten(source, &flat) || !flat) { CFRelease(sources); return 70; }
    NSDictionary *request = @{ @"tsmInputSourceSelectedInpSrcKey": (__bridge id)flat };
    CFDataRef data = CFPropertyListCreateData(NULL, (__bridge CFPropertyListRef)request,
      kCFPropertyListXMLFormat_v1_0, 0, NULL);
    CFMessagePortRef port = portFn(NULL, CFSTR("com.apple.tsm.portname"), pid);
    int result = 70;
    if (data && port) {
      CFDataRef reply = NULL;
      SInt32 status = CFMessagePortSendRequest(port, 7, data, 0.3, 0.3,
        kCFRunLoopDefaultMode, &reply);
      if (status == kCFMessagePortSuccess) {
        result = 0;
        if (reply) {
          CFPropertyListRef parsed = CFPropertyListCreateWithData(NULL, reply, 0, NULL, NULL);
          if (parsed && CFGetTypeID(parsed) == CFDictionaryGetTypeID()) {
            NSNumber *error = [(__bridge NSDictionary *)parsed objectForKey:@"tsmInputModeReplyToServerErrorKey"];
            if (error && error.intValue != 0) result = 70;
          }
          if (parsed) CFRelease(parsed);
        }
      }
      if (reply) CFRelease(reply);
    }
    if (port) CFRelease(port);
    if (data) CFRelease(data);
    CFRelease(flat); CFRelease(sources);
    return result;
}

int main(int argc, const char **argv) {
  @autoreleasepool {
    if (argc != 3) return 64;
    NSString *sourceID = [NSString stringWithUTF8String:argv[1]];
    pid_t expected = (pid_t)strtol(argv[2], NULL, 10);
    if (expected <= 0) return 64;
    [NSApplication sharedApplication];
    // Repair an earlier TIS-only selection: its global ID may already be
    // Squirrel even though the focused app is still using ABC.
    TISInputSourceRef current = TISCopyCurrentKeyboardInputSource();
    NSString *currentID = (__bridge NSString *)TISGetInputSourceProperty(current, kTISPropertyInputSourceID);
    BOOL repair = [sourceID isEqualToString:@"im.rime.inputmethod.Squirrel.Hans"] && [currentID isEqualToString:sourceID];
    CFRelease(current);
    if (repair) {
      int result = selectFocused(@"com.apple.keylayout.ABC", expected);
      if (result) return result;
      // InputMethodKit activation/deactivation is asynchronous even after
      // the TSM reply. Let the previous input controller finish detaching.
      usleep(100000);
    }
    return selectFocused(sourceID, expected);
  }
}
