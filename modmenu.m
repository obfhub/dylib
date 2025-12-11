// modmenu.m – Subway Surfers Unlimited (Unity View Hook, No Crash)
// Adds button to game view directly – global Esign injection

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;
static const uint8_t patch[] = {0xFF, 0xC9, 0x9A, 0x3B, 0xC0, 0x03, 0x5F, 0xD6}; // 999999999
static uint8_t original[8];
static bool enabled = false;
static UIButton *modButton = nil;

// Dynamic UnityFramework slide finder
static intptr_t getUnitySlide() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

static void toggleUnlimited(id sender) {
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

static void addModButton(UIView *gameView) {
    if (modButton) return; // Already added

    modButton = [UIButton buttonWithType:UIButtonTypeCustom];
    modButton.frame = CGRectMake(20, 100, 60, 60);
    modButton.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.9];
    modButton.layer.cornerRadius = 30;
    modButton.layer.borderWidth = 2;
    modButton.layer.borderColor = [UIColor whiteColor].CGColor;
    modButton.titleLabel.font = [UIFont boldSystemFontOfSize:30];
    [modButton setTitle:@"∞" forState:UIControlStateNormal];
    [modButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [modButton addTarget:@(toggleUnlimited) action:@selector(toggleUnlimited:) forControlEvents:UIControlEventTouchUpInside];

    [gameView addSubview:modButton];
}

__attribute__((constructor))
static void init() {
    // Confirm load (1 sec)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1ULL * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAlertController *loadAlert = [UIAlertController alertControllerWithTitle:@"Mod Loaded!"
                                                                            message:@"Button appears soon"
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [loadAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
        [vc presentViewController:loadAlert animated:YES completion:nil];
    });

    // Poll for Unity view in background thread (no main queue block)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (true) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
                if (vc && vc.view && getUnitySlide() != 0 && ![vc.view.subviews containsObject:modButton]) {
                    addModButton(vc.view);  // Add to game view
                }
            });
            [NSThread sleepForTimeInterval:1.0];  // Check every 1 sec
        }
    });
}
