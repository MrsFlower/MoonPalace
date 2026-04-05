#include <raylib.h>
#include <rlgl.h>
#include <raymath.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Text buffer to safely receive string data from Moonbit
static char text_buffer[1024];
static int text_len = 0;

void clear_text_buffer() {
    text_len = 0;
    text_buffer[0] = '\0';
}

void append_text_char(int32_t c) {
    if (text_len < 1023) {
        text_buffer[text_len++] = (char)c;
        text_buffer[text_len] = '\0';
    }
}

static Texture2D current_atlas = {0};

void load_atlas_from_buffer() {
    if (current_atlas.id != 0) {
        UnloadTexture(current_atlas);
    }
    current_atlas = LoadTexture(text_buffer);
}

void begin_voxel_batch() {
    rlSetTexture(current_atlas.id);
    rlBegin(RL_QUADS);
    rlColor4ub(255, 255, 255, 255);
}

void end_voxel_batch() {
    rlEnd();
    rlSetTexture(0);
}

// 绘制一个带贴图的立方体，贴图取自 atlas 中指定的 UV 区域 (u, v, width, height)
void draw_voxel_faces(double x, double y, double z, double size, 
                      double u, double v, double uv_w, double uv_h) {
    float xf = (float)x;
    float yf = (float)y;
    float zf = (float)z;
    float s = (float)(size / 2.0);
    
    // Front Face
    rlNormal3f(0.0f, 0.0f, 1.0f);
    rlTexCoord2f(u, v + uv_h); rlVertex3f(xf - s, yf - s, zf + s);
    rlTexCoord2f(u + uv_w, v + uv_h); rlVertex3f(xf + s, yf - s, zf + s);
    rlTexCoord2f(u + uv_w, v); rlVertex3f(xf + s, yf + s, zf + s);
    rlTexCoord2f(u, v); rlVertex3f(xf - s, yf + s, zf + s);

    // Back Face
    rlNormal3f(0.0f, 0.0f, -1.0f);
    rlTexCoord2f(u + uv_w, v + uv_h); rlVertex3f(xf - s, yf - s, zf - s);
    rlTexCoord2f(u + uv_w, v); rlVertex3f(xf - s, yf + s, zf - s);
    rlTexCoord2f(u, v); rlVertex3f(xf + s, yf + s, zf - s);
    rlTexCoord2f(u, v + uv_h); rlVertex3f(xf + s, yf - s, zf - s);

    // Top Face
    rlNormal3f(0.0f, 1.0f, 0.0f);
    rlTexCoord2f(u, v + uv_h); rlVertex3f(xf - s, yf + s, zf - s);
    rlTexCoord2f(u, v); rlVertex3f(xf - s, yf + s, zf + s);
    rlTexCoord2f(u + uv_w, v); rlVertex3f(xf + s, yf + s, zf + s);
    rlTexCoord2f(u + uv_w, v + uv_h); rlVertex3f(xf + s, yf + s, zf - s);

    // Bottom Face
    rlNormal3f(0.0f, -1.0f, 0.0f);
    rlTexCoord2f(u + uv_w, v + uv_h); rlVertex3f(xf - s, yf - s, zf - s);
    rlTexCoord2f(u, v + uv_h); rlVertex3f(xf + s, yf - s, zf - s);
    rlTexCoord2f(u, v); rlVertex3f(xf + s, yf - s, zf + s);
    rlTexCoord2f(u + uv_w, v); rlVertex3f(xf - s, yf - s, zf + s);

    // Right face
    rlNormal3f(1.0f, 0.0f, 0.0f);
    rlTexCoord2f(u + uv_w, v + uv_h); rlVertex3f(xf + s, yf - s, zf - s);
    rlTexCoord2f(u + uv_w, v); rlVertex3f(xf + s, yf + s, zf - s);
    rlTexCoord2f(u, v); rlVertex3f(xf + s, yf + s, zf + s);
    rlTexCoord2f(u, v + uv_h); rlVertex3f(xf + s, yf - s, zf + s);

    // Left Face
    rlNormal3f(-1.0f, 0.0f, 0.0f);
    rlTexCoord2f(u, v + uv_h); rlVertex3f(xf - s, yf - s, zf - s);
    rlTexCoord2f(u + uv_w, v + uv_h); rlVertex3f(xf - s, yf - s, zf + s);
    rlTexCoord2f(u + uv_w, v); rlVertex3f(xf - s, yf + s, zf + s);
    rlTexCoord2f(u, v); rlVertex3f(xf - s, yf + s, zf - s);
}

