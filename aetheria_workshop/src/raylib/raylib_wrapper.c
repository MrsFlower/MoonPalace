#include <raylib.h>
#include <rlgl.h>
#include <raymath.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
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

void DrawRectangle_wrapper(int32_t posX, int32_t posY, int32_t width, int32_t height, int32_t r, int32_t g, int32_t b, int32_t a) {
    Color color = { (unsigned char)r, (unsigned char)g, (unsigned char)b, (unsigned char)a };
    DrawRectangle(posX, posY, width, height, color);
}

void DrawRectangleLines_wrapper(int32_t posX, int32_t posY, int32_t width, int32_t height, int32_t r, int32_t g, int32_t b, int32_t a) {
    Color color = { (unsigned char)r, (unsigned char)g, (unsigned char)b, (unsigned char)a };
    DrawRectangleLines(posX, posY, width, height, color);
}

int32_t GetMouseX_wrapper() {
    return GetMouseX();
}

int32_t GetMouseY_wrapper() {
    return GetMouseY();
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

int32_t GetCharPressed_wrapper() {
    return GetCharPressed();
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

double get_frame_time_wrapper() {
    return (double)GetFrameTime();
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
    
    // Removed the -90 degree rotation on the X-axis because the plaza was standing vertically like a wall.
    // Now it lies flat correctly.
    Vector3 rotationAxis = { 1.0f, 0.0f, 0.0f };
    float rotationAngle = 0.0f; 

    Vector3 scaleVec = { finalScale, finalScale, finalScale };
    
    DrawModelEx(chunk_models[index], position, rotationAxis, rotationAngle, scaleVec, WHITE);
    
    rlEnableBackfaceCulling();
}

// ==========================================
// CUSTOM .CHUNK FORMAT PARSER & RENDERER
// ==========================================

typedef struct VoxelChunk {
    int width;
    int height;
    int depth;
    int has_uv;
    unsigned char* data; // 1 for solid, 0 for empty
    float* uvs; // 16 floats per solid voxel
    Model instanced_model; // Used for instanced rendering
} VoxelChunk;

static VoxelChunk loaded_chunk = { 0 };
static Model chunk_model = { 0 };
static bool is_chunk_model_ready = false;

const char* fog_vs = 
"#version 330\n"
"in vec3 vertexPosition;\n"
"in vec2 vertexTexCoord;\n"
"in vec4 vertexColor;\n"
"out vec2 fragTexCoord;\n"
"out vec4 fragColor;\n"
"out float fragDistance;\n"
"uniform mat4 mvp;\n"
"void main() {\n"
"    fragTexCoord = vertexTexCoord;\n"
"    fragColor = vertexColor;\n"
"    vec4 pos = mvp * vec4(vertexPosition, 1.0);\n"
"    fragDistance = pos.z;\n"
"    gl_Position = pos;\n"
"}\n";

const char* fog_fs = 
"#version 330\n"
"in vec2 fragTexCoord;\n"
"in vec4 fragColor;\n"
"in float fragDistance;\n"
"out vec4 finalColor;\n"
"uniform sampler2D texture0;\n"
"void main() {\n"
"    vec4 texColor = texture(texture0, fragTexCoord);\n"
"    vec4 color = texColor * fragColor;\n"
"    float fogDensity = 0.012;\n"
"    float fogFactor = exp(-pow(fragDistance * fogDensity, 2.0));\n"
"    fogFactor = clamp(fogFactor, 0.0, 1.0);\n"
"    vec4 fogColor = vec4(0.53, 0.81, 0.92, 1.0);\n" // Sky Blue (135, 206, 235)
"    finalColor = mix(fogColor, color, fogFactor);\n"
"}\n";

void build_chunk_model() {
    if (loaded_chunk.data == NULL) return;
    
    int width = loaded_chunk.width;
    int height = loaded_chunk.height;
    int depth = loaded_chunk.depth;
    float v = 0.5f;
    
    int total_voxels = loaded_chunk.width * loaded_chunk.height * loaded_chunk.depth;
    
    // 1. Count exposed faces for memory allocation
    int face_count = 0;
    for (int i = 0; i < total_voxels; i++) {
        if (loaded_chunk.data[i] == 0) continue;
        int z = i / (width * height);
        int y = (i / width) % height;
        int x = i % width;
        
        if (y + 1 >= height || loaded_chunk.data[x + (y+1)*width + z*width*height] == 0) face_count++;
        if (y - 1 < 0 || loaded_chunk.data[x + (y-1)*width + z*width*height] == 0) face_count++;
        if (z + 1 >= depth || loaded_chunk.data[x + y*width + (z+1)*width*height] == 0) face_count++;
        if (z - 1 < 0 || loaded_chunk.data[x + y*width + (z-1)*width*height] == 0) face_count++;
        if (x + 1 >= width || loaded_chunk.data[(x+1) + y*width + z*width*height] == 0) face_count++;
        if (x - 1 < 0 || loaded_chunk.data[(x-1) + y*width + z*width*height] == 0) face_count++;
    }
    
    if (face_count == 0) return;
    printf("[VoxelRenderer] Compiling Mesh with %d exposed faces...\n", face_count);
    
    Mesh mesh = { 0 };
    mesh.triangleCount = face_count * 2;
    mesh.vertexCount = mesh.triangleCount * 3;
    mesh.vertices = (float *)MemAlloc(mesh.vertexCount * 3 * sizeof(float));
    mesh.normals = (float *)MemAlloc(mesh.vertexCount * 3 * sizeof(float));
    mesh.colors = (unsigned char *)MemAlloc(mesh.vertexCount * 4 * sizeof(unsigned char));
    if (loaded_chunk.has_uv) {
        mesh.texcoords = (float *)MemAlloc(mesh.vertexCount * 2 * sizeof(float));
    }
    
    int v_idx = 0;
    int n_idx = 0;
    int c_idx = 0;
    int t_idx = 0;
    
    float offset_x = -(width * v) / 2.0f;
    float offset_y = 0.0f;
    float offset_z = -(depth * v) / 2.0f;
    
    // Macro to add 2 triangles (6 vertices) for a Quad
    #define ADD_VERTEX(vx, vy, vz, nx, ny, nz, r, g, b, a, u, v_coord) \
        mesh.vertices[v_idx++] = (vx); mesh.vertices[v_idx++] = (vy); mesh.vertices[v_idx++] = (vz); \
        mesh.normals[n_idx++] = (nx); mesh.normals[n_idx++] = (ny); mesh.normals[n_idx++] = (nz); \
        mesh.colors[c_idx++] = (r); mesh.colors[c_idx++] = (g); mesh.colors[c_idx++] = (b); mesh.colors[c_idx++] = (a); \
        if (loaded_chunk.has_uv) { mesh.texcoords[t_idx++] = (u); mesh.texcoords[t_idx++] = (v_coord); }
    
    #define ADD_QUAD(v1x,v1y,v1z, u1,v1, v2x,v2y,v2z, u2,v2, v3x,v3y,v3z, u3,v3, v4x,v4y,v4z, u4,v4, nx,ny,nz, r,g,b) \
        ADD_VERTEX(v1x,v1y,v1z, nx,ny,nz, r,g,b,255, u1,v1) \
        ADD_VERTEX(v2x,v2y,v2z, nx,ny,nz, r,g,b,255, u2,v2) \
        ADD_VERTEX(v3x,v3y,v3z, nx,ny,nz, r,g,b,255, u3,v3) \
        ADD_VERTEX(v1x,v1y,v1z, nx,ny,nz, r,g,b,255, u1,v1) \
        ADD_VERTEX(v3x,v3y,v3z, nx,ny,nz, r,g,b,255, u3,v3) \
        ADD_VERTEX(v4x,v4y,v4z, nx,ny,nz, r,g,b,255, u4,v4)
        
    int solid_idx = 0;
    for (int i = 0; i < total_voxels; i++) {
        if (loaded_chunk.data[i] == 0) continue;
        int z = i / (width * height);
        int y = (i / width) % height;
        int x = i % width;
        
        float px = offset_x + x * v;
        float py = offset_y + y * v;
        float pz = offset_z + z * v;
        
        // Simple height-based grayscale coloring for testing
        unsigned char cr = 200 - (y * 2);
        unsigned char cg = 200 - (y * 2);
        unsigned char cb = 200 - (y * 2);
        if (y * 2 > 150) { cr = 50; cg = 50; cb = 50; }
        
        if (loaded_chunk.has_uv) {
            cr = 255; cg = 255; cb = 255; // White base color if textured
        }
        
        // UV array indexing
        float* uv = loaded_chunk.has_uv ? &loaded_chunk.uvs[solid_idx * 16] : NULL;
        
        // Corner mapping:
        // 0: (0,0,0)  1: (1,0,0)  2: (0,1,0)  3: (1,1,0)
        // 4: (0,0,1)  5: (1,0,1)  6: (0,1,1)  7: (1,1,1)
        #define GET_U(c) (uv ? uv[(c)*2] : 0.0f)
        #define GET_V(c) (uv ? uv[(c)*2+1] : 0.0f)
        
        // Top (+Y)
        if (y + 1 >= height || loaded_chunk.data[x + (y+1)*width + z*width*height] == 0) {
            unsigned char c = (unsigned char)(cr + 20); if(c>255) c=255;
            if (loaded_chunk.has_uv) c = 255;
            ADD_QUAD(px,py+v,pz,   GET_U(2),GET_V(2),
                     px,py+v,pz+v, GET_U(6),GET_V(6),
                     px+v,py+v,pz+v, GET_U(7),GET_V(7),
                     px+v,py+v,pz, GET_U(3),GET_V(3),
                     0,1,0, c,c,c);
        }
        // Bottom (-Y)
        if (y - 1 < 0 || loaded_chunk.data[x + (y-1)*width + z*width*height] == 0) {
            unsigned char c = (unsigned char)(cr - 40); if(cr<40) c=0;
            if (loaded_chunk.has_uv) c = 120;
            ADD_QUAD(px,py,pz+v, GET_U(4),GET_V(4),
                     px,py,pz,   GET_U(0),GET_V(0),
                     px+v,py,pz, GET_U(1),GET_V(1),
                     px+v,py,pz+v, GET_U(5),GET_V(5),
                     0,-1,0, c,c,c);
        }
        // Front (+Z)
        if (z + 1 >= depth || loaded_chunk.data[x + y*width + (z+1)*width*height] == 0) {
            unsigned char c = (unsigned char)(cr - 10); if(cr<10) c=0;
            if (loaded_chunk.has_uv) c = 210;
            ADD_QUAD(px,py,pz+v,     GET_U(4),GET_V(4),
                     px+v,py,pz+v,   GET_U(5),GET_V(5),
                     px+v,py+v,pz+v, GET_U(7),GET_V(7),
                     px,py+v,pz+v,   GET_U(6),GET_V(6),
                     0,0,1, c,c,c);
        }
        // Back (-Z)
        if (z - 1 < 0 || loaded_chunk.data[x + y*width + (z-1)*width*height] == 0) {
            unsigned char c = (unsigned char)(cr - 10); if(cr<10) c=0;
            if (loaded_chunk.has_uv) c = 210;
            ADD_QUAD(px+v,py,pz,   GET_U(1),GET_V(1),
                     px,py,pz,     GET_U(0),GET_V(0),
                     px,py+v,pz,   GET_U(2),GET_V(2),
                     px+v,py+v,pz, GET_U(3),GET_V(3),
                     0,0,-1, c,c,c);
        }
        // Right (+X)
        if (x + 1 >= width || loaded_chunk.data[(x+1) + y*width + z*width*height] == 0) {
            unsigned char c = cr;
            if (loaded_chunk.has_uv) c = 180;
            ADD_QUAD(px+v,py,pz+v,   GET_U(5),GET_V(5),
                     px+v,py,pz,     GET_U(1),GET_V(1),
                     px+v,py+v,pz,   GET_U(3),GET_V(3),
                     px+v,py+v,pz+v, GET_U(7),GET_V(7),
                     1,0,0, c,c,c);
        }
        // Left (-X)
        if (x - 1 < 0 || loaded_chunk.data[(x-1) + y*width + z*width*height] == 0) {
            unsigned char c = cr;
            if (loaded_chunk.has_uv) c = 180;
            ADD_QUAD(px,py,pz,     GET_U(0),GET_V(0),
                     px,py,pz+v,   GET_U(4),GET_V(4),
                     px,py+v,pz+v, GET_U(6),GET_V(6),
                     px,py+v,pz,   GET_U(2),GET_V(2),
                     -1,0,0, c,c,c);
        }
        solid_idx++;
    }
    
    UploadMesh(&mesh, false);
    chunk_model = LoadModelFromMesh(mesh);
    
    // Apply custom distance fog shader
    Shader fog_shader = LoadShaderFromMemory(fog_vs, fog_fs);
    chunk_model.materials[0].shader = fog_shader;
    
    is_chunk_model_ready = true;
    printf("[VoxelRenderer] Mesh compiled and uploaded to GPU successfully.\n");
}

void load_custom_chunk(int index) {
    // For now we just load it into a global variable since we only have one chunk
    FILE* file = fopen(text_buffer, "rb");
    if (!file) {
        printf("Failed to open .chunk file: %s\n", text_buffer);
        return;
    }
    
    char magic[4];
    fread(magic, 1, 4, file);
    if (magic[0] != 'C' || magic[1] != 'H' || magic[2] != 'N' || magic[3] != 'K') {
        printf("Invalid magic number in .chunk file.\n");
        fclose(file);
        return;
    }
    
    int version;
    fread(&version, 4, 1, file);
    fread(&loaded_chunk.width, 4, 1, file);
    fread(&loaded_chunk.height, 4, 1, file);
    fread(&loaded_chunk.depth, 4, 1, file);
    
    // Skip 8 bytes of voxel_size (double)
    fseek(file, 8, SEEK_CUR);
    fread(&loaded_chunk.has_uv, 4, 1, file);
    
    int total_voxels = loaded_chunk.width * loaded_chunk.height * loaded_chunk.depth;
    printf("Loading .chunk: %d x %d x %d (Total %d voxels), has_uv: %d\n", 
        loaded_chunk.width, loaded_chunk.height, loaded_chunk.depth, total_voxels, loaded_chunk.has_uv);
        
    if (loaded_chunk.data != NULL) {
        free(loaded_chunk.data);
    }
    loaded_chunk.data = (unsigned char*)malloc(total_voxels);
    fread(loaded_chunk.data, 1, total_voxels, file);
    
    if (loaded_chunk.has_uv) {
        int solid_count = 0;
        for (int i = 0; i < total_voxels; i++) {
            if (loaded_chunk.data[i] != 0) solid_count++;
        }
        loaded_chunk.uvs = (float*)malloc(solid_count * 16 * sizeof(float));
        fread(loaded_chunk.uvs, sizeof(float), solid_count * 16, file);
        printf("[DEBUG] Chunk has UVs. Read %d solid voxels UV data. First voxel UV0: %f, %f\n", solid_count, loaded_chunk.uvs[0], loaded_chunk.uvs[1]);
    }

    fclose(file);
    
    // Automatically build the optimized mesh once loaded
    build_chunk_model();
}

void bind_atlas_to_chunk() {
    if (chunk_model.meshCount > 0 && current_atlas.id != 0) {
        chunk_model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = current_atlas;
    }
}

void draw_custom_chunk() {
    if (loaded_chunk.data == NULL) return;
    
    if (is_chunk_model_ready) {
        Vector3 position = { 0.0f, 0.0f, 0.0f };
        DrawModel(chunk_model, position, 1.0f, WHITE);
    }
}

int32_t get_voxel_at_wrapper(double x, double y, double z) {
    if (loaded_chunk.data == NULL) return 0;
    
    // Chunk origin logic from build_chunk_model:
    float v = 0.5f;
    float offset_x = -(loaded_chunk.width * v) / 2.0f;
    float offset_y = 0.0f;
    float offset_z = -(loaded_chunk.depth * v) / 2.0f;
    
    // Convert world space coordinates back to grid indices
    int grid_x = (int)round((x - offset_x) / v);
    int grid_y = (int)round((y - offset_y) / v);
    int grid_z = (int)round((z - offset_z) / v);
    
    if (grid_x < 0 || grid_x >= loaded_chunk.width ||
        grid_y < 0 || grid_y >= loaded_chunk.height ||
        grid_z < 0 || grid_z >= loaded_chunk.depth) {
        return 0; // Out of bounds is empty (air)
    }
    
    int index = grid_x + grid_y * loaded_chunk.width + grid_z * loaded_chunk.width * loaded_chunk.height;
    return loaded_chunk.data[index] != 0 ? 1 : 0;
}

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
