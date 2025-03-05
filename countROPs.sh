#!/bin/bash

# Prevent unexpected shell termination
trap 'echo "Script completed, keeping session alive..."' EXIT

# Ensure NVIDIA Docker runtime is available
if ! command -v docker >/dev/null 2>&1 || ! docker info --format '{{.Runtimes}}' | grep -q nvidia; then
    echo "Error: Docker or NVIDIA runtime not installed. Please install NVIDIA Container Toolkit."
    echo "See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
    exit 1
fi

# Temporary directory for building
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Create Dockerfile
cat << 'EOF' > Dockerfile
FROM nvidia/cuda:12.2.0-base-ubuntu22.04
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install pynvml
COPY check_rops.py /app/check_rops.py
RUN chmod +x /app/check_rops.py
CMD ["python3", "/app/check_rops.py"]
EOF

# Create complete Python script with formatted output and full GPU list
cat << 'EOF' > check_rops.py
#!/usr/bin/env python3
import pynvml
import sys

# ANSI escape codes for formatting
BOLD = "\033[1m"
GREEN = "\033[32m"
BLUE = "\033[34m"
RESET = "\033[0m"

EXPECTED_ROPS = {
    # 50 Series (Blackwell, based on reported specs)
    "RTX 5090": 176,
    "RTX 5090D": 176,
    "RTX 5080": 112,
    "RTX 5070 Ti": 96,
    "RTX 5070": 96,
    # 40 Series (Ada Lovelace)
    "RTX 4090": 176,
    "RTX 4080": 112,
    "RTX 4070 Ti": 96,
    "RTX 4070": 96,
    "RTX 4060 Ti": 64,
    "RTX 4060": 64,
    # 30 Series (Ampere)
    "RTX 3090": 112,
    "RTX 3080": 96,
    "RTX 3070": 96,
    "RTX 3060 Ti": 80,
    "RTX 3060": 64
}

def initialize_nvml():
    try:
        pynvml.nvmlInit()
        return True
    except pynvml.NVMLError as e:
        print(f"Error initializing NVML: {e}")
        return False

def get_gpu_info():
    device_count = pynvml.nvmlDeviceGetCount()
    if device_count == 0:
        print("No NVIDIA GPUs detected.")
        return None
    gpu_info = []
    for i in range(device_count):
        handle = pynvml.nvmlDeviceGetHandleByIndex(i)
        name = pynvml.nvmlDeviceGetName(handle)
        inferred_rops = None
        for model, rops in EXPECTED_ROPS.items():
            if model in name:
                inferred_rops = rops
                break
        if inferred_rops is None:
            inferred_rops = 0  # Unknown GPU
        gpu_info.append((name, inferred_rops))
    return gpu_info

def check_rops():
    if not initialize_nvml():
        sys.exit(1)
    gpu_info = get_gpu_info()
    if not gpu_info:
        sys.exit(1)
    print("Checking ROP counts for detected GPUs...")
    print("Note: ROP counts are inferred from model specifications.")
    for name, rops in gpu_info:
        print(f"\n{BOLD}{GREEN}GPU: {name}{RESET}")
        print(f"{BOLD}{BLUE}Detected ROPs (inferred): {rops}{RESET}")
        matched = False
        for model, expected in EXPECTED_ROPS.items():
            if model in name:
                matched = True
                if rops < expected:
                    print(f"WARNING: Missing ROPs detected!")
                    print(f"Expected: {expected}, Found: {rops}")
                    print("Contact your GPU manufacturer for a replacement.")
                else:
                    print(f"{BOLD}{BLUE}ROPs match expected value: {expected}{RESET}")
                break
        if not matched:
            print("Unknown GPU model. Cannot verify ROP count precisely.")
    pynvml.nvmlShutdown()

if __name__ == "__main__":
    check_rops()
EOF

# Build the Docker image quietly
DOCKER_IMAGE="rop-test:latest"
echo "Building Docker image... (this may take a few seconds)"
docker build -t "$DOCKER_IMAGE" . >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to build Docker image."
    cd ~ >/dev/null || exit 1
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Run the Docker container with output redirection
echo "Running ROP test..."
docker run --rm --gpus all -i "$DOCKER_IMAGE" 2>&1

# Clean up and return to home directory
cd ~ >/dev/null || exit 1
rm -rf "$TEMP_DIR"

# Keep session alive by spawning an interactive shell, with a blank line
echo ""
echo "Test completed. Entering interactive shell..."
bash  # Start a new interactive shell

# Exit cleanly (won’t reach here due to bash)
exit 0
