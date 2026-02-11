API_URL="https://api.github.com/repos/Acly/krita-ai-diffusion/releases/latest"

echo "Consultando GitHub..."
curl -sL -H "User-Agent: Linux" "$API_URL" | jq -r '.tag_name + " " + .assets[0].browser_download_url' > .download_info

read -r VERSION DOWNLOAD_URL <<< $(cat .download_info)

# 3. Mostrar la versión
echo "---------------------------------------"
echo "Versión encontrada: $VERSION"
echo "URL de descarga:    $DOWNLOAD_URL"
echo "---------------------------------------"

FILENAME=$(basename "$DOWNLOAD_URL")

mkdir -p {package,decompressed}
echo "Descargando $FILENAME..."
cd package
curl -L -# -O "$DOWNLOAD_URL"
cd ../decompressed
echo "Descomprimiendo..."
unzip -qo "../package/$FILENAME" 
cd ..
echo "¡Listo!"
