// modmenu.m – Unlimited Everything toggle for Subway Surfers (non-jailbroken)
// Works on iOS 13 → 18.2, floating menu
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;               // your offset
static const uint8_t patch[] = {0xFF,0xC9,0x9A,0x3B, 0xC0,0x03,0x5F,0xD6}; // 999999999
static uint8_t original[8];
static bool enabled = false;

static void handleTap() {
    enabled = !enabled;

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Subway Surfers"
                             message:enabled ? @"UNLIMITED ON" : @"Unlimited OFF"
                      preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];

    UIWindow *w = UIApplication.sharedApplication.windows.firstObject;
    [w.rootViewController ?: w presentViewController:a animated:YES completion:nil];

    uint64_t addr = GET_CURRENCY_OFFSET + _dyld_get_image_vmaddr_slide(0);
    if (enabled) {
        memcpy(original, (void*)addr, sizeof(original));
        mprotect((void*)addr, 4096, PROT_READ|PROT_WRITE|PROT_EXEC);
        memcpy((void*)addr, patch, sizeof(patch));
    } else {
        mprotect((void*)addr, 4096, PROT_READ|PROT_WRITE|PROT_EXEC);
        memcpy((void*)addr, original, sizeof(original));
    }
}

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4ULL*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *btn = [[UIWindow alloc] initWithFrame:CGRectMake(30, 120, 70, 70)];
        btn.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.85];
        btn.layer.cornerRadius = 35;
        btn.windowLevel = 999999;

        UILabel *l = [[UILabel alloc] initWithFrame:btn.bounds];
        l.text = @"∞"; l.textAlignment = NSTextAlignmentCenter;
        l.font = [UIFont boldSystemFontOfSize:40];
        l.textColor = UIColor.whiteColor;
        [btn addSubview:l];

        [btn addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:(__bridge id)(void*)handleTap
                                                                        action:@selector(invoke)]];
        [btn makeKeyAndVisible];
    });
}
