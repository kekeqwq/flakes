#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// LaunchServices rejects dynamic UTIs through duti. Use a real empty file
// of each extension with the supported NSWorkspace API instead.
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
        NSURL *app = [workspace URLForApplicationWithBundleIdentifier:@"org.gnu.Emacs.Client"];
        if (!app) {
            fprintf(stderr, "Emacs client is not registered in this login session\n");
            return 1;
        }
        NSFileManager *fm = NSFileManager.defaultManager;
        NSURL *temp = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        temp = [temp URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
        NSError *error = nil;
        if (![fm createDirectoryAtURL:temp withIntermediateDirectories:NO attributes:nil error:&error]) {
            fprintf(stderr, "Unable to create test file directory: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        int failures = 0;
        for (int i = 1; i < argc; i++) {
            NSString *entry = [NSString stringWithUTF8String:argv[i]];
            BOOL isType = [entry containsString:@"."];
            NSURL *file = nil;
            UTType *type = nil;
            if (isType) {
                type = [UTType typeWithIdentifier:entry];
                if (!type) {
                    fprintf(stderr, "%s: unknown content type\n", argv[i]);
                    failures++;
                    continue;
                }
            } else {
                file = [[temp URLByAppendingPathComponent:@"sample"] URLByAppendingPathExtension:entry];
                if (![fm createFileAtPath:file.path contents:[@"text\n" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil]) {
                    fprintf(stderr, "%s: unable to create test file\n", argv[i]);
                    failures++;
                    continue;
                }
                NSURL *current = [workspace URLForApplicationToOpenURL:file];
                if ([current.URLByResolvingSymlinksInPath isEqual:app.URLByResolvingSymlinksInPath]) continue;
            }
            __block BOOL done = NO;
            __block NSError *result = nil;
            void (^completion)(NSError *) = ^(NSError *err) {
                dispatch_async(dispatch_get_main_queue(), ^{ result = err; done = YES; });
            };
            if (isType) [workspace setDefaultApplicationAtURL:app toOpenContentType:type completionHandler:completion];
            else [workspace setDefaultApplicationAtURL:app toOpenContentTypeOfFileAtURL:file completionHandler:completion];
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
            while (!done && deadline.timeIntervalSinceNow > 0) {
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            }
            if (!done || result) {
                fprintf(stderr, "%s: %s\n", argv[i], done ? result.localizedDescription.UTF8String : "timed out");
                failures++;
                if (!done) break;
            }
        }
        [fm removeItemAtURL:temp error:nil];
        return failures ? 1 : 0;
    }
}
