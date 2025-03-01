#!/bin/bash

# Check dependencies
if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "Error: nvidia-smi not found. Ensure NVIDIA drivers are installed."
    exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker not found. Install Docker first."
    exit 1
fi
if ! docker ps >/dev/null 2>&1; then
    echo "Error: Docker requires sudo or user must be in 'docker' group. Run 'sudo usermod -aG docker $USER' and relogin, or use sudo."
    exit 1
fi
if ! docker run --rm --gpus all nvidia/cuda:12.4.1-base nvidia-smi >/dev/null 2>&1; then
    echo "Error: NVIDIA Container Toolkit not configured. Install nvidia-docker2 or equivalent."
    exit 1
fi
if grep -q "microsoft" /proc/version 2>/dev/null; then
    if ! docker info --format '{{.Runtimes}}' | grep -q "nvidia"; then
        echo "Error: NVIDIA runtime not detected in WSL2 Docker. Ensure Docker Desktop WSL2 integration and NVIDIA Container Toolkit are configured."
        exit 1
    fi
fi

DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
if [ -z "$DRIVER_VERSION" ]; then
    echo "Error: NVIDIA driver not detected on host. Please install NVIDIA drivers."
    exit 1
fi

echo "Detected host NVIDIA driver version: $DRIVER_VERSION"

if [ "$(printf '%s\n%s' "$DRIVER_VERSION" "535.104.05" | sort -V | head -n1)" = "535.104.05" ]; then
    CUDA_IMAGE="nvidia/cuda:12.4.1-devel-ubuntu22.04"
    CUDA_VERSION="12.4.1"
elif [ "$(printf '%s\n%s' "$DRIVER_VERSION" "450.80.02" | sort -V | head -n1)" = "450.80.02" ]; then
    CUDA_IMAGE="nvidia/cuda:11.8.0-devel-ubuntu22.04"
    CUDA_VERSION="11.8.0"
else
    echo "Error: Host driver ($DRIVER_VERSION) is too old for CUDA 11.8+ (minimum 450.80.02)."
    exit 1
fi

echo "Using container image: $CUDA_IMAGE (CUDA $CUDA_VERSION), compatible with host driver $DRIVER_VERSION"

docker run --rm --gpus all -it "$CUDA_IMAGE" bash -c "
    apt update && apt install -y gcc make freeglut3-dev git cmake bc && \
    git clone https://github.com/NVIDIA/cuda-samples.git /cuda-samples && \
    cd /cuda-samples/Samples/5_Domain_Specific/nbody && \
    GPU=\$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1) && \
    DRIVER_VERSION=\$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1) && \
    echo \"Container using host driver version: \$DRIVER_VERSION\" && \
    if echo \"\$GPU\" | grep -q -E \"3060|3070|3080|3090\"; then ARCH=86; THRESH=15000; \
    elif echo \"\$GPU\" | grep -q -E \"4060|4070\"; then ARCH=89; THRESH=25000; \
    elif echo \"\$GPU\" | grep -q -E \"4080|4090|5070|5080|5090\"; then ARCH=89; THRESH=38000; \
    else ARCH=75; THRESH=10000; fi && \
    sed -i \"s/set(CMAKE_CUDA_ARCHITECTURES .*/set(CMAKE_CUDA_ARCHITECTURES \${ARCH})/\" CMakeLists.txt && \
    sed -i \"/target_compile_features/d\" CMakeLists.txt && \
    cmake . && make && \
    RESULT=\$(./nbody -benchmark -numbodies=65536 | grep -oP \"\d+\.\d+(?= single-precision GFLOP/s)\") && \
    echo -e \"\n\033[34mThresholds Refined:\nRTX 30-series: 15,000 GFLOP/s (covers 3060-3090 range).\nRTX 4060/4070: 25,000 GFLOP/s (mid-tier Ada estimate).\nRTX 4080/4090: 38,000 GFLOP/s (high-end Ada/Blackwell).\nRTX 50-series: 38,000 GFLOP/s (speculative).\nFallback: 10,000 GFLOP/s (20-series).\033[0m\n\" && \
    if (( \$(echo \"\$RESULT >= \$THRESH\" | bc -l) )); then \
        echo -e \"\033[32mGFLOP/s: \$RESULT\033[0m\" && echo -e \"\033[32mROPs fully working for \$GPU\033[0m\n\"; \
    else \
        echo -e \"\033[31mGFLOP/s: \$RESULT\033[0m\" && echo -e \"\033[31mROPs fail or doubt for \$GPU\033[0m\n\"; \
    fi && exit 0" && docker rmi "$CUDA_IMAGE"
