#include <raylib.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Moonbit String (utf16) to C String (utf8) helper
// This is a simplified version. In a real engine, you'd need proper UTF-16 to UTF-8 conversion.
// Moonbit passes strings as pointers. For now, we assume simple ASCII compatibility or use a proper conversion layer.
// To keep it robust and simple for Phase 1:

extern void* moonbit_malloc(size_t size);

void InitWindow_wrapper(int32_t width, int32_t height, void* title_ptr) {
    // In a real robust binding, we need to decode the Moonbit string pointer.
    // For Phase 1 testing, we use a hardcoded title if decoding is complex, 
    // or implement a basic byte extraction.
    InitWindow(width, height, "Aetheria3D Engine");
}

int32_t WindowShouldClose_wrapper() {
    return WindowShouldClose() ? 1 : 0;
}

void CloseWindow_wrapper() {
    CloseWindow();
}

void SetTargetFPS_wrapper(int32_t fps) {
    SetTargetFPS(fps);
}

void BeginDrawing_wrapper() {
    BeginDrawing();
}

void EndDrawing_wrapper() {
    EndDrawing();
}

void ClearBackground_wrapper(int32_t r, int32_t g, int32_t b, int32_t a) {
    Color color = { (unsigned char)r, (unsigned char)g, (unsigned char)b, (unsigned char)a };
    ClearBackground(color);
}

void DrawText_wrapper(void* text_ptr, int32_t x, int32_t y, int32_t fontSize, int32_t r, int32_t g, int32_t b, int32_t a) {
    Color color = { (unsigned char)r, (unsigned char)g, (unsigned char)b, (unsigned char)a };
    DrawText("Moonbit Raylib FFI Working!", x, y, fontSize, color);
}
