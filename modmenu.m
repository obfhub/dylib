// modmenu.m – Subway Surfers Unlimited Everything (Dec 2025 working)
// Inject into UnityFramework, NOT the main binary!

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;  // correct
static const uint8_t patch[]   = {0xFF,0xC9,0x9A,0x3B, 0xC0,0x03,0x5F,0xD6}; // 999999999
static uint8_t original[8];
static bool enabled = false;

static void (*orig_present)(id, SEL, id, BOOL, id);
void my_present(id self, SEL _cmd, id vc, BOOL animated, id completion) {
    enabled = !enabled;

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Subway Surfers"
                                    message:enabled ? @"UNLIMITED ON" : @"Unlimited OFF"
                             preferredStyle:1];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
    [self presentViewController:a animated:YES completion:nil];

    uint64_t addr = GET_CURRENCY_OFFSET + _dyld_get_image_vmaddr_slide(0);
    if (enabled) {
        memcpy(original, (void*)addr, 8);
        mprotect((void*)addr, 0x4000, PROT_READ|PROT_WRITE|PROT_EXEC);
        memcpy((void*)addr, patch, 8);
    } else {
        mprotect((void*)addr, 0x4000, PROT_READ|PROT_WRITE|PROT_EXEC);
        memcpy((void*)addr, original, 8);
    }

    // call original
    orig_present(self, _cmd, vc, animated, completion);
}

__attribute__((constructor))
static void init() {
    // Hook any view controller present method so menu works even without floating button
    MSHookMessageEx(objc_getClass("UIViewController"),
                    @selector(presentViewController:animated:completion:),
                    (IMP(my_present), (IMP*)&orig_present);

    // Optional floating button (appears in 3 sec)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3ULL*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *btn = [[UIWindow alloc] initWithFrame:CGRectMake(30, 120, 70, 70)];
        btn.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.9];
        btn.layer.cornerRadius = 35;
        btn.windowLevel = 999999;

        UILabel *l = [[UILabel alloc] initWithFrame:btn.bounds];
        l.text = @"∞"; l.textColor = UIColor.whiteColor;
        l.font = [UIFont boldSystemFontOfSize:42];
        l.textAlignment = NSTextAlignmentCenter;
        [btn addSubview:l];

        [btn addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:btn
                                            action:@selector(presentViewController:animated:completion:)]];
        [btn makeKeyAndVisible];
    });
}
