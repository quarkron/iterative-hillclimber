# Kernel timeline without nsys

`libcuptitrace.so` records every kernel's GPU start/end timestamps through the CUPTI activity API when preloaded into the
process (only the process you want traced: preloading into wrappers such as `taskset` can hang them):

    ./build.sh                                   # inside the application's container / toolkit
    LD_PRELOAD=/path/libcuptitrace.so CUPTI_TRACE_OUT=/tmp/trace.bin ./app ...
    python3 trace_summary.py /tmp/trace.bin 30   # per-kernel totals, counts, means; largest idle gaps between kernels

Format: header (u32 magic, u32 version, u64 footer offset), records {u64 start_ns, u64 end_ns, u32 name_id, u32 stream},
footer = name table. The idle gaps (GPU waiting for the host) are often the cheapest things to remove.
