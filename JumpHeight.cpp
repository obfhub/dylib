#include <substrate.h>
#include <UIKit/UIKit.h>
#include <cstdint>
#include <cstdio>

// --- Offsets (update if needed) ---
constexpr uintptr_t JUMP_HEIGHT_OFFSET = 0x4C; // JumpHeight in CharacterMotorConfig

// --- Global player pointer ---
void* g_PlayerPtr = nullptr; // Set this to your CharacterMotorConfig object pointer

// --- Patch function ---
void PatchJumpHeight(void* player) {
    if (!player) return;
    float* jumpHeightPtr = (float*)((uintptr_t)player + JUMP_HEIGHT_OFFSET);
    *jumpHeightPtr = 30.0f;
}

// --- Optional: Hooked Unity Update loop ---
typedef void (*UnityUpdate_t)();
UnityUpdate_t orig_UnityUpdate = nullptr;

void UnityUpdate_Hooked() {
    // Call original Update
    if (orig_UnityUpdate) orig_UnityUpdate();

    // Patch JumpHeight every frame
    PatchJumpHeight(g_PlayerPtr);
}

// --- dylib constructor ---
__attribute__((constructor))
static void init() {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"JumpHeight patch dylib loaded!");

        // TODO: Set g_PlayerPtr to actual CharacterMotorConfig pointer
        // g_PlayerPtr = <player pointer>;

        // TODO: Hook Unity Update if you want continuous patch
        // MSHookFunction((void*)UnityUpdateRVA, (void*)UnityUpdate_Hooked, (void**)&orig_UnityUpdate);

        // Or just patch once if pointer is valid
        PatchJumpHeight(g_PlayerPtr);
    });
}
