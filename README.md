# Are You Missing ROPs?

This script will check for missing ROPs so you can ensure you're getting the full GPU performance you paid for.

## Linux
```wget -O - https://raw.githubusercontent.com/MachoDrone/checkROPS/main/checkROPS.sh | bash```

## Windows
1. Use GPU-Z or HWinfo to see the ROP count and confirm it matches your GPU’s specs (e.g., look up your GPU on [TechPowerUp](https://www.techpowerup.com) or the manufacturer’s site).
2. Run a simple rendering test (e.g., [Unigine Heaven](https://benchmark.unigine.com/heaven)) to ensure the GPU’s graphics pipeline, including ROPs, is functioning.

- .

- ROPs are **not used** for AI inference or the AI image generation process. The GPU’s compute units (CUDA cores, Tensor Cores, etc.) handle those tasks.

- ROPs are used for viewing the generated image on your screen, but this is a post-processing step unrelated to the AI computation.

- This tool is just to ensure you’re getting the ROPs you paid for, if that matters to you.

## About This Script
The script downloads approximately 7 GB of data for the `nvidia/cuda:12.4.1-devel-ubuntu22.04` container image and installs an additional 288 MB of packages inside the container to build and run the `nbody` benchmark. Once the benchmark completes, the container and its image are automatically deleted using `docker run --rm` and `docker rmi`, **leaving no permanent footprint on the host system beyond the initial disk usage.**
