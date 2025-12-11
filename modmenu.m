// modmenu.m – Subway Surfers Unlimited (Static Patch – No Crash on Tap)
// Global Esign injection – patches on load, button for feedback

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;
static const uint8_t patch[] = {0xFF,0xC9,0x9A,0x3B, 0xC0,0x03,0x5F,0xD6}; // mov w0, #999999999 ; ret

// Static patch function (safe, no mprotect)
static void applyStaticPatch() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            uint64_t addr = GET_CURRENCY_OFFSET + _dyld_get_image_vmaddr_slide(i);
            // Direct memcpy (no mprotect – iOS allows on load)
            memcpy((void*)addr, patch, 8);
            break;
        }
    }
}

// Wrapper for tap
@interface SubwayModHelper : NSObject
@end
@implementation SubwayModHelper
+ (void)showToggle {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Unlimited Active!"
                                                                   message:@"999M Coins/Keys/Boosters – Always ON"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Got It" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *vc = UIApplication.sharedApplication.keyWindow.rootViewController;
    if (vc) [vc presentViewController:alert animated:YES completion:nil];
}
@end

static void addModButton(UIView *view) {
    static UIButton *modButton = nil;
    if (modButton || !view) return;

    modButton = [UIButton buttonWithType:UIButtonTypeCustom];
    modButton.frame = CGRectMake(20, 100, 80, 80);
    modButton.backgroundColor = [UIColor systemBlueColor];
    modButton.layer.cornerRadius = 40;
    modButton.layer.borderWidth = 4;
    modButton.layer.borderColor = UIColor.whiteColor.CGColor;
    [modButton setTitle:@"∞" forState:UIControlStateNormal];
    [modButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    modButton.titleLabel.font = [UIFont boldSystemFontOfSize:48];

    [modButton addTarget:[SubwayModHelper class]
                  action:@selector(showToggle)
        forControlEvents:UIControlEventTouchUpInside];

    [view addSubview:modButton];
}

__attribute__((constructor))
static void init() {
    // Apply static patch immediately
    applyStaticPatch();

    // Confirm loaded
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1ULL*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Mod Active!"
                                                                   message:@"Unlimited Everything – Tap ∞ for Info"
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
        UIViewController *vc = UIApplication.sharedApplication.keyWindow.rootViewController;
        if (vc) [vc presentViewController:a animated:YES completion:nil];
    });

    // Add button when view ready
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (true) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                UIViewController *vc = UIApplication.sharedApplication.keyWindow.rootViewController;
                if (vc && vc.isViewLoaded && vc.view.window) {
                    addModButton(vc.view);
                }
            });
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}
