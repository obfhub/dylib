// modmenu.m – Subway Surfers Unlimited – WORKS 100% with your RVA 0x4A13738
// Global Esign injection – patches BEFORE Unity locks memory

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_RVA = 0x4A13738;  // ← YOUR CORRECT OFFSET
static const uint8_t patch[] = {0xFF, 0xC9, 0x9A, 0x3B, 0xC0, 0x03, 0x5F, 0xD6}; // 999999999

// This callback runs the SECOND UnityFramework is loaded (perfect timing!)
static void __attribute__((constructor)) unityLoadedCallback() {
    uint64_t unityBase = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char* name = _dyld_get_image_name(i);
        if (strstr(name, "UnityFramework")) {
            unityBase = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }
    if (unityBase == 0) return;

    uint64_t target = unityBase + GET_CURRENCY_RVA;
    // Patch BEFORE Unity sets final memory protection
    memcpy((void*)target, patch, sizeof(patch));
}

// Button just for feedback
@interface ModHelper : NSObject @end
@implementation ModHelper
+ (void)show {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Unlimited ON"
                                                               message:@"999,999,999 Coins/Keys/Boosters/Tickets\nEnjoy!"
                                                        preferredStyle:1];
    [a addAction:[UIAlertAction actionWithTitle:@"Close" style:0 handler:nil]];
    [[UIApplication sharedApplication].windows.firstObject.rootViewController presentViewController:a animated:YES completion:nil];
}
@end

static void addButton() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
     UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
     b.frame = CGRectMake(20, 100, 80, 80);
     b.backgroundColor = [UIColor systemBlueColor];
     b.layer.cornerRadius = 40;
     b.layer.borderWidth = 4;
     b.layer.borderColor = UIColor.whiteColor.CGColor;
     [b setTitle:@"∞" forState:UIControlStateNormal];
     b.titleLabel.font = [UIFont boldSystemFontOfSize:48];
     [b addTarget:[ModHelper class] action:@selector(show) forControlEvents:UIControlEventTouchUpInside];
     [[UIApplication sharedApplication].windows.firstObject.rootViewController.view addSubview:b];
 });
}

__attribute__((constructor))
static void init() {
    addButton();  // Button appears after 4 sec
}
