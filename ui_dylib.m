#import <Cocoa/Cocoa.h>

@interface SimpleWindowController : NSObject
@property (strong) NSWindow *window;
@end

@implementation SimpleWindowController

- (instancetype)init {
    self = [super init];
    if (self) {
        NSRect frame = NSMakeRect(0, 0, 420, 220);

        self.window = [[NSWindow alloc]
            initWithContentRect:frame
                      styleMask:(NSWindowStyleMaskTitled |
                                 NSWindowStyleMaskClosable |
                                 NSWindowStyleMaskMiniaturizable)
                        backing:NSBackingStoreBuffered
                          defer:NO];

        [self.window setTitle:@"Hello from .dylib"];
        [self.window center];

        NSView *content = [self.window contentView];
        content.wantsLayer = YES;
        content.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];

        // Label
        NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 140, 380, 24)];
        label.stringValue = @"This UI was created by a dylib.";
        label.editable = NO;
        label.bezeled = NO;
        label.drawsBackground = NO;
        label.font = [NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
        [content addSubview:label];

        // Button
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(20, 80, 160, 32)];
        btn.title = @"Close Window";
        btn.bezelStyle = NSBezelStyleRounded;
        btn.target = self;
        btn.action = @selector(closeWindow);
        [content addSubview:btn];
    }
    return self;
}

- (void)closeWindow {
    [self.window close];
}

@end


static SimpleWindowController *controller = nil;

// auto-runs when dylib loads
__attribute__((constructor))
static void dylib_entry() {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            // Ensure an NSApplication exists (needed if host is console app)
            if (NSApp == nil) {
                [NSApplication sharedApplication];
                [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            }

            controller = [[SimpleWindowController alloc] init];
            [controller.window makeKeyAndOrderFront:nil];
            [NSApp activateIgnoringOtherApps:YES];
        }
    });
}
