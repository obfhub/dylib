// modmenu.m – Unlimited Subway Surfers (Global Esign Injection, Button Always Visible)
// Inject normally into main app – finds UnityFramework automatically

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;
static const uint8_t patch[] = {0xFF, 0xC9, 0x9A, 0x3B, 0xC0, 0x03, 0x5F, 0xD6}; // 999999999
static uint8_t original[8];
static bool enabled = false;

// Dynamic UnityFramework slide finder
static intptr_t getUnitySlide() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

static void toggleUnlimited() {
    enabled = !enabled;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subway Mod"
                                                                   message:enabled ? @"UNLIMITED ON (999M Coins/Keys)" : @"Unlimited OFF"
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
            mprotect((void*)addr, 4096, PROT_READ | PROT_WRITE | PROT_EXEC);
            memcpy((void*)addr, patch, 8);
        } else {
            mprotect((void*)addr, 4096, PROT_READ | PROT_WRITE | PROT_EXEC);
            memcpy((void*)addr, original, 8);
        }
    }
}

__attribute__((constructor))
static void init() {
    // Confirm load with alert (appears in ~1 sec)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1ULL * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAlertController *loadAlert = [UIAlertController alertControllerWithTitle:@"Mod Loaded!"
                                                                            message:@"∞ Button in 10 sec"
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [loadAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
        [vc presentViewController:loadAlert animated:YES completion:nil];
    });

    // Floating button (10 sec delay for Unity load)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10ULL * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(20, 100, 80, 80)];
        window.backgroundColor = [UIColor colorWithRed:0 green:0.5 blue:1 alpha:0.95];
        window.layer.cornerRadius = 40;
        window.layer.borderWidth = 3;
        window.layer.borderColor = [UIColor whiteColor].CGColor;
        window.layer.shadowColor = [UIColor blackColor].CGColor;
        window.layer.shadowOpacity = 0.8;
        window.layer.shadowRadius = 10;
        window.layer.shadowOffset = CGSizeMake(0, 5);
        window.windowLevel = UIWindowLevelAlert + 1000;  // Forces on top

        UILabel *label = [[UILabel alloc] initWithFrame:window.bounds];
        label.text = @"∞";
        label.font = [UIFont systemFontOfSize:50 weight:UIFontWeightHeavy];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        [window addSubview:label];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = window.bounds;
        [button addTarget:(__bridge id _Nonnull)(void*)toggleUnlimited action:@selector(toggleUnlimited) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:button];

        [window makeKeyAndVisible];
    });
}
