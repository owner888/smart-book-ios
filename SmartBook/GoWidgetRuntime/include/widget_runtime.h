#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*widget_event_cb)(int64_t handle, const char* event, const char* message, void* user_data);

int32_t wr_init(const char* widget_dir, const char* data_dir);

int64_t wr_create(const char* widget_path, widget_event_cb cb, void* user_data);
void    wr_destroy(int64_t handle);

int32_t wr_start(int64_t handle, const char* initial_script_json);
int32_t wr_stop(int64_t handle);

char*   wr_run(int64_t handle, const char* script);

int32_t wr_on(int64_t handle, const char* event, const char* payload_json);

void    wr_string_free(char* p);

#ifdef __cplusplus
}
#endif
