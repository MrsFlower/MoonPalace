#ifdef _WIN32
#include <windows.h>
#include <wininet.h>
#pragma comment(lib, "wininet.lib")
#include <direct.h>
#else
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#endif

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// 16MB buffer for image downloads and large JSON
#define NET_BUFFER_SIZE (16 * 1024 * 1024)
static char* net_buffer = NULL;
static int net_buffer_len = 0;
static char net_path_buffer[1024];
static int net_path_len = 0;

void net_ensure_buffer() {
    if (net_buffer == NULL) {
        net_buffer = (char*)malloc(NET_BUFFER_SIZE);
        net_buffer_len = 0;
    }
}

void net_clear_path() {
    net_path_len = 0;
}

void net_append_path_char(int c) {
    if (net_path_len < sizeof(net_path_buffer) - 1) {
        net_path_buffer[net_path_len++] = (char)c;
    }
}

int worker_mkdir(int ignored) {
    net_path_buffer[net_path_len] = '\0';
#ifdef _WIN32
    return _mkdir(net_path_buffer);
#else
    return mkdir(net_path_buffer, 0777);
#endif
}

int worker_rename_file(int old_ptr, int new_ptr) {
    net_path_buffer[net_path_len] = '\0';
    net_ensure_buffer();
    net_buffer[net_buffer_len] = '\0';
#ifdef _WIN32
    // Windows rename might fail if new file exists. Remove it first.
    remove(net_buffer);
#endif
    return rename(net_path_buffer, net_buffer);
}

int worker_get_exe_dir() {
#ifdef _WIN32
    char exe_path[MAX_PATH];
    DWORD len = GetModuleFileNameA(NULL, exe_path, MAX_PATH);
    if (len == 0) return 0;
    
    char* last_slash = strrchr(exe_path, '\\');
    if (last_slash != NULL) {
        *last_slash = '\0';
        len = (DWORD)(last_slash - exe_path);
    }
    
    net_ensure_buffer();
    net_buffer_len = 0;
    for (DWORD i = 0; i < len; i++) {
        if (net_buffer_len < NET_BUFFER_SIZE) {
            net_buffer[net_buffer_len++] = exe_path[i];
        }
    }
    return (int)net_buffer_len;
#else
    return 0;
#endif
}

void net_clear_buffer() {
    net_ensure_buffer();
    net_buffer_len = 0;
}

#define INTERNET_OPTION_SECURE_PROTOCOLS 168

void net_append_char(int c) {
    if (net_buffer_len < NET_BUFFER_SIZE - 1) {
        net_buffer[net_buffer_len++] = (char)c;
    }
}

int net_get_char(int index) {
    if (index >= 0 && index < net_buffer_len) {
        return (int)(unsigned char)net_buffer[index];
    }
    return 0;
}

int net_get_len() {
    return net_buffer_len;
}

int64_t net_internet_open() {
#ifdef _WIN32
    HINTERNET hInt = InternetOpenA("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", INTERNET_OPEN_TYPE_PRECONFIG, NULL, NULL, 0);
    if (hInt) {
        DWORD timeout = 600000; // 10 minutes
        InternetSetOptionA(hInt, INTERNET_OPTION_RECEIVE_TIMEOUT, &timeout, sizeof(timeout));
        InternetSetOptionA(hInt, INTERNET_OPTION_SEND_TIMEOUT, &timeout, sizeof(timeout));
        InternetSetOptionA(hInt, INTERNET_OPTION_CONNECT_TIMEOUT, &timeout, sizeof(timeout));
        
        // Enable TLS 1.2 globally for the session (0x00000A80 is TLS 1.0|1.1|1.2)
        DWORD protocols = 0x00000A80;
        InternetSetOptionA(hInt, INTERNET_OPTION_SECURE_PROTOCOLS, &protocols, (DWORD)sizeof(protocols));
    }
    return (int64_t)(intptr_t)hInt;
#else
    printf("net_internet_open is not implemented for this platform yet.\n");
    return 0;
#endif
}

int64_t net_internet_connect(int64_t hInternet, int port, int is_https) {
#ifdef _WIN32
    // host is in net_buffer (null-terminated)
    net_ensure_buffer();
    net_buffer[net_buffer_len] = '\0';
    printf("C Connect: %s:%d\n", net_buffer, port);
    
    DWORD flags = 0;
    DWORD service = INTERNET_SERVICE_HTTP;
    return (int64_t)(intptr_t)InternetConnectA((HINTERNET)(intptr_t)hInternet, net_buffer, port, NULL, NULL, service, flags, 0);
#else
    return 0;
#endif
}

