#import <Cocoa/Cocoa.h>
#include <dlfcn.h>
#include <stdio.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Create app so UI can live
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        void *h = dlopen("./libui.dylib", RTLD_NOW);
        if (!h) {
            printf("dlopen error: %s\n", dlerror());
            return 1;
        }

        printf("dylib loaded. Window should appear.\n");

        // Run the macOS event loop
        [NSApp run];

        dlclose(h);
    }
    return 0;
}
