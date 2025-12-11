// modmenu.m – Subway Surfers Unlimited Everything (Global Esign – No Crash, Button Appears)

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;
static const uint8_t patch[] = {0xFF,0xC9,0x9A,0x3B, 0xC0,0x03,0x5F,0xD6}; // 999999999
static uint8_t original[8];
static bool enabled = false;
static UIButton *modButton = nil;

// Find UnityFramework slide
static intptr_t getUnitySlide() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

// Toggle function
static void toggleUnlimited() {
    enabled = !enabled;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subway Mod"
                                                                   message:enabled ? @"UNLIMITED ON" : @"Unlimited OFF"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

    UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:alert animated:YES completion:nil];

    intptr_t slide = getUnitySlide();
    if (slide) {
        uint64_t addr = GET_CURRENCY_OFFSET + slide;
        if (enabled) {
            memcpy(original, (void*)addr, 8);
            mprotect((void*)addr, 4096, PROT_READ|PROT_WRITE|PROT_EXEC);
            memcpy((void*)addr, patch, 8);
        } else {
            mprotect((void*)addr, 4096, PROT_READ|PROT_WRITE|PROT_EXEC);
            memcpy((void*)addr, original, 8);
        }
    }
}

// Add button to Unity's view
static void addModButtonToView(UIView *view) {
    if (modButton || !view) return;

    modButton = [UIButton buttonWithType:UIButtonTypeCustom];
    modButton.frame = CGRectMake(20, 100, 70, 70);
    modButton.backgroundColor = [UIColor colorWithRed:0 green:0.5 blue:1 alpha:0.95];
    modButton.layer.cornerRadius = 35;
    modButton.layer.borderWidth = 3;
    modButton.layer.borderColor = UIColor.whiteColor.CGColor;
    [modButton setTitle:@"∞" forState:UIControlStateNormal];
    [modButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    modButton.titleLabel.font = [UIFont boldSystemFontOfSize:42];

    // Correct way to add target (no boxing error)
    [modButton addTarget:nil action:@selector(toggleUnlimited) forControlEvents:UIControlEventTouchUpInside];

    [view addSubview:modButton];
}

__attribute__((constructor))
static void init() {
    // Confirm dylib loaded
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1ULL*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Mod Loaded!"
                                                                   message:@"Button appears in a few seconds"
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
        UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
        [vc presentViewController:a animated:YES completion:nil];
    });

    // Poll every second until Unity view is ready
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (true) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
                if (vc && vc.isViewLoaded && vc.view.window && getUnitySlide() != 0) {
                    addModButtonToView(vc.view);
                }
            });
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}
