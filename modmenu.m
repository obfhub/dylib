// modmenu.m — Single-file Subway Surfers Unlimited Coins Mod Menu (ObjC source)
// Drop in repo + YAML below → Builds fat arm64/arm64e dylib on GitHub Actions
// Inject with Esign/optool on non-JB iOS 15–18.2

#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <UIKit/UIKit.h>

// ==== CONFIG (change offset/value here) ====
static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;          // Your GetCurrency RVA
static const uint8_t patch[]   = {0xFF,0xC9,0x9A,0x3B, 0xC0,0x03,0x5F,0xD6}; // mov w0, #999999999 ; ret
static uint8_t original[8];
static bool enabled = false;

// ==== Floating Menu Button ====
__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(0, 4ULL*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *btn = [[UIWindow alloc] initWithFrame:CGRectMake(30, 120, 70, 70)];
        btn.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.85];
        btn.layer.cornerRadius = 35;
        btn.windowLevel = 999999;

        UILabel *lbl = [[UILabel alloc] initWithFrame:btn.bounds];
        lbl.text = @"∞";
        lbl.font = [UIFont boldSystemFontOfSize:40];
        lbl.textColor = UIColor.whiteColor;
        lbl.textAlignment = NSTextAlignmentCenter;
        [btn addSubview:lbl];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:^(id _Nonnull sender) {
            enabled = !enabled;
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Subway Mod"
                                        message:enabled?@"UNLIMITED ON":@"Unlimited OFF"
                                        preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:a animated:YES completion:nil];

            // ASLR-safe address (slide + offset)
            uint64_t addr = GET_CURRENCY_OFFSET + _dyld_get_image_vmaddr_slide(0);
            if (enabled) {
                memcpy(original, (void*)addr, 8);
                mprotect((void*)addr, 8, PROT_READ|PROT_WRITE|PROT_EXEC);
                memcpy((void*)addr, patch, 8);
            } else {
                mprotect((void*)addr, 8, PROT_READ|PROT_WRITE|PROT_EXEC);
                memcpy((void*)addr, original, 8);
            }
        }];
        [btn addGestureRecognizer:tap];

        [btn makeKeyAndVisible];
    });
}
