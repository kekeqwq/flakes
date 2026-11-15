// Opt-in native clipboard integration fixture. No screenshot/image file is made.
// Saves/restores original pasteboard items only in memory; never prints them.
#import <AppKit/AppKit.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) return 2;
        NSPasteboard *board = NSPasteboard.generalPasteboard;
        NSMutableArray *saved = [NSMutableArray array];
        for (NSPasteboardItem *item in board.pasteboardItems) {
            NSMutableDictionary *types = [NSMutableDictionary dictionary];
            for (NSString *type in item.types) {
                NSData *data = [item dataForType:type];
                if (data) types[type] = [data copy];
            }
            [saved addObject:types];
        }
        NSBitmapImageRep *image = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:16 pixelsHigh:16
            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
            colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:64 bitsPerPixel:32];
        for (int i = 0; i < 16 * 16; ++i) {
            unsigned char *p = image.bitmapData + i * 4;
            p[0] = 203; p[1] = 166; p[2] = 247; p[3] = 255;
        }
        NSData *png = [image representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (!png.length) return 3;
        [board clearContents];
        [board declareTypes:@[NSPasteboardTypePNG] owner:nil];
        [board setData:png forType:NSPasteboardTypePNG];
        NSInteger testChange = board.changeCount;
        int result = 1;
        @try {
            NSTask *task = [NSTask new];
            task.executableURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
            NSMutableArray *arguments = [NSMutableArray array];
            for (int i = 2; i < argc; ++i) [arguments addObject:[NSString stringWithUTF8String:argv[i]]];
            task.arguments = arguments;
            NSError *error = nil;
            if ([task launchAndReturnError:&error]) {
                [task waitUntilExit];
                result = task.terminationStatus;
            }
        } @finally {
            // A concurrent user/application copy wins: never overwrite it.
            if (board.changeCount == testChange) {
                NSMutableArray *restored = [NSMutableArray array];
                for (NSDictionary *types in saved) {
                    NSPasteboardItem *item = [NSPasteboardItem new];
                    for (NSString *type in types) [item setData:types[type] forType:type];
                    [restored addObject:item];
                }
                [board clearContents];
                if (restored.count) [board writeObjects:restored];
            }
        }
        return result;
    }
}
