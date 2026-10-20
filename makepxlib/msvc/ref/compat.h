#ifndef COMPAT_H
#define COMPAT_H

#include <time.h>

// Mapeia localtime_r do POSIX para a função segura do Windows (localtime_s)
static inline struct tm *localtime_r(const time_t *timep, struct tm *result) {
    if (result == NULL || timep == NULL) return NULL;
    if (localtime_s(result, timep) == 0) {
        return result;
    }
    return NULL;
}

#endif