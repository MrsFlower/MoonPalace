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
    if (!IsCursorHidden()) {
        DisableCursor();
    }
}

void EnableCursor_wrapper() {
    if (IsCursorHidden()) {
        EnableCursor();
    }
}

void HideCursor_wrapper() {
    HideCursor();
}

void ShowCursor_wrapper() {
    ShowCursor();
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

#define MAX_CHUNKS 128
static Model chunk_models[MAX_CHUNKS] = { 0 };

void load_chunk_model_from_buffer(int index) {
    if (index < 0 || index >= MAX_CHUNKS) return;
    
    if (chunk_models[index].meshCount > 0) {
        UnloadModel(chunk_models[index]);
    }
    chunk_models[index] = LoadModel(text_buffer);
    
    // Auto-center logic but keeping spatial relation
    // Trellis chunks are originally exported by trimesh which usually retains absolute positions.
    // However, some GLB exporters might bake the offset into the vertices and some into the nodes.
    // Let's completely remove ANY translation matrix manipulation to ensure we render it EXACTLY as it is in the file.
    // Let's print out the bounds of each chunk to debug if they are all overlapping or flattened.
    if (chunk_models[index].meshCount > 0) {
        BoundingBox bounds = GetMeshBoundingBox(chunk_models[index].meshes[0]);
        printf("[DEBUG] Chunk %d loaded. Vertices: %d, Bounds: min(%.2f, %.2f, %.2f) max(%.2f, %.2f, %.2f)\n",
               index, chunk_models[index].meshes[0].vertexCount,
               bounds.min.x, bounds.min.y, bounds.min.z,
               bounds.max.x, bounds.max.y, bounds.max.z);
               
        for (int i = 0; i < chunk_models[index].materialCount; i++) {
            chunk_models[index].materials[i].maps[MATERIAL_MAP_DIFFUSE].color = WHITE;
        }
    }
}

void draw_chunk_model_wrapper(int index, double x, double y, double z, double scale) {
    if (index < 0 || index >= MAX_CHUNKS) return;
    if (chunk_models[index].meshCount == 0) return;
    
    rlDisableBackfaceCulling();
    
    float finalScale = (float)scale;
    Vector3 position = { (float)x, (float)y, (float)z };
    
    // Apply standard fix for Z-up GLB models in Raylib to make them stand up correctly.
    // Also, when models are exported in Python using trimesh, they often lose the "transform node" 
    // that GLTF provides for the Y-up / Z-up conversion. We apply it manually here.
    Vector3 rotationAxis = { 1.0f, 0.0f, 0.0f };
    float rotationAngle = -90.0f; // This rotates the flat model up.
    
    Vector3 scaleVec = { finalScale, finalScale, finalScale };
    
    DrawModelEx(chunk_models[index], position, rotationAxis, rotationAngle, scaleVec, WHITE);
    
    rlEnableBackfaceCulling();
}

#include <stdio.h>

void debug_global_model_wrapper() {
    printf("[DEBUG] debug_global_model_wrapper called.\n");
    if (global_model.meshCount > 0) {
        printf("[DEBUG] Model loaded with %d meshes.\n", global_model.meshCount);
        BoundingBox bounds = GetMeshBoundingBox(global_model.meshes[0]);
        printf("[DEBUG] Mesh 0 bounds: min(%.2f, %.2f, %.2f) max(%.2f, %.2f, %.2f)\n", 
            bounds.min.x, bounds.min.y, bounds.min.z,
            bounds.max.x, bounds.max.y, bounds.max.z);
        printf("[DEBUG] Mesh 0 vertices: %d, triangles: %d\n", 
            global_model.meshes[0].vertexCount, global_model.meshes[0].triangleCount);
            
        // 打印前 5 个顶点和纹理坐标看看是否有问题
        if (global_model.meshes[0].vertices != NULL) {
            for (int i = 0; i < 5 && i < global_model.meshes[0].vertexCount; i++) {
                printf("[DEBUG] Vertex %d: x=%.2f, y=%.2f, z=%.2f\n", 
                    i, 
                    global_model.meshes[0].vertices[i*3],
                    global_model.meshes[0].vertices[i*3+1],
                    global_model.meshes[0].vertices[i*3+2]);
            }
        }
        if (global_model.meshes[0].texcoords != NULL) {
            for (int i = 0; i < 5 && i < global_model.meshes[0].vertexCount; i++) {
                printf("[DEBUG] TexCoord %d: u=%.2f, v=%.2f\n", 
                    i, 
                    global_model.meshes[0].texcoords[i*2],
                    global_model.meshes[0].texcoords[i*2+1]);
            }
        } else {
            printf("[DEBUG] Mesh has NO texture coordinates.\n");
        }
        
        if (global_model.meshes[0].normals != NULL) {
            printf("[DEBUG] Mesh has normals.\n");
        } else {
            printf("[DEBUG] Mesh has NO normals.\n");
        }
        
        if (global_model.meshes[0].colors != NULL) {
            printf("[DEBUG] Mesh has vertex colors.\n");
        } else {
            printf("[DEBUG] Mesh has NO vertex colors.\n");
        }
        
    } else {
        printf("[DEBUG] No model loaded.\n");
    }
}
void load_global_model_from_buffer() {
    if (global_model.meshCount > 0) {
        UnloadModel(global_model);
    }
    global_model = LoadModel(text_buffer);
    
    // Auto-center the mesh but do not scale it
    if (global_model.meshCount > 0) {
        BoundingBox bounds = GetMeshBoundingBox(global_model.meshes[0]);
        Vector3 center = {
            (bounds.min.x + bounds.max.x) / 2.0f,
            bounds.min.y, // Keep the floor at y=0, rather than centering on y axis
            (bounds.min.z + bounds.max.z) / 2.0f
        };
        
        Matrix translation = MatrixTranslate(-center.x, -center.y, -center.z);
        global_model.transform = translation;
        
        // Raylib usually handles vertex colors natively if texture is absent, 
        // but we explicitly set the material color to WHITE to ensure it doesn't get tinted.
        for (int i = 0; i < global_model.materialCount; i++) {
            global_model.materials[i].maps[MATERIAL_MAP_DIFFUSE].color = WHITE;
        }
    }
}

void draw_global_model_wrapper(double x, double y, double z, double scale) {
    // Disable Backface Culling
    rlDisableBackfaceCulling();
    
    // Compute scale
    float finalScale = (float)scale;
    
    // Default Raylib expects models to have Y-up.
    // Trellis output bounds are: min(-0.50, -0.30, -0.50) max(0.50, 0.30, 0.50)
    // This is already a normalized -0.5 to 0.5 bounding box!
    // But it's very small. If we draw it with scale 1.0, it will be 1x1x1 unit.
    // If the user's camera is at Y=10.0 and looking at 0,0,0, a 1x1x1 model will be tiny.
    // Let's scale it by the user's scale parameter directly.
    // If the user passes scale=1.0, it stays 1.0. If the user passes scale=10.0, it becomes 10.0.
    
    Vector3 position = { (float)x, (float)y, (float)z };
    Vector3 rotationAxis = { 1.0f, 0.0f, 0.0f };
    float rotationAngle = 0.0f; // No rotation by default
    Vector3 scaleVec = { finalScale, finalScale, finalScale };
    
    // Trellis GLB models might not have a material assigned properly in raylib.
    // We already set this in load_global_model_from_buffer, so no need to do it here every frame.
    
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