void draw_text_from_buffer(int32_t x, int32_t y, int32_t fontSize, int32_t r, int32_t g, int32_t b, int32_t a) {
    Color color = { (unsigned char)r, (unsigned char)g, (unsigned char)b, (unsigned char)a };
    DrawText(text_buffer, x, y, fontSize, color);
}

void DrawFPS_wrapper(int32_t x, int32_t y) {
    DrawFPS(x, y);
}

void InitWindow_wrapper(int32_t width, int32_t height) {
    InitWindow(width, height, text_len > 0 ? text_buffer : "Aetheria3D Engine");
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

// Input Wrappers
int32_t IsKeyDown_wrapper(int32_t key) {
    return IsKeyDown(key) ? 1 : 0;
}

int32_t IsKeyPressed_wrapper(int32_t key) {
    return IsKeyPressed(key) ? 1 : 0;
}

int32_t IsMouseButtonDown_wrapper(int32_t button) {
    return IsMouseButtonDown(button) ? 1 : 0;
}

int32_t IsMouseButtonPressed_wrapper(int32_t button) {
    return IsMouseButtonPressed(button) ? 1 : 0;
}

double GetMouseDeltaX_wrapper() {
    return (double)GetMouseDelta().x;
}

double GetMouseDeltaY_wrapper() {
    return (double)GetMouseDelta().y;
}

double get_mouse_wheel_move_wrapper() {
    return (double)GetMouseWheelMove();
}

// Camera and Model Wrappers
static Camera3D current_camera = { 0 };

void setup_camera(double cam_px, double cam_py, double cam_pz, 
                  double tar_x, double tar_y, double tar_z, 
                  double up_x, double up_y, double up_z, 
                  double fovy) {
    current_camera.position = (Vector3){ (float)cam_px, (float)cam_py, (float)cam_pz };
    current_camera.target = (Vector3){ (float)tar_x, (float)tar_y, (float)tar_z };
    current_camera.up = (Vector3){ (float)up_x, (float)up_y, (float)up_z };
    current_camera.fovy = (float)fovy;
    current_camera.projection = CAMERA_PERSPECTIVE;
}

void DisableCursor_wrapper() {
    DisableCursor();
}

void EnableCursor_wrapper() {
    EnableCursor();
}

void update_camera_wrapper(int32_t mode) {
    UpdateCamera(&current_camera, mode);
}

void UpdateCameraPro_wrapper(double movement_x, double movement_y, double movement_z, double rotation_x, double rotation_y, double rotation_z, double zoom) {
    Vector3 movement = { (float)movement_x, (float)movement_y, (float)movement_z };
    Vector3 rotation = { (float)rotation_x, (float)rotation_y, (float)rotation_z };
    UpdateCameraPro(&current_camera, movement, rotation, (float)zoom);
}

double get_camera_position_x_wrapper() {
    return (double)current_camera.position.x;
}

double get_camera_position_y_wrapper() {
    return (double)current_camera.position.y;
}

double get_camera_position_z_wrapper() {
    return (double)current_camera.position.z;
}

void set_camera_position_wrapper(double x, double y, double z) {
    current_camera.position.x = (float)x;
    current_camera.position.y = (float)y;
    current_camera.position.z = (float)z;
}
void begin_mode_3d_wrapper(double cam_px, double cam_py, double cam_pz, 
                           double tar_x, double tar_y, double tar_z, 
                           double up_x, double up_y, double up_z, 
                           double fovy) {
    current_camera.position = (Vector3){ (float)cam_px, (float)cam_py, (float)cam_pz };
    current_camera.target = (Vector3){ (float)tar_x, (float)tar_y, (float)tar_z };
    current_camera.up = (Vector3){ (float)up_x, (float)up_y, (float)up_z };
    current_camera.fovy = (float)fovy;
    current_camera.projection = CAMERA_PERSPECTIVE;
    BeginMode3D(current_camera);
}

void begin_mode_3d_current_camera_wrapper() {
    BeginMode3D(current_camera);
}

void EndMode3D_wrapper() {
    EndMode3D();
}

// Simple Model Loading (Stores globally to avoid managing pointers in Moonbit C backend for now)
static Model global_model = { 0 };

void load_global_model_from_buffer() {
    if (global_model.meshCount > 0) {
        UnloadModel(global_model);
    }
    global_model = LoadModel(text_buffer);
    
    // Auto-center and normalize size
    if (global_model.meshCount > 0) {
        BoundingBox bounds = GetMeshBoundingBox(global_model.meshes[0]);
        // Shift model meshes to center
        Vector3 center = {
            (bounds.min.x + bounds.max.x) / 2.0f,
            (bounds.min.y + bounds.max.y) / 2.0f,
            (bounds.min.z + bounds.max.z) / 2.0f
        };
        
        float sizeX = bounds.max.x - bounds.min.x;
        float sizeY = bounds.max.y - bounds.min.y;
        float sizeZ = bounds.max.z - bounds.min.z;
        float maxSize = sizeX > sizeY ? (sizeX > sizeZ ? sizeX : sizeZ) : (sizeY > sizeZ ? sizeY : sizeZ);
        
        // Instead of scaling matrix which might break normals, let's just use it in DrawModelEx.
        // We only translate here.
        Matrix translation = MatrixTranslate(-center.x, -center.y, -center.z);
        global_model.transform = translation;
        
        // Save the scale factor globally if we want to apply it in draw, 
        // but for now let's just let the user scale it in the draw call
        // Actually, Trellis outputs are sometimes very small, like 0.05. 
        // We will scale by 1.0 / maxSize during draw.
    }
}

void draw_global_model_wrapper(double x, double y, double z, double scale) {
    // 渲染 Trellis GLB 时，模型有时候网格混乱是因为背面剔除(Backface Culling)
    // 但 Trellis 经常生成内部多边形，或者法线有问题。我们尝试禁用剔除看看。
    rlDisableBackfaceCulling();
    
    // Compute scale
    float finalScale = (float)scale;
    if (global_model.meshCount > 0) {
        BoundingBox bounds = GetMeshBoundingBox(global_model.meshes[0]);
        float sizeX = bounds.max.x - bounds.min.x;
        float sizeY = bounds.max.y - bounds.min.y;
        float sizeZ = bounds.max.z - bounds.min.z;
        float maxSize = sizeX > sizeY ? (sizeX > sizeZ ? sizeX : sizeZ) : (sizeY > sizeZ ? sizeY : sizeZ);
        if (maxSize > 0.0001f) {
            finalScale *= (1.0f / maxSize) * 10.0f; // normalize to size 10.0
        }
    }
    
    Vector3 position = { (float)x, (float)y, (float)z };
    Vector3 rotationAxis = { 1.0f, 0.0f, 0.0f }; // rotate around X
    float rotationAngle = -90.0f; // 大部分 GLB 是 Y up
    Vector3 scaleVec = { finalScale, finalScale, finalScale };
    
    DrawModelEx(global_model, position, rotationAxis, rotationAngle, scaleVec, WHITE);
    
    rlEnableBackfaceCulling();
}

void DrawCube_wrapper(double x, double y, double z, double w, double h, double l, int32_t r, int32_t g, int32_t b, int32_t a) {
    Color color = { (unsigned char)r, (unsigned char)g, (unsigned char)b, (unsigned char)a };
    DrawCube((Vector3){(float)x, (float)y, (float)z}, (float)w, (float)h, (float)l, color);
}

void DrawCubeWires_wrapper(double x, double y, double z, double w, double h, double l, int32_t r, int32_t g, int32_t b, int32_t a) {
    Color color = { (unsigned char)r, (unsigned char)g, (unsigned char)b, (unsigned char)a };
    DrawCubeWires((Vector3){(float)x, (float)y, (float)z}, (float)w, (float)h, (float)l, color);
}

void DrawGrid_wrapper(int32_t slices, double spacing) {
    DrawGrid(slices, (float)spacing);
}
