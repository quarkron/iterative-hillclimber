#!/usr/bin/env bash
# Build libcuptitrace.so against the CUPTI of the CUDA toolkit the traced application uses (run inside its container).
#   CUDA_HOME=/usr/local/cuda ./build.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUDA_HOME=${CUDA_HOME:-/usr/local/cuda}
T=$CUDA_HOME/targets/x86_64-linux; [ -d "$T" ] || T=$CUDA_HOME
INC=$T/include; LIB=$T/lib; [ -d "$CUDA_HOME/extras/CUPTI/include" ] && { INC=$CUDA_HOME/extras/CUPTI/include; LIB=$CUDA_HOME/extras/CUPTI/lib64; }
gcc -shared -fPIC -O2 -Wall -I"$INC" "$HERE/cuptitrace.c" -L"$LIB" -lcupti -Wl,-rpath,"$LIB" -o "$HERE/libcuptitrace.so"
ls -la "$HERE/libcuptitrace.so"
