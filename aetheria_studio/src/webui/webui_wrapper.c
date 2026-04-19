#include "webui.h"
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#ifdef _WIN32
#include <windows.h>
static CRITICAL_SECTION moonbit_mutex;
static int mutex_initialized = 0;
#else
#include <pthread.h>
static pthread_mutex_t moonbit_mutex = PTHREAD_MUTEX_INITIALIZER;
static int mutex_initialized = 1;
#endif

// Initialize the mutex (called once before webui starts)
void init_moonbit_mutex() {
#ifdef _WIN32
    if (!mutex_initialized) {
        InitializeCriticalSection(&moonbit_mutex);
        mutex_initialized = 1;
    }
#endif
}

void lock_moonbit() {
#ifdef _WIN32
    if (mutex_initialized) EnterCriticalSection(&moonbit_mutex);
#else
    pthread_mutex_lock(&moonbit_mutex);
#endif
}

void unlock_moonbit() {
#ifdef _WIN32
    if (mutex_initialized) LeaveCriticalSection(&moonbit_mutex);
#else
    pthread_mutex_unlock(&moonbit_mutex);
#endif
}

// Use Thread-Local Storage (TLS) to make the text buffer thread-safe
// This prevents multiple WebUI threads from corrupting the buffer concurrently
#ifdef _MSC_VER
static __declspec(thread) char* dynamic_text_buffer = NULL;
static __declspec(thread) int dynamic_text_len = 0;
static __declspec(thread) int dynamic_text_cap = 0;
#else
static __thread char* dynamic_text_buffer = NULL;
static __thread int dynamic_text_len = 0;
static __thread int dynamic_text_cap = 0;
#endif

void clear_text_buffer() {
    if (dynamic_text_buffer == NULL) {
        dynamic_text_cap = 8192;
        dynamic_text_buffer = (char*)malloc(dynamic_text_cap);
    }
    dynamic_text_len = 0;
    dynamic_text_buffer[0] = '\0';
}

void append_text_char(int32_t c) {
    if (dynamic_text_len + 2 >= dynamic_text_cap) {
        dynamic_text_cap *= 2;
        dynamic_text_buffer = (char*)realloc(dynamic_text_buffer, dynamic_text_cap);
    }
    dynamic_text_buffer[dynamic_text_len++] = (char)c;
    dynamic_text_buffer[dynamic_text_len] = '\0';
}

int64_t webui_new_window_wrapper() {
    return (int64_t)webui_new_window();
}

int32_t webui_show_wrapper(int64_t window) {
    return (int32_t)webui_show((size_t)window, dynamic_text_buffer);
}

int32_t webui_show_browser_wrapper(int64_t window, int32_t browser) {
    bool res = webui_show_browser((size_t)window, dynamic_text_buffer, (size_t)browser);
    if (!res) {
        printf("DEBUG [C]: webui_show_browser failed! Falling back to webui_show\n");
        return (int32_t)webui_show((size_t)window, dynamic_text_buffer);
    }
    return (int32_t)res;
}

void webui_set_timeout_wrapper(int32_t second) {
    webui_set_timeout((size_t)second);
}

void webui_wait_wrapper() {
    webui_wait();
}

void webui_exit_wrapper() {
    webui_exit();
}

void webui_run_wrapper(int64_t window) {
    webui_run((size_t)window, dynamic_text_buffer);
}

void webui_navigate_wrapper(int64_t window) {
    webui_navigate((size_t)window, dynamic_text_buffer);
}

int32_t webui_set_root_folder_wrapper(int64_t window) {
    return (int32_t)webui_set_root_folder((size_t)window, dynamic_text_buffer);
}

extern int32_t _M0FP48username16aetheria__studio3src5webui30moonbit__webui__dispatcher__v2(int64_t window, int64_t event_type, int64_t element_ptr, int64_t data_ptr, int64_t event_number);

void global_webui_callback_v2(webui_event_t *e) {
    const char* data = webui_get_string(e);
    
    // MoonBit Native's Garbage Collector and Allocator are NOT thread-safe!
    // Since WebUI uses a thread pool, concurrent WebSocket messages will execute this 
    // callback simultaneously on multiple threads. If multiple threads enter MoonBit 
    // and allocate objects simultaneously, the heap pointer corrupts and the process crashes instantly.
    // We MUST lock before entering MoonBit code.
    lock_moonbit();
    
    _M0FP48username16aetheria__studio3src5webui30moonbit__webui__dispatcher__v2((int64_t)e->window, (int64_t)e->event_type, (int64_t)(intptr_t)e->element, (int64_t)(intptr_t)data, (int64_t)e->event_number);
    
    unlock_moonbit();
}

int64_t webui_bind_wrapper_v2(int64_t window) {
    return (int64_t)webui_bind((size_t)window, dynamic_text_buffer, global_webui_callback_v2);
}

void webui_return_string_wrapper(int64_t window, int64_t event_number) {
    webui_interface_set_response((size_t)window, (size_t)event_number, dynamic_text_buffer);
}

int32_t webui_get_string_char(int64_t ptr, int32_t index) {
    const unsigned char* str = (const unsigned char*)(intptr_t)ptr;
    if (str == NULL) return 0;
    return (int32_t)str[index];
}

void system_command_wrapper() {
    system(dynamic_text_buffer);
}

int64_t get_env_wrapper() {
    char* val = getenv(dynamic_text_buffer);
    if (val == NULL) return 0;
    return (int64_t)(intptr_t)val;
}

int64_t webui_get_url_wrapper(int64_t window) {
    const char* url = webui_get_url((size_t)window);
    if (url == NULL) return 0;
    return (int64_t)(intptr_t)url;
}

int32_t get_time_wrapper() {
    return (int32_t)time(NULL);
}
