/* cuptitrace — minimal LD_PRELOAD CUPTI activity tracer (ERA loop tooling).
 *
 * Why this exists: an nsys whose bundled CUPTI predates the GPU architecture can record ZERO kernels (silently), and
 * a newer nsys can hang at launch on some systems. The CUDA toolkit's own libcupti supports the architecture it ships
 * with, so we ask it directly for the per-kernel activity records nsys would have produced: GPU-side start/end
 * timestamps per launch.
 *
 * Records CONCURRENT_KERNEL (+ MEMCPY/MEMSET as pseudo-kernels named "[memcpy]"/"[memset]") to a binary file:
 *   header  : magic "CUPT" u32, version u32
 *   records : struct { u64 start_ns, end_ns; u32 name_id, stream_id; }   (24 bytes each)
 *   footer  : after the records, the name table: u32 n, then n × (u32 len, bytes)  — written at exit.
 * The footer offset is patched into the header (u64 at byte 8) at exit so a reader can locate the table.
 *
 * Build (inside the container):  see build.sh.  Use:  LD_PRELOAD=libcuptitrace.so CUPTI_TRACE_OUT=file.bin cmd
 * Overhead: CPU-side ~1-2 us per launch for record handling; the GPU timestamps themselves are unaffected.
 */
#include <cupti.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <pthread.h>
#include <unistd.h>

#define BUF_SIZE (8 * 1024 * 1024)
#define MAX_NAMES 8192

typedef struct { uint64_t start, end; uint32_t name_id, stream_id; } rec_t;

static FILE *g_out = NULL;
static pthread_mutex_t g_mu = PTHREAD_MUTEX_INITIALIZER;
static char *g_names[MAX_NAMES];
static uint32_t g_nnames = 0;
static uint64_t g_nrecs = 0, g_dropped = 0;

static uint32_t name_id(const char *s) {
    if (!s) s = "[null]";
    for (uint32_t i = 0; i < g_nnames; i++) if (strcmp(g_names[i], s) == 0) return i;
    if (g_nnames >= MAX_NAMES) return MAX_NAMES - 1;
    g_names[g_nnames] = strdup(s);
    return g_nnames++;
}

static void CUPTIAPI buf_requested(uint8_t **buf, size_t *size, size_t *maxrec) {
    *buf = (uint8_t *)aligned_alloc(8, BUF_SIZE); *size = BUF_SIZE; *maxrec = 0;
}

static void CUPTIAPI buf_completed(CUcontext ctx, uint32_t sid, uint8_t *buf, size_t size, size_t valid) {
    (void)ctx; (void)sid;
    CUpti_Activity *r = NULL;
    pthread_mutex_lock(&g_mu);
    for (;;) {
        CUptiResult st = cuptiActivityGetNextRecord(buf, valid, &r);
        if (st != CUPTI_SUCCESS) break;
        rec_t o;
        switch (r->kind) {
        case CUPTI_ACTIVITY_KIND_CONCURRENT_KERNEL:
        case CUPTI_ACTIVITY_KIND_KERNEL: {
            CUpti_ActivityKernel9 *k = (CUpti_ActivityKernel9 *)r;
            o.start = k->start; o.end = k->end; o.name_id = name_id(k->name); o.stream_id = k->streamId; break; }
        case CUPTI_ACTIVITY_KIND_MEMCPY: {
            CUpti_ActivityMemcpy5 *m = (CUpti_ActivityMemcpy5 *)r;
            o.start = m->start; o.end = m->end; o.name_id = name_id("[memcpy]"); o.stream_id = m->streamId; break; }
        case CUPTI_ACTIVITY_KIND_MEMSET: {
            CUpti_ActivityMemset4 *m = (CUpti_ActivityMemset4 *)r;
            o.start = m->start; o.end = m->end; o.name_id = name_id("[memset]"); o.stream_id = m->streamId; break; }
        default: continue;
        }
        if (g_out) { fwrite(&o, sizeof o, 1, g_out); g_nrecs++; }
    }
    size_t dropped = 0;
    cuptiActivityGetNumDroppedRecords(ctx, sid, &dropped);
    g_dropped += dropped;
    pthread_mutex_unlock(&g_mu);
    free(buf);
}

static void finish(void) {
    cuptiActivityFlushAll(1);
    pthread_mutex_lock(&g_mu);
    if (g_out) {
        long off = ftell(g_out);
        fwrite(&g_nnames, 4, 1, g_out);
        for (uint32_t i = 0; i < g_nnames; i++) {
            uint32_t len = (uint32_t)strlen(g_names[i]);
            fwrite(&len, 4, 1, g_out); fwrite(g_names[i], 1, len, g_out);
        }
        uint64_t off64 = (uint64_t)off;
        fseek(g_out, 8, SEEK_SET); fwrite(&off64, 8, 1, g_out);
        fclose(g_out); g_out = NULL;
        fprintf(stderr, "[cuptitrace] %llu records, %u distinct names, %llu DROPPED\n",
                (unsigned long long)g_nrecs, g_nnames, (unsigned long long)g_dropped);
    }
    pthread_mutex_unlock(&g_mu);
}

__attribute__((constructor)) static void init(void) {
    const char *path = getenv("CUPTI_TRACE_OUT");
    if (!path) { fprintf(stderr, "[cuptitrace] CUPTI_TRACE_OUT unset — tracing disabled\n"); return; }
    /* Only the FIRST process to arm traces. Children inherit LD_PRELOAD (+ this marker) and would otherwise
     * fopen(path,"wb") — truncating the parent's file and clobbering its first record with their footer. */
    char pidbuf[32]; snprintf(pidbuf, sizeof pidbuf, "%d", (int)getpid());
    const char *armed = getenv("CUPTI_TRACE_ARMED_PID");
    if (armed && strcmp(armed, pidbuf) != 0) return;
    setenv("CUPTI_TRACE_ARMED_PID", pidbuf, 1);
    g_out = fopen(path, "wb");
    if (!g_out) { fprintf(stderr, "[cuptitrace] cannot open %s\n", path); return; }
    uint32_t magic = 0x54505543u /* "CUPT" */, ver = 1; uint64_t off = 0;
    fwrite(&magic, 4, 1, g_out); fwrite(&ver, 4, 1, g_out); fwrite(&off, 8, 1, g_out);
    CUptiResult st = cuptiActivityRegisterCallbacks(buf_requested, buf_completed);
    if (st != CUPTI_SUCCESS) { const char *e; cuptiGetResultString(st, &e); fprintf(stderr, "[cuptitrace] register: %s\n", e); }
    cuptiActivityEnable(CUPTI_ACTIVITY_KIND_CONCURRENT_KERNEL);
    if (getenv("CUPTI_TRACE_MEM")) { cuptiActivityEnable(CUPTI_ACTIVITY_KIND_MEMCPY); cuptiActivityEnable(CUPTI_ACTIVITY_KIND_MEMSET); }
    atexit(finish);
    fprintf(stderr, "[cuptitrace] armed -> %s\n", path);
}
