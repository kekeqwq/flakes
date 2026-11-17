// A LaunchServices file-aware client launcher, not a second Emacs process.
#import <Cocoa/Cocoa.h>

@interface EmacsClientDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSMutableArray<NSString *> *files;
@property(nonatomic) BOOL ready;
@end

@implementation EmacsClientDelegate
- (void)connect {
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @EMACSCLIENT;
  NSMutableArray *args = [NSMutableArray arrayWithArray:
      @[@"--create-frame", @"--no-wait", @"--alternate-editor=false"]];
  // -- prevents document names from being interpreted as client options.
  if (self.files.count) {
    [args addObject:@"--"];
    [args addObjectsFromArray:self.files];
  }
  task.arguments = args;
  NSError *error = nil;
  BOOL launched = [task launchAndReturnError:&error];
  if (launched) [task waitUntilExit];
  if (launched && task.terminationStatus == 0) {
    // Creating an NS frame in a daemon does not necessarily activate its
    // application. Target the exact server PID, not an arbitrary Emacs app.
    NSTask *focus = [[NSTask alloc] init];
    NSPipe *output = [NSPipe pipe];
    focus.launchPath = @EMACSCLIENT;
    focus.arguments = @[@"--alternate-editor=false", @"--eval",
        @"(progn (select-frame-set-input-focus (selected-frame)) (emacs-pid))"];
    focus.standardOutput = output;
    if ([focus launchAndReturnError:&error]) {
      NSData *data = [[output fileHandleForReading] readDataToEndOfFile];
      [focus waitUntilExit];
      if (focus.terminationStatus == 0) {
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        pid_t pid = (pid_t)[text integerValue];
        if (pid > 0) {
          NSRunningApplication *server = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
          [server activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        }
      }
    }
  }
  if (!launched || task.terminationStatus != 0) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Emacs service is not ready";
    alert.informativeText = @"The desktop app only connects to the managed Emacs daemon. Check the Home Manager Emacs LaunchAgent; it may still be initializing. No standalone daemon was started.";
    [alert runModal];
  }
  [NSApp terminate:nil];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  self.ready = YES;
  // Let any initial open-file AppleEvents be delivered before making a frame.
  [self performSelector:@selector(connect) withObject:nil afterDelay:0.1];
}
- (void)application:(NSApplication *)application openFiles:(NSArray<NSString *> *)files {
  [self.files addObjectsFromArray:files];
  [application replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)flag {
  if (self.ready) [self connect];
  return YES;
}
@end

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    EmacsClientDelegate *delegate = [[EmacsClientDelegate alloc] init];
    delegate.files = [NSMutableArray array];
    for (int i = 1; i < argc; i++) {
      NSString *arg = [NSString stringWithUTF8String:argv[i]];
      if (![arg hasPrefix:@"-psn_"]) [delegate.files addObject:arg];
    }
    app.delegate = delegate;
    [app run];
  }
  return 0;
}
