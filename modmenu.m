// modmenu.m – Unlimited Everything for Subway Surfers (Global Esign Injection)
// Dynamically finds UnityFramework slide – inject into main binary, works non-JB iOS 13–18.2

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;
static const uint8_t patch[] = {0xFF, 0xC9, 0x9A, 0x3B, 0xC0, 0x03, 0x5F, 0xD6}; // mov w0, #999999999 ; ret
static uint8_t original[8];
static bool enabled = false;

// Find UnityFramework's ASLR slide (key for global injection)
static intptr_t getUnitySlide() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "UnityFramework")) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0; // Fallback if not loaded yet
}

static void handleTap() {
    enabled = !enabled;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subway Surfers"
                                                                   message:enabled ? @"UNLIMITED ON" : @"Unlimited OFF"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

    UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:alert animated:YES completion:nil];

    intptr_t slide = getUnitySlide();
    if (slide == 0) return; // Unity not loaded – retry later if needed

    uint64_t addr = GET_CURRENCY_OFFSET + slide;
    if (enabled) {
        memcpy(original, (void*)addr, sizeof(original));
        mprotect((void*)addr, 4096, PROT_READ | PROT_WRITE | PROT_EXEC);
        memcpy((void*)addr, patch, sizeof(patch));
    } else {
        mprotect((void*)addr, 4096, PROT_READ | PROT_WRITE | PROT_EXEC);
        memcpy((void*)addr, original, sizeof(original));
    }
}

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3ULL * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *btn = [[UIWindow alloc] initWithFrame:CGRectMake(30, 120, 70, 70)];
        btn.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.85];
        btn.layer.cornerRadius = 35;
        btn.windowLevel = 999999;

        UILabel *l = [[UILabel alloc] initWithFrame:btn.bounds];
        l.text = @"∞";
        l.font = [UIFont boldSystemFontOfSize:40];
        l.textColor = UIColor.whiteColor;
        l.textAlignment = NSTextAlignmentCenter;
        [btn addSubview:l];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:@selector(handleTap)];
        [btn addGestureRecognizer:tap];

        [btn makeKeyAndVisible];
    });
}