int64_t net_http_open_request(int64_t hConnect, int is_post, int is_https) {
#ifdef _WIN32
    // path is in net_buffer (null-terminated)
    net_ensure_buffer();
    net_buffer[net_buffer_len] = '\0';
    printf("C OpenRequest: %s (HTTPS: %d)\n", net_buffer, is_https);
    
    DWORD flags = INTERNET_FLAG_RELOAD | INTERNET_FLAG_NO_CACHE_WRITE;
    if (is_https) {
        flags |= INTERNET_FLAG_SECURE; // Require TLS
        flags |= INTERNET_FLAG_IGNORE_CERT_CN_INVALID;
        flags |= INTERNET_FLAG_IGNORE_CERT_DATE_INVALID;
    }
    const char* verb = is_post ? "POST" : "GET";
    HINTERNET hReq = HttpOpenRequestA((HINTERNET)(intptr_t)hConnect, verb, net_buffer, "HTTP/1.1", NULL, NULL, flags, 0);
    
    if (hReq) {
        DWORD timeout = 600000; // 10 minutes (600,000 ms)
        InternetSetOptionA(hReq, INTERNET_OPTION_RECEIVE_TIMEOUT, &timeout, sizeof(timeout));
        InternetSetOptionA(hReq, INTERNET_OPTION_SEND_TIMEOUT, &timeout, sizeof(timeout));
        InternetSetOptionA(hReq, INTERNET_OPTION_CONNECT_TIMEOUT, &timeout, sizeof(timeout));
        
        if (is_https) {
            DWORD securityFlags = 0;
            DWORD len = sizeof(securityFlags);
            InternetQueryOptionA(hReq, INTERNET_OPTION_SECURITY_FLAGS, &securityFlags, &len);
            securityFlags |= SECURITY_FLAG_IGNORE_UNKNOWN_CA |
                             SECURITY_FLAG_IGNORE_CERT_CN_INVALID |
                             SECURITY_FLAG_IGNORE_CERT_DATE_INVALID |
                             SECURITY_FLAG_IGNORE_REVOCATION; // Important for some APIs
            InternetSetOptionA(hReq, INTERNET_OPTION_SECURITY_FLAGS, &securityFlags, sizeof(securityFlags));
            
            // Force TLS 1.2
            // 0x00000800 = WININET_API_FLAG_USE_TLS1_2 equivalent if missing in old headers
            DWORD protocols = 0x00000800; 
            InternetSetOptionA((HINTERNET)(intptr_t)hConnect, INTERNET_OPTION_SECURE_PROTOCOLS, &protocols, (DWORD)sizeof(protocols));
        }
    }
    
    return (int64_t)(intptr_t)hReq;
#else
    return 0;
#endif
}

int net_http_add_header(int64_t hRequest) {
#ifdef _WIN32
    // header is in net_buffer
    net_ensure_buffer();
    return HttpAddRequestHeadersA((HINTERNET)(intptr_t)hRequest, net_buffer, net_buffer_len, HTTP_ADDREQ_FLAG_ADD | HTTP_ADDREQ_FLAG_REPLACE);
#else
    return 0;
#endif
}

int net_http_send_request(int64_t hRequest) {
#ifdef _WIN32
    // body is in net_buffer
    net_ensure_buffer();
    LPVOID body = net_buffer_len > 0 ? (LPVOID)net_buffer : NULL;
    BOOL res = HttpSendRequestA((HINTERNET)(intptr_t)hRequest, NULL, 0, body, net_buffer_len);
    if (!res) {
        DWORD err = GetLastError();
        printf("HttpSendRequestA failed with error: %lu\n", err);
        // Error 12029 is ERROR_INTERNET_CANNOT_CONNECT
        // Often due to TLS settings in wininet
    }
    return res;
#else
    return 0;
#endif
}

int net_http_get_status_code(int64_t hRequest) {
#ifdef _WIN32
    DWORD statusCode = 0;
    DWORD length = sizeof(DWORD);
    if (HttpQueryInfoA((HINTERNET)(intptr_t)hRequest, HTTP_QUERY_STATUS_CODE | HTTP_QUERY_FLAG_NUMBER, &statusCode, &length, NULL)) {
        return (int)statusCode;
    }
    return 0;
#else
    return 0;
#endif
}

int net_internet_read_file(int64_t hFile) {
#ifdef _WIN32
    // Reads up to 4MB chunks per call to avoid filling the 16MB buffer and crashing C FFI boundary
    net_ensure_buffer();
    DWORD dwRead = 0;
    DWORD to_read = 4 * 1024 * 1024; // 4MB
    if (to_read > NET_BUFFER_SIZE) to_read = NET_BUFFER_SIZE;
    BOOL bResult = InternetReadFile((HINTERNET)(intptr_t)hFile, net_buffer, to_read, &dwRead);
    if (!bResult) {
        net_buffer_len = 0;
        return -1; // Error
    }
    net_buffer_len = (int)dwRead;
    return net_buffer_len; // Bytes read
#else
    return 0;
#endif
}

void net_internet_close_handle(int64_t handle) {
#ifdef _WIN32
    if (handle) {
        InternetCloseHandle((HINTERNET)(intptr_t)handle);
    }
#endif
}

void worker_sleep(int ms) {
#ifdef _WIN32
    Sleep(ms);
#else
    usleep(ms * 1000);
#endif
}

int worker_get_random() {
    static int seeded = 0;
    if (!seeded) {
#ifdef _WIN32
        srand((unsigned int)time(NULL) ^ (unsigned int)GetCurrentProcessId());
#else
        srand((unsigned int)time(NULL) ^ (unsigned int)getpid());
#endif
        seeded = 1;
    }
    // Return a large random number (combining multiple rands to get more bits)
    return (rand() << 15) ^ rand();
}

// File I/O for Workers
int worker_read_file() {
    net_path_buffer[net_path_len] = '\0';
    FILE* f = fopen(net_path_buffer, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    net_ensure_buffer();
    if (size > NET_BUFFER_SIZE) size = NET_BUFFER_SIZE - 1;
    size_t read_bytes = fread(net_buffer, 1, size, f);
    net_buffer[read_bytes] = '\0';
    net_buffer_len = (int)read_bytes;
    fclose(f);
    return net_buffer_len;
}

int worker_write_file(int append) {
    net_path_buffer[net_path_len] = '\0';
    FILE* f = fopen(net_path_buffer, append ? "ab" : "wb");
    if (!f) return -1;
    size_t written = fwrite(net_buffer, 1, net_buffer_len, f);
    fclose(f);
    return (int)written;
}

int net_system_command_wrapper(int dummy) {
    if (!net_buffer) return -1;
    return system(net_buffer);
}
