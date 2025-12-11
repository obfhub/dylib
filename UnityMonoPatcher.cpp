#include <stdio.h>
#include <dlfcn.h>
#include <mach/mach.h>

// Define the Mono types and functions we need from the Mono runtime.
// This avoids needing the full Mono headers for a simple file.
typedef void* MonoDomain;
typedef void* MonoAssembly;
typedef void* MonoImage;
typedef void* MonoClass;
typedef void* MonoMethod;
typedef void* MonoObject;
typedef void* MonoString;

// Function pointers to the Mono API functions we will retrieve dynamically.
typedef MonoDomain* (*mono_get_root_domain_t)(void);
typedef MonoDomain (*mono_domain_get_t)(void);
typedef MonoAssembly* (*mono_domain_assembly_open_t)(MonoDomain domain, const char* assemblyName);
typedef MonoImage* (*mono_assembly_get_image_t)(MonoAssembly* assembly);
typedef MonoClass* (*mono_class_from_name_t)(MonoImage* image, const char* name_space, const char* name);
typedef MonoMethod* (*mono_class_get_method_from_name_t)(MonoClass* klass, const char* name, int param_count);
typedef MonoObject* (*mono_runtime_invoke_t)(MonoMethod* method, void* obj, void** params, MonoObject** exc);
typedef MonoString* (*mono_string_new_t)(MonoDomain domain, const char* text);

// Global function pointers
static mono_get_root_domain_t mono_get_root_domain = NULL;
static mono_domain_get_t mono_domain_get = NULL;
static mono_domain_assembly_open_t mono_domain_assembly_open = NULL;
static mono_assembly_get_image_t mono_assembly_get_image = NULL;
static mono_class_from_name_t mono_class_from_name = NULL;
static mono_class_get_method_from_name_t mono_class_get_method_from_name = NULL;
static mono_runtime_invoke_t mono_runtime_invoke = NULL;
static mono_string_new_t mono_string_new = NULL;

// Function to dynamically load the Mono library and get the function pointers.
bool load_mono_functions() {
    // The path to the Mono library inside a Unity iOS app is usually this.
    const char* mono_path = "/Frameworks/Mono/libmono.dylib";
    void* handle = dlopen(mono_path, RTLD_LAZY);
    if (!handle) {
        printf("[UnityMonoPatcher] Failed to load Mono library from %s\n", mono_path);
        return false;
    }

    // Load all the required functions
    mono_get_root_domain = (mono_get_root_domain_t)dlsym(handle, "mono_get_root_domain");
    mono_domain_get = (mono_domain_get_t)dlsym(handle, "mono_domain_get");
    mono_domain_assembly_open = (mono_domain_assembly_open_t)dlsym(handle, "mono_domain_assembly_open");
    mono_assembly_get_image = (mono_assembly_get_image_t)dlsym(handle, "mono_assembly_get_image");
    mono_class_from_name = (mono_class_from_name_t)dlsym(handle, "mono_class_from_name");
    mono_class_get_method_from_name = (mono_class_get_method_from_name_t)dlsym(handle, "mono_class_get_method_from_name");
    mono_runtime_invoke = (mono_runtime_invoke_t)dlsym(handle, "mono_runtime_invoke");
    mono_string_new = (mono_string_new_t)dlsym(handle, "mono_string_new");

    // Check that all functions were loaded successfully
    if (!mono_get_root_domain || !mono_domain_get || !mono_domain_assembly_open || !mono_assembly_get_image || !mono_class_from_name || !mono_class_get_method_from_name || !mono_runtime_invoke || !mono_string_new) {
        printf("[UnityMonoPatcher] Failed to load one or more Mono functions.\n");
        return false;
    }

    printf("[UnityMonoPatcher] Successfully loaded Mono functions.\n");
    return true;
}

// The main constructor function that runs on library load.
__attribute__((constructor)) void patch_unity_game() {
    printf("[UnityMonoPatcher] Initializing...\n");

    if (!load_mono_functions()) {
        return;
    }

    // Get the active Mono domain
    // CORRECTED: Changed from 'MonoDomain*' to 'MonoDomain' to fix the type mismatch.
    MonoDomain domain = mono_domain_get();
    if (!domain) {
        printf("[UnityMonoPatcher] Failed to get Mono domain.\n");
        return;
    }

    // Open the Assembly-CSharp.dll, which contains the game's C# code.
    MonoAssembly* assembly = mono_domain_assembly_open(domain, "Assembly-CSharp.dll");
    if (!assembly) {
        printf("[UnityMonoPatcher] Failed to open Assembly-CSharp.dll.\n");
        return;
    }

    // Get the image from the assembly to inspect its contents.
    MonoImage* image = mono_assembly_get_image(assembly);
    if (!image) {
        printf("[UnityMonoPatcher] Failed to get image from Assembly-CSharp.dll.\n");
        return;
    }

    // Find the "GameConfig" class. It's usually in the global namespace ('').
    MonoClass* gameConfigClass = mono_class_from_name(image, "", "GameConfig");
    if (!gameConfigClass) {
        printf("[UnityMonoPatcher] Failed to find class 'GameConfig'.\n");
        return;
    }

    printf("[UnityMonoPatcher] Found class 'GameConfig'.\n");

    // Find the "set_AimAssistAmount" method. The 'set_' prefix is how .NET compilers name property setters.
    MonoMethod* setMethod = mono_class_get_method_from_name(gameConfigClass, "set_AimAssistAmount", 1); // 1 parameter (the float value)
    if (!setMethod) {
        printf("[UnityMonoPatcher] Failed to find 'set_AimAssistAmount' method.\n");
        return;
    }

    printf("[UnityMonoPatcher] Found 'set_AimAssistAmount' method.\n");

    // Prepare the argument to pass to the setter method.
    float newValue = 100.0f;
    void* args[1];
    args[0] = &newValue;

    // Invoke the setter method. Since it's a static method, the second argument is NULL.
    mono_runtime_invoke(setMethod, NULL, args, NULL);

    printf("[UnityMonoPatcher] Successfully invoked 'set_AimAssistAmount' with value %.2f. Patch complete!\n", newValue);
}
