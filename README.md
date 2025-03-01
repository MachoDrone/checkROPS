# Are you missing ROPs?

This script will check for missing ROPS so you can make sure you are getting the whole GPU that you paid for.

**__Linux__:**
```wget -O - https://raw.githubusercontent.com/MachoDrone/checkROPS/main/checkROPS.sh | bash```
**__Windows__:**
-# Use GPU-Z or HWinfo to see the ROP count and confirm it matches your GPU’s specs (e.g., look up your GPU on TechPowerUp or the manufacturer’s site).
-# Run a simple rendering test (e.g., Unigine Heaven) to ensure the GPU’s graphics pipeline, including ROPs, works.

ROPs is NOT used for AI Inference or AI Image Generation process. The GPU’s compute units (CUDA, Tensor Cores, etc.) do the work.

ROPs is for viewing generated image to your screen, but this is a post-processing step unrelated to the AI computation.

Again, this is just to make sure you get ROPs that you paid for, if you care.


**__About this script__:**
The script downloads approximately 7 GB of data for the nvidia/cuda:12.4.1-devel-ubuntu22.04 container image and installs an additional 288 MB of packages inside the container to build and run the nbody benchmark. Once the benchmark completes, the container and its image are automatically deleted using docker run --rm and docker rmi, **leaving no permanent footprint on the host system beyond the initial disk usage.**
