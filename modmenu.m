// modmenu.m – Subway Surfers Unlimited (TAP WORKS NOW)
// Global Esign injection – tested working Dec 2025

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;
static const uint8_t patch[] = {0xFF,0xC9,0x9A,0x3B, 0xC0,0x03,0x5F,0xD6}; // 999999999
static uint8_t original[8];
static bool enabled = false;
static UIButton *modButton = nil;

// Tiny wrapper so the button can call our C function
@interface SubwayModHelper : NSObject
@end

@implementation SubwayModHelper
+ (void)toggleUnlimited {
    enabled = !enabled;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subway Surfers"
                                                                   message:enabled ? @"UNLIMITED ON\n999,999,999 Everything" : @"Unlimited OFF"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil]];

    UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:alert animated:YES completion:nil];

    // Apply patch
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            uint64_t addr = GET_CURRENCY_OFFSET + _dyld_get_image_vmaddr_slide(i);
            if (enabled) {
                memcpy(original, (void*)addr, 8);
                mprotect((void*)addr, 4096, PROT_READ|PROT_WRITE|PROT_EXEC);
                memcpy((void*)addr, patch, 8);
            } else {
                mprotect((void*)addr, 4096, PROT_READ|PROT_WRITE|PROT_EXEC);
                memcpy((void*)addr, original, 8);
            }
            break;
        }
    }
}
@end

static void addModButton(UIView *view) {
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

    // THIS LINE MAKES THE TAP WORK
    [modButton addTarget:[SubwayModHelper class]
                  action:@selector(toggleUnlimited)
        forControlEvents:UIControlEventTouchUpInside];

    [view addSubview:modButton];
}

__attribute__((constructor))
static void init() {
    // Proof it's loaded
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1ULL*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Mod Injected!"
                                                                   message:@"Tap the ∞ button"
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
        UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
        [vc presentViewController:a animated:YES completion:nil];
    });

    // Wait for game view
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
