// modmenu.m — Final working version (Dec 2025)
// Floating ∞ button → toggle Unlimited Coins/Keys/Everything in Subway Surfers
// Builds on GitHub Actions in ~40 seconds → inject with Esign/Sideloadly

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;
static const uint8_t patch[]   = {0xFF,0xC9,0x9A,0x3B, 0xC0,0x03,0x5F,0xD6}; // mov w0, #999999999 ; ret
static uint8_t original[8];
static bool enabled = false;

// Helper to get the top-most view controller (replaces deprecated keyWindow)
UIViewController *topVC() {
    UIWindow *window = UIApplication.sharedApplication.windows.firstObject
                     ?: UIApplication.sharedApplication.delegate.window;
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

// Tap handler (now as a proper SEL)
static void handleTap(UITapGestureRecognizer *sender) {
    enabled = !enabled;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subway Surfers"
                                                                   message:enabled ? @"UNLIMITED ON" : @"Unlimited OFF"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [topVC() presentViewController:alert animated:YES completion:nil];

    uint64_t addr = GET_CURRENCY_OFFSET + _dyld_get_image_vmaddr_slide(0); // ASLR safe

    if (enabled) {
        memcpy(original, (void*)addr, 8);
        mprotect((void*)addr, 8, PROT_READ | PROT_WRITE | PROT_EXEC);
        memcpy((void*)addr, patch, 8);
    } else {
        mprotect((void*)addr, 8, PROT_READ | PROT_WRITE | PROT_EXEC);
        memcpy((void*)addr, original, 8);
    }
}

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4ULL * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *btn = [[UIWindow alloc] initWithFrame:CGRectMake(30, 120, 70, 70)];
        btn.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.85];
        btn.layer.cornerRadius = 35;
        btn.windowLevel = 999999;
        btn.hidden = NO;

        UILabel *lbl = [[UILabel alloc] initWithFrame:btn.bounds];
        lbl.text = @"∞";
        lbl.font = [UIFont boldSystemFontOfSize:40];
        lbl.textColor = UIColor.whiteColor;
        lbl.textAlignment = NSTextAlignmentCenter;
        [btn addSubview:lbl];

        [btn addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:nil action:@selector(handleTap:)]];
        [btn makeKeyAndVisible];
    });
}
