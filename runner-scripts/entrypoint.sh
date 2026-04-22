#!/bin/bash -x

set -e
PLUGIN_FORCE_TAG=v1.49.1
if [ -n "$PLUGIN_FORCE_TAG" ]; then
    echo Providing plugin version $PLUGIN_FORCE_TAG
fi
#echo '***'
#echo 'DOWNLOAD MODELS: cd ai_diffusion && python3 download_models.py -m ../ComfyUI'
#echo '***'
echo "########################################"
echo "[INFO] Starting ComfyUI..."
echo "########################################"

# Let .pyc files be stored in one place
export PYTHONPYCACHEPREFIX="/root/.cache/pycache"
# Let PIP install packages to /root/.local
export PIP_USER=true
# Add above to PATH
export PATH="${PATH}:/root/.local/bin"
# Suppress [WARNING: Running pip as the 'root' user]
export PIP_ROOT_USER_ACTION=ignore

mkdir -p ai_diffusion && cd /root/ai_diffusion
if [ ! -f "/root/ai_diffusion/.download_info" ]; then
    bash /runner-scripts/get_latest_plugin.sh $PLUGIN_FORCE_TAG
fi
read -r VERSION DOWNLOAD_URL <<< $(cat .download_info)
FILENAME=$(basename "$DOWNLOAD_URL")
python -m http.server -d ./package 8080 &

TARGET_DIR="/opt/ComfyUI/models"
CONTAINER_SOURCE="/opt/ComfyUI/.models/"
HOST_SOURCE="/models/"

TMPFS_DIR="/root/.overlay"
WORK_DIR="$TMPFS_DIR/work"
UPPER_DIR="$TMPFS_DIR/changes"

if [ -w "/models" ] ; then
    # Escritura en el HOST de los modelos
    cd /root/ai_diffusion/decompressed/ai_diffusion
    # Se descargará del host segun entorno AI_DIFFUSION_DOWNLOAD_URL
    # download_models.py utiliza <path>/models por defecto
    python download_models.py -m / --flux2 --checkpoints
fi
# contenido original para que sea ro
if [ ! -d "$CONTAINER_SOURCE" ]; then
    mv "$TARGET_DIR" "$CONTAINER_SOURCE"
    mkdir -p "$TARGET_DIR" "$WORK_DIR" "$UPPER_DIR"
fi

# lowerdir: Capas de RO (Host + Original del Contenedor)
# upperdir: Cambios COW
# workdir: Interno
fuse-overlayfs -o lowerdir="$HOST_SOURCE":"$CONTAINER_SOURCE",upperdir="$UPPER_DIR",workdir="$WORK_DIR" "$TARGET_DIR"

python /runner-scripts/test_ov.py

nice -n 19 ionice -c 3 python3 /opt/ComfyUI/main.py --listen --port 8188 ${CLI_ARGS}
tail -f

