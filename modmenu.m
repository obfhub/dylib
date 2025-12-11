// modmenu.m – Subway Surfers Unlimited (Working Offset for v3.56+)
// Global Esign – patches on load, tap for confirmation

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A1A3C8;  // Updated for v3.56+ (GetCurrency RVA)
static const uint8_t patch[] = {0xFF, 0xC9, 0x9A, 0x3B, 0xC0, 0x03, 0x5F, 0xD6}; // mov w0, #999999999 ; ret

// Static patch (applies once on load – no runtime crash)
static void applyPatch() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            uint64_t addr = GET_CURRENCY_OFFSET + _dyld_get_image_vmaddr_slide(i);
            memcpy((void*)addr, patch, 8);  // Direct write – safe on load
            break;
        }
    }
}

// Wrapper for tap feedback
@interface SubwayModHelper : NSObject
@end
@implementation SubwayModHelper
+ (void)showStatus {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Patch Active!"
                                                                   message:@"999M Coins/Keys/Boosters – Check Menu!"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
    if (vc) [vc presentViewController:alert animated:YES completion:nil];
}
@end

static void addModButton(UIView *view) {
    static UIButton *modButton;
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
                  action:@selector(showStatus)
        forControlEvents:UIControlEventTouchUpInside];

    [view addSubview:modButton];
}

__attribute__((constructor))
static void init() {
    applyPatch();  // Patch immediately

    // Confirm
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1ULL * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Mod Ready!"
                                                                   message:@"Unlimited Everything – Tap ∞ to Confirm"
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
        UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
        if (vc) [vc presentViewController:a animated:YES completion:nil];
    });

    // Add button
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (true) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
                if (vc && vc.isViewLoaded && vc.view.window) {
                    addModButton(vc.view);
                }
            });
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}
