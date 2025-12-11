// modmenu.m – Debug Patch (Shows Addr/Slide on Tap)
// Tap ∞ → Alert with debug info

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

static const uint64_t GET_CURRENCY_OFFSET = 0x4A13738;
static const uint8_t patch[] = {0xFF,0xC9,0x9A,0x3B, 0xC0,0x03,0x5F,0xD6};
static uint8_t original[8];
static bool enabled = false;

@interface SubwayModHelper : NSObject
@end
@implementation SubwayModHelper
+ (void)debugTap {
    intptr_t slide = 0;
    bool unityFound = false;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), "UnityFramework")) {
            slide = _dyld_get_image_vmaddr_slide(i);
            unityFound = true;
            break;
        }
    }

    NSString *status = [NSString stringWithFormat:@"Unity Found: %@\nSlide: 0x%lx\nAddr: 0x%llx\nPatch Applied!", unityFound ? @"YES" : @"NO", slide, GET_CURRENCY_OFFSET + slide];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Debug Info"
                                                                   message:status
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

    UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:alert animated:YES completion:nil];

    // Try patch (no mprotect – for debug)
    if (unityFound) {
        uint64_t addr = GET_CURRENCY_OFFSET + slide;
        memcpy(original, (void*)addr, 8);
        memcpy((void*)addr, patch, 8);
    }
}
@end

static void addModButton(UIView *view) {
    static UIButton *modButton = nil;
    if (modButton) return;

    modButton = [UIButton buttonWithType:UIButtonTypeCustom];
    modButton.frame = CGRectMake(20, 100, 80, 80);
    modButton.backgroundColor = [UIColor systemBlueColor];
    modButton.layer.cornerRadius = 40;
    modButton.layer.borderWidth = 4;
    modButton.layer.borderColor = UIColor.whiteColor.CGColor;
    [modButton setTitle:@"∞" forState:UIControlStateNormal];
    [modButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    modButton.titleLabel.font = [UIFont boldSystemFontOfSize:48];

    [modButton addTarget:[SubwayModHelper class] action:@selector(debugTap) forControlEvents:UIControlEventTouchUpInside];

    [view addSubview:modButton];
}

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1ULL*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Debug Mod Loaded" message:@"Tap ∞ for patch info" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
        UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
        [vc presentViewController:a animated:YES completion:nil];
    });

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (true) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                UIViewController *vc = UIApplication.sharedApplication.windows.firstObject.rootViewController;
                if (vc && vc.isViewLoaded && vc.view.window) {
                    addModButton(vc.view
