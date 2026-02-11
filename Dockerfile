################################################################################
# Dockerfile that builds ComfyUI & Openvino'
# Running on XPU (Intel GPU) and OpenVINO.
# Using PyTorch built by Intel.
################################################################################
FROM ubuntu:24.04 AS base

USER root
WORKDIR /

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tzdata ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Get Openvino from URL
ARG package_url=https://storage.openvinotoolkit.org/repositories/openvino_genai/packages/2025.4/linux/openvino_genai_ubuntu24_2025.4.0.0_x86_64.tar.gz
ARG TEMP_DIR=/tmp/openvino_installer

WORKDIR ${TEMP_DIR}
ADD ${package_url} ${TEMP_DIR}

# install product by copying archive content
ARG TEMP_DIR=/tmp/openvino_installer
ENV INTEL_OPENVINO_DIR=/opt/intel/openvino

# Creating user openvino and adding it to groups"users"
RUN useradd -ms /bin/bash -G users openvino

RUN find "${TEMP_DIR}" \( -name "*.tgz" -o -name "*.tar.gz" \) -exec tar -xzf {} \; && \
    OV_BUILD="$(find . -maxdepth 1 -type d -name "*openvino*" | grep -oP '(?<=_)\d+.\d+.\d.\d+')" && \
    OV_YEAR="$(echo "$OV_BUILD" | grep -oP '^[^\d]*(\d+)')" && \
    OV_FOLDER="$(find . -maxdepth 1 -type d -name "*openvino*")" && \
    mkdir -p /opt/intel/openvino_"$OV_BUILD"/ && \
    cp -rf "$OV_FOLDER"/*  /opt/intel/openvino_"$OV_BUILD"/ && \
    rm -rf "${TEMP_DIR:?}"/"$OV_FOLDER" && \
    ln --symbolic /opt/intel/openvino_"$OV_BUILD"/ /opt/intel/openvino && \
    ln --symbolic /opt/intel/openvino_"$OV_BUILD"/ /opt/intel/openvino_"$OV_YEAR" && \
    rm -rf "${TEMP_DIR}" && \
    chown -R openvino /opt/intel/openvino_"$OV_BUILD"


ENV InferenceEngine_DIR=/opt/intel/openvino/runtime/cmake
ENV LD_LIBRARY_PATH=/opt/intel/openvino/runtime/3rdparty/hddl/lib:/opt/intel/openvino/runtime/3rdparty/tbb/lib:/opt/intel/openvino/runtime/lib/intel64:/opt/intel/openvino/tools/compile_tool:/opt/intel/openvino/extras/opencv/lib
ENV OpenCV_DIR=/opt/intel/openvino/extras/opencv/cmake
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV PYTHONPATH=/opt/intel/openvino/python:/opt/intel/openvino/python/python3:/opt/intel/openvino/extras/opencv/python
ENV TBB_DIR=/opt/intel/openvino/runtime/3rdparty/tbb/cmake
ENV ngraph_DIR=/opt/intel/openvino/runtime/cmake
ENV OpenVINO_DIR=/opt/intel/openvino/runtime/cmake
ENV INTEL_OPENVINO_DIR=/opt/intel/openvino
ENV OV_TOKENIZER_PREBUILD_EXTENSION_PATH=/opt/intel/openvino/runtime/lib/intel64/libopenvino_tokenizers.so
ENV PKG_CONFIG_PATH=/opt/intel/openvino/runtime/lib/intel64/pkgconfig

RUN rm -rf ${INTEL_OPENVINO_DIR}/.distribution && mkdir ${INTEL_OPENVINO_DIR}/.distribution && \
    touch ${INTEL_OPENVINO_DIR}/.distribution/docker
# -----------------



FROM base AS opencv-deps

LABEL description="This is the dev image for OpenCV building with OpenVINO Runtime backend"
LABEL vendor="Intel Corporation"

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

RUN apt-get update; \
    apt-get install -y --no-install-recommends \
        git \
        python3-dev \
        python3-pip \
        python3-venv \
        build-essential \
        cmake \
        ninja-build \
        libgtk-3-dev \
        libpng-dev \
        libjpeg-dev \
        libwebp-dev \
        libtiff5-dev \
        libopenexr-dev \
        libopenblas-dev \
        libx11-dev \
        libavutil-dev \
        libavcodec-dev \
        libavformat-dev \
        libswscale-dev \
        libswresample-dev \
        # libtbb2 \
        libssl-dev \
        libva-dev \
        libmfx-dev \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev \
        libavif-dev && \
    rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH=$VIRTUAL_ENV/bin:$PATH

RUN python3 -m pip install --no-cache-dir --upgrade pip
RUN python3 -m pip install --no-cache-dir numpy==2.2.6

CMD ["/bin/bash"]

# -----------------

FROM opencv-deps AS opencv

LABEL description="This is the dev image for OpenCV building with OpenVINO Runtime backend"
LABEL vendor="Intel Corporation"

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ARG OPENCV_BRANCH=4.13.0
WORKDIR /opt/repo
RUN git clone https://github.com/opencv/opencv.git
WORKDIR /opt/repo/opencv
RUN git checkout ${OPENCV_BRANCH}
WORKDIR /opt/repo/opencv/build

RUN . "${INTEL_OPENVINO_DIR}"/setupvars.sh; \
    cmake -G Ninja \
    -D BUILD_INFO_SKIP_EXTRA_MODULES=ON \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_JASPER=OFF \
    -D BUILD_JAVA=OFF \
    -D BUILD_JPEG=ON \
    -D BUILD_APPS_LIST=version \
    -D BUILD_opencv_apps=ON \
    -D BUILD_opencv_java=OFF \
    -D BUILD_OPENEXR=OFF \
    -D BUILD_PNG=ON \
    -D BUILD_TBB=OFF \
    -D BUILD_WEBP=OFF \
    -D BUILD_ZLIB=ON \
    -D BUILD_TESTS=ON \
    -D WITH_1394=OFF \
    -D WITH_CUDA=OFF \
    -D WITH_EIGEN=OFF \
    -D WITH_GPHOTO2=OFF \
    -D WITH_GSTREAMER=ON \
    -D OPENCV_GAPI_GSTREAMER=OFF \
    -D WITH_GTK_2_X=OFF \
    -D WITH_IPP=ON \
    -D WITH_JASPER=OFF \
    -D WITH_LAPACK=OFF \
    -D WITH_MATLAB=OFF \
    -D WITH_MFX=ON \
    -D WITH_OPENCLAMDBLAS=OFF \
    -D WITH_OPENCLAMDFFT=OFF \
    -D WITH_OPENEXR=OFF \
    -D WITH_OPENJPEG=OFF \
    -D WITH_QUIRC=OFF \
    -D WITH_TBB=OFF \
    -D WITH_TIFF=OFF \
    -D WITH_VTK=OFF \
    -D WITH_WEBP=OFF \
    -D CMAKE_USE_RELATIVE_PATHS=ON \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D ENABLE_BUILD_HARDENING=ON \
    -D ENABLE_CONFIG_VERIFICATION=ON \
    -D ENABLE_PRECOMPILED_HEADERS=OFF \
    -D ENABLE_CXX11=ON \
    -D INSTALL_PDB=ON \
    -D INSTALL_TESTS=ON \
    -D INSTALL_C_EXAMPLES=OFF \
    -D INSTALL_PYTHON_EXAMPLES=OFF \
    -D CMAKE_INSTALL_PREFIX=install \
    -D OPENCV_SKIP_PKGCONFIG_GENERATION=ON \
    -D OPENCV_SKIP_PYTHON_LOADER=OFF \
    -D OPENCV_SKIP_CMAKE_ROOT_CONFIG=ON \
    -D OPENCV_GENERATE_SETUPVARS=OFF \
    -D OPENCV_BIN_INSTALL_PATH=bin \
    -D OPENCV_INCLUDE_INSTALL_PATH=include \
    -D OPENCV_LIB_INSTALL_PATH=lib \
    -D OPENCV_CONFIG_INSTALL_PATH=cmake \
    -D OPENCV_3P_LIB_INSTALL_PATH=3rdparty \
    -D OPENCV_DOC_INSTALL_PATH=doc \
    -D OPENCV_OTHER_INSTALL_PATH=etc \
    -D OPENCV_LICENSES_INSTALL_PATH=etc/licenses \
    -D OPENCV_INSTALL_FFMPEG_DOWNLOAD_SCRIPT=ON \
    -D BUILD_opencv_world=OFF \
    -D BUILD_opencv_python2=OFF \
    -D BUILD_opencv_python3=ON \
    -D BUILD_opencv_dnn=OFF \
    -D BUILD_opencv_gapi=OFF \
    -D PYTHON3_PACKAGES_PATH=install/python/python3 \
    -D PYTHON3_LIMITED_API=ON \
    -D HIGHGUI_PLUGIN_LIST=all \
    -D OPENCV_PYTHON_INSTALL_PATH=python \
    -D CPU_BASELINE=SSE4_2 \
    -D OPENCV_IPP_GAUSSIAN_BLUR=ON \
    -D WITH_OPENVINO=ON \
    -D OPENCV_DNN_OPENVINO=ON \
    -D OPENCV_TEST_DNN_OPENVINO=ON \
    -D WITH_INF_ENGINE=ON \
    -D InferenceEngine_DIR="${INTEL_OPENVINO_DIR}"/runtime/cmake/ \
    -D ngraph_DIR="${INTEL_OPENVINO_DIR}"/runtime/cmake/ \
    -D INF_ENGINE_RELEASE=2022010000 \
    -D VIDEOIO_PLUGIN_LIST=ffmpeg,gstreamer,mfx \
    -D CMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
    -D CMAKE_BUILD_TYPE=Release /opt/repo/opencv && \
    ninja -j "$(nproc)" && cmake --install . && \
    rm -Rf install/bin install/etc/samples

WORKDIR /opt/repo/opencv/build/install
CMD ["/bin/bash"]
# -------------------------------------------------------------------------------------------------


FROM ubuntu:24.04 AS ov_base

LABEL description="This is the dev image for Intel(R) Distribution of OpenVINO(TM) toolkit on Ubuntu 22.04 LTS"
LABEL vendor="Intel Corporation"

USER root
WORKDIR /

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Creating user openvino and adding it to groups "video", "render" and "users" to use GPU and VPU
RUN sed -ri -e 's@^UMASK[[:space:]]+[[:digit:]]+@UMASK 000@g' /etc/login.defs && \
	grep -E "^UMASK" /etc/login.defs && groupadd render && useradd -ms /bin/bash -G video,users,render openvino && \
    chown openvino -R /home/openvino

RUN mkdir /opt/intel

ENV INTEL_OPENVINO_DIR /opt/intel/openvino

COPY --from=base /opt/intel/ /opt/intel/

WORKDIR /thirdparty

ARG INSTALL_SOURCES="no"

ARG DEPS="tzdata \
          curl"

ARG LGPL_DEPS="g++ \
               gcc \
               libc6-dev"
ARG INSTALL_PACKAGES="-c=python -c=core -c=dev"

RUN apt-get update && apt-get upgrade -y && \
    dpkg --get-selections | grep -v deinstall | awk '{print $1}' > base_packages.txt  && \
    apt-get install -y --no-install-recommends ${DEPS} && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get reinstall -y ca-certificates && rm -rf /var/lib/apt/lists/* && update-ca-certificates

RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-venv ${LGPL_DEPS} && \
    ${INTEL_OPENVINO_DIR}/install_dependencies/install_openvino_dependencies.sh -y ${INSTALL_PACKAGES} && \
    if [ "$INSTALL_SOURCES" = "yes" ]; then \
      sed -Ei 's/# deb-src /deb-src /' /etc/apt/sources.list && \
      apt-get update && \
	  dpkg --get-selections | grep -v deinstall | awk '{print $1}' > all_packages.txt && \
	  grep -v -f base_packages.txt all_packages.txt | while read line; do \
	  package=$(echo $line); \
	  name=(${package//:/ }); \
      grep -l GPL /usr/share/doc/${name[0]}/copyright; \
      exit_status=$?; \
	  if [ $exit_status -eq 0 ]; then \
	    apt-get source -q --download-only $package;  \
	  fi \
      done && \
      echo "Download source for $(ls | wc -l) third-party packages: $(du -sh)"; fi && \
    rm /usr/lib/python3.*/lib-dynload/readline.cpython-3*-gnu.so && rm -rf /var/lib/apt/lists/*

RUN curl -L -O  https://github.com/uxlfoundation/oneTBB/releases/download/v2022.3.0/oneapi-tbb-2022.3.0-lin.tgz && \
    tar -xzf  oneapi-tbb-2022.3.0-lin.tgz && \
    cp oneapi-tbb-2022.3.0/lib/intel64/gcc4.8/libtbb.so* /opt/intel/openvino/runtime/lib/intel64/ && \
    rm -Rf oneapi-tbb-2022.3.0*

WORKDIR ${INTEL_OPENVINO_DIR}/licensing
RUN if [ "$INSTALL_SOURCES" = "no" ]; then \
        echo "This image doesn't contain source for 3d party components under LGPL/GPL licenses. They are stored in https://storage.openvinotoolkit.org/repositories/openvino/ci_dependencies/container_gpl_sources/." > DockerImage_readme.txt ; \
    fi


ENV InferenceEngine_DIR=/opt/intel/openvino/runtime/cmake
ENV LD_LIBRARY_PATH=/opt/intel/openvino/runtime/3rdparty/hddl/lib:/opt/intel/openvino/runtime/3rdparty/tbb/lib:/opt/intel/openvino/runtime/lib/intel64:/opt/intel/openvino/tools/compile_tool:/opt/intel/openvino/extras/opencv/lib
ENV OpenCV_DIR=/opt/intel/openvino/extras/opencv/cmake
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV PYTHONPATH=/opt/intel/openvino/python:/opt/intel/openvino/python/python3:/opt/intel/openvino/extras/opencv/python
ENV TBB_DIR=/opt/intel/openvino/runtime/3rdparty/tbb/cmake
ENV ngraph_DIR=/opt/intel/openvino/runtime/cmake
ENV OpenVINO_DIR=/opt/intel/openvino/runtime/cmake
ENV INTEL_OPENVINO_DIR=/opt/intel/openvino
ENV OV_TOKENIZER_PREBUILD_EXTENSION_PATH=/opt/intel/openvino/runtime/lib/intel64/libopenvino_tokenizers.so
ENV PKG_CONFIG_PATH=/opt/intel/openvino/runtime/lib/intel64/pkgconfig

# setup python

ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH=$VIRTUAL_ENV/bin:$PATH

RUN python3 -m pip install  --no-cache-dir --upgrade pip

# dev package
WORKDIR ${INTEL_OPENVINO_DIR}
ARG OPENVINO_WHEELS_VERSION=2025.4.0
ARG OPENVINO_WHEELS_URL
RUN apt-get update && apt-get install -y --no-install-recommends cmake make git && rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install --no-cache-dir openvino=="${OPENVINO_WHEELS_VERSION}" && \
    python3 -m pip install --no-cache-dir openvino-tokenizers=="${OPENVINO_WHEELS_VERSION}" && \
    python3 -m pip install --no-cache-dir openvino-genai=="${OPENVINO_WHEELS_VERSION}"

WORKDIR ${INTEL_OPENVINO_DIR}/licensing

COPY --from=opencv /opt/repo/opencv/build/install ${INTEL_OPENVINO_DIR}/extras/opencv
RUN  echo "export OpenCV_DIR=${INTEL_OPENVINO_DIR}/extras/opencv/cmake" | tee -a "${INTEL_OPENVINO_DIR}/extras/opencv/setupvars.sh"; \
     echo "export LD_LIBRARY_PATH=${INTEL_OPENVINO_DIR}/extras/opencv/lib:\$LD_LIBRARY_PATH" | tee -a "${INTEL_OPENVINO_DIR}/extras/opencv/setupvars.sh"

# Install dependencies for OV::RemoteTensor
RUN apt-get update && apt-get install -y --no-install-recommends opencl-headers ocl-icd-opencl-dev libavif-dev && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

# build samples into ${INTEL_OPENVINO_DIR}/samples/cpp/samples_bin
WORKDIR ${INTEL_OPENVINO_DIR}/samples/cpp
RUN ./build_samples.sh -b /tmp/build -i ${INTEL_OPENVINO_DIR}/samples/cpp/samples_bin && \
    rm -Rf /tmp/build

# add Model API package
#RUN git clone https://github.com/openvinotoolkit/open_model_zoo && \
#    sed -i '/opencv-python/d' open_model_zoo/demos/common/python/requirements.txt && \
#    pip3 --no-cache-dir install open_model_zoo/demos/common/python/ && \
#    rm -Rf open_model_zoo && \
#    python3 -c "from model_zoo import model_api"

# Intel® NPU drivers (optional)
RUN apt-get update && \
    apt-get install -y --no-install-recommends libtbb12 && \
    apt-get clean
RUN mkdir /tmp/npu_deps && cd /tmp/npu_deps && \
    curl -L -O https://github.com/intel/linux-npu-driver/releases/download/v1.28.0/linux-npu-driver-v1.28.0.20251218-20347000698-ubuntu2404.tar.gz && \
    tar xvfz linux-npu-driver-v1.28.0.20251218-20347000698-ubuntu2404.tar.gz && \
    dpkg -i ./*.deb && cd .. && rm -Rf /tmp/npu_deps 

# for GPU
RUN apt-get update && \
    apt-get install -y --no-install-recommends ocl-icd-libopencl1 && \
    apt-get clean ; \
    rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
RUN mkdir /tmp/gpu_deps && cd /tmp/gpu_deps && \
    curl -L -O https://github.com/oneapi-src/level-zero/releases/download/v1.26.3/level-zero_1.26.3+u24.04_amd64.deb && \

    curl -L -O https://github.com/intel/intel-graphics-compiler/releases/download/v2.27.10/intel-igc-core-2_2.27.10+20617_amd64.deb && \
    curl -L -O https://github.com/oneapi-src/level-zero/releases/download/v1.26.3/level-zero-devel_1.26.3+u24.04_amd64.deb && \
    curl -L -O https://github.com/intel/intel-graphics-compiler/releases/download/v2.27.10/intel-igc-opencl-2_2.27.10+20617_amd64.deb && \
    curl -L -O https://github.com/intel/compute-runtime/releases/download/26.01.36711.4/intel-ocloc-dbgsym_26.01.36711.4-0_amd64.ddeb && \
    curl -L -O https://github.com/intel/compute-runtime/releases/download/26.01.36711.4/intel-ocloc_26.01.36711.4-0_amd64.deb && \
    curl -L -O https://github.com/intel/compute-runtime/releases/download/26.01.36711.4/intel-opencl-icd-dbgsym_26.01.36711.4-0_amd64.ddeb && \
    curl -L -O https://github.com/intel/compute-runtime/releases/download/26.01.36711.4/intel-opencl-icd_26.01.36711.4-0_amd64.deb && \
    curl -L -O https://github.com/intel/compute-runtime/releases/download/26.01.36711.4/libigdgmm12_22.9.0_amd64.deb && \
    curl -L -O https://github.com/intel/compute-runtime/releases/download/26.01.36711.4/libze-intel-gpu1-dbgsym_26.01.36711.4-0_amd64.ddeb && \
    curl -L -O https://github.com/intel/compute-runtime/releases/download/26.01.36711.4/libze-intel-gpu1_26.01.36711.4-0_amd64.deb && \
    dpkg -i ./*.deb && rm -Rf /tmp/gpu_deps


# Post-installation cleanup and setting up OpenVINO environment variables
ENV LIBVA_DRIVER_NAME=iHD
ENV GST_VAAPI_ALL_DRIVERS=1
ENV LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri

RUN apt-get update && \
    apt-get autoremove -y gfortran && \
    rm -rf /var/lib/apt/lists/*

USER openvino
WORKDIR ${INTEL_OPENVINO_DIR}
ENV DEBIAN_FRONTEND=noninteractive

CMD ["/bin/bash"]

# -------------------------------------------------------------------------------------------------

# Setup custom layers below
FROM ov_base AS comfyui

USER root
RUN set -eu

# See http://bugs.python.org/issue19846

RUN if [ -f /etc/apt/apt.conf.d/proxy.conf ]; then rm /etc/apt/apt.conf.d/proxy.conf; fi && \
    if [ ! -z ${HTTP_PROXY} ]; then echo "Acquire::http::Proxy \"${HTTP_PROXY}\";" >> /etc/apt/apt.conf.d/proxy.conf; fi && \
    if [ ! -z ${HTTPS_PROXY} ]; then echo "Acquire::https::Proxy \"${HTTPS_PROXY}\";" >> /etc/apt/apt.conf.d/proxy.conf; fi
RUN apt-get update -y && \
    apt-get full-upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    google-perftools \
    openssh-server \
    net-tools \
    libcairo2-dev
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    if [ -f /etc/apt/apt.conf.d/proxy.conf ]; then rm /etc/apt/apt.conf.d/proxy.conf; fi
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 100

WORKDIR /opt

ARG IPEX_VERSION=2.7.0
ARG TORCHCCL_VERSION=2.7.0
ARG PYTORCH_VERSION=2.7.0
ARG TORCHAUDIO_VERSION=2.7.0
ARG TORCHVISION_VERSION=0.22.0
RUN python -m venv venv && \
    . ./venv/bin/activate && \
    python -m pip --no-cache-dir install --upgrade \
    pip \
    setuptools \
    psutil && \
    python -m pip install --no-cache-dir \
    torch==${PYTORCH_VERSION}+cpu torchvision==${TORCHVISION_VERSION}+cpu torchaudio==${TORCHAUDIO_VERSION}+cpu --index-url https://download.pytorch.org/whl/cpu && \
    python -m pip install --no-cache-dir \
    intel_extension_for_pytorch==${IPEX_VERSION} oneccl_bind_pt==${TORCHCCL_VERSION} --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/cpu/us/ && \
    python -m pip install intel-openmp && \
    python -m pip cache purge


# Cache left by upstream
RUN rm -rf /opt/.cache/pip

# Python and tools
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
    && apt-get install -y \
fish \
fd-find \
vim \
less \
aria2 \
git \
ninja-build \
make \
cmake \
build-essential \
python3-pybind11 \
libgl1 \
#libgl-mesa0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Python Packages
ARG PIP_ROOT_USER_ACTION='ignore'

RUN --mount=type=cache,target=/opt/.cache/pip \
    pip list \
    && pip install \
        --upgrade pip wheel setuptools

# Deps for ComfyUI & custom nodes
COPY builder-scripts/.  /builder-scripts/

# Make sure using the right version of Intel packages
RUN --mount=type=cache,target=/opt/.cache/pip \
    pip install \
    intel-extension-for-pytorch==2.7.10+xpu \
    --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/

RUN --mount=type=cache,target=/opt/.cache/pip \
    pip install \
    oneccl_bind_pt==2.7.0+xpu \
    --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/

# Install the ComfyUI CLI
RUN --mount=type=cache,target=/opt/.cache/pip \
    pip install comfy-cli

RUN --mount=type=cache,target=/opt/.cache/pip \
    pip install -r https://raw.githubusercontent.com/Comfy-Org/ComfyUI/refs/heads/master/requirements.txt

RUN --mount=type=cache,target=/opt/.cache/pip \
    pip install torch==2.7.0 torchaudio==2.7.0 torchsde==0.2.6 torchvision==0.22.0

RUN --mount=type=cache,target=/opt/.cache/pip \
    pip install matplotlib scikit-image orjson pillow_heif toml

COPY builder-scripts/packages-freeze.txt /opt/packages-freeze.txt
RUN --mount=type=cache,target=/opt/.cache/pip \
    pip install --force-reinstall -r /opt/packages-freeze.txt \
    --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
    && apt-get install -y \
    unzip \
    jq \
    fuse-overlayfs \
    tree \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


RUN git clone https://github.com/comfy-org/ComfyUI /opt/ComfyUI
RUN pip install -r /opt/ComfyUI/requirements.txt
RUN pip install -r /opt/ComfyUI/manager_requirements.txt
RUN cd /opt/ComfyUI/custom_nodes && git clone https://github.com/ltdrdata/ComfyUI-Manager comfyui-manager
RUN cd /opt/ComfyUI/custom_nodes && git clone https://github.com/Fannovel16/comfyui_controlnet_aux comfyui_controlnet_aux && cd comfyui_controlnet_aux && pip install -r requirements.txt
RUN cd /opt/ComfyUI/custom_nodes && git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus ComfyUI_IPAdapter_plus
RUN cd /opt/ComfyUI/custom_nodes && git clone https://github.com/Acly/comfyui-tooling-nodes comfyui-tooling-nodes
RUN cd /opt/ComfyUI/custom_nodes && git clone https://github.com/Acly/comfyui-inpaint-nodes comfyui-inpaint-nodes


#################################################################################
#

COPY runner-scripts/.  /runner-scripts/
COPY /runner-scripts/config.ini /opt/ComfyUI/user/__manager/config.ini

USER root
VOLUME /root
WORKDIR /root
EXPOSE 8188 8080
ENV CLI_ARGS="--cpu --use-pytorch-cross-attention"
CMD ["bash","/runner-scripts/entrypoint.sh"]
