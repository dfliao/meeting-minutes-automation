FROM debian:bullseye-slim

# Basic dependencies
RUN apt-get update && apt-get install -y --no-install-recommends     git cmake build-essential ffmpeg python3 python3-pip curl ca-certificates  && rm -rf /var/lib/apt/lists/*

# Python packages
RUN pip3 install --no-cache-dir fastapi "uvicorn[standard]" python-multipart

# Get whisper.cpp and build without AVX
WORKDIR /app
#RUN git clone https://github.com/ggerganov/whisper.cpp.git src &&     cd src && make clean && make -j4 WHISPER_NO_AVX=1
# 取得 whisper.cpp 並以 CMake 編譯（禁用 AVX/AVX2/FMA/F16C）
RUN git clone https://github.com/ggml-org/whisper.cpp.git src && \
    cmake -S src -B build \
      -DWHISPER_NO_AVX=ON \
      -DWHISPER_NO_AVX2=ON \
      -DWHISPER_NO_FMA=ON \
      -DWHISPER_NO_F16C=ON && \
    cmake --build build -j4 --config Release


# Prepare folders
RUN mkdir -p /models /data
VOLUME ["/models", "/data"]

# Copy API server
COPY server.py /app/server.py

EXPOSE 8000
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
