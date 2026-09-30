#!/usr/bin/env bash
set -euo pipefail

# Directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FORCE_BUILD=false
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
    FORCE_BUILD=true
fi

echo "=========================================="
echo "    YouTube Morphe Auto-Builder (Local)   "
echo "=========================================="

# 1. Check dependencies (docker)
if ! command -v docker &>/dev/null; then
    echo "[-] Erreur : Docker n'est pas installé ou accessible." >&2
    exit 1
fi

# 2. Check keystore
KEYSTORE_FILE="$SCRIPT_DIR/morphe.keystore"
if [[ ! -f "$KEYSTORE_FILE" ]]; then
    echo "[*] Génération d'un keystore de signature persistant..."
    docker run --rm -v "$SCRIPT_DIR:/app" -w /app eclipse-temurin:21-jre-alpine \
        keytool -genkeypair -v -keystore /app/morphe.keystore \
        -alias morphe -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass morphepass -keypass morphepass \
        -dname "CN=Morphe, OU=Morphe, O=Morphe, L=Unknown, ST=Unknown, C=US"
    docker run --rm -v "$SCRIPT_DIR:/app" alpine chown -R "$(id -u):$(id -g)" /app/morphe.keystore
fi

# 3. Get latest Morphe Desktop CLI release
echo "[*] Vérification de la dernière version de Morphe Desktop..."
DESKTOP_RELEASE_JSON=$(curl -sL https://api.github.com/repos/MorpheApp/morphe-desktop/releases/latest)
DESKTOP_JAR_URL=$(echo "$DESKTOP_RELEASE_JSON" | jq -r '.assets[] | select(.name | test("morphe-desktop-.*-all\\.jar$")) | .browser_download_url' | head -n 1)
DESKTOP_JAR_NAME=$(basename "$DESKTOP_JAR_URL")

if [[ ! -f "$SCRIPT_DIR/$DESKTOP_JAR_NAME" ]]; then
    echo "[*] Téléchargement de $DESKTOP_JAR_NAME..."
    rm -f "$SCRIPT_DIR"/morphe-desktop-*-all.jar
    curl -sL "$DESKTOP_JAR_URL" -o "$SCRIPT_DIR/$DESKTOP_JAR_NAME"
fi

# 4. Get latest Morphe Patches release
echo "[*] Vérification de la dernière version de Morphe Patches..."
PATCHES_RELEASE_JSON=$(curl -sL https://api.github.com/repos/MorpheApp/morphe-patches/releases/latest)
PATCHES_MPP_URL=$(echo "$PATCHES_RELEASE_JSON" | jq -r '.assets[] | select(.name | test("patches-.*\\.mpp$")) | .browser_download_url' | head -n 1)
PATCHES_MPP_NAME=$(basename "$PATCHES_MPP_URL")

if [[ ! -f "$SCRIPT_DIR/$PATCHES_MPP_NAME" ]]; then
    echo "[*] Téléchargement de $PATCHES_MPP_NAME..."
    rm -f "$SCRIPT_DIR"/patches-*.mpp
    curl -sL "$PATCHES_MPP_URL" -o "$SCRIPT_DIR/$PATCHES_MPP_NAME"
fi

# 5. Determine recommended YouTube version for these patches
echo "[*] Détection de la version YouTube compatible..."
COMPAT_OUTPUT=$(docker run --rm -v "$SCRIPT_DIR:/app" -w /app eclipse-temurin:21-jre-alpine \
    java -jar "$DESKTOP_JAR_NAME" list-versions --patches="$PATCHES_MPP_NAME" -f=com.google.android.youtube 2>/dev/null || true)

RECOMMENDED_VER=$(echo "$COMPAT_OUTPUT" | grep -E '^[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | awk '{print $1}')

if [[ -z "$RECOMMENDED_VER" ]]; then
    echo "[-] Avertissement : Impossible d'extraire la version depuis list-versions, fallback sur 21.16.256"
    RECOMMENDED_VER="21.16.256"
fi

echo "[+] Version YouTube recommandée : $RECOMMENDED_VER"

# 6. Check if already built
CURRENT_VER=""
if [[ -f "$SCRIPT_DIR/version.txt" ]]; then
    CURRENT_VER=$(cat "$SCRIPT_DIR/version.txt")
fi

if [[ "$CURRENT_VER" == "$RECOMMENDED_VER" && -f "$SCRIPT_DIR/youtube-morphe.apk" && "$FORCE_BUILD" == false ]]; then
    echo "[+] L'APK youtube-morphe.apk est déjà à jour (version $RECOMMENDED_VER)."
    echo "    Utilise './build_local.sh --force' pour forcer la recompilation."
    exit 0
fi

# 7. Compile in-app update check extension
echo "[*] Compilation de l'extension de vérification in-app..."
docker run --rm -v "$SCRIPT_DIR:/app" -w /app eclipse-temurin:21-jdk-alpine sh -c "apk add --no-cache python3 >/dev/null && python3 build_patch.py"

# 8. Download official YouTube APK
STOCK_APK="$SCRIPT_DIR/youtube-stock.apk"
echo "[*] Téléchargement de l'APK officiel YouTube $RECOMMENDED_VER..."
STOCK_URL="https://archive.org/download/jhc-apks/apks/com.google.android.youtube/com.google.android.youtube-${RECOMMENDED_VER}-all.apk"

HTTP_CODE=$(curl -sL -w "%{http_code}" "$STOCK_URL" -o "$STOCK_APK")
if [[ "$HTTP_CODE" != "200" || ! -s "$STOCK_APK" ]]; then
    echo "[-] Erreur : Échec du téléchargement depuis Archive.org (code $HTTP_CODE)." >&2
    rm -f "$STOCK_APK"
    exit 1
fi

echo "[+] APK officiel téléchargé avec succès ($(du -h "$STOCK_APK" | cut -f1))."

# 9. Patch with Morphe & In-App Updater
echo "[*] Application des patches Morphe et de l'in-app updater..."
docker run --rm --memory=3g -v "$SCRIPT_DIR:/app" -w /app eclipse-temurin:21-jre-alpine \
    java -Xmx2g -jar "$DESKTOP_JAR_NAME" patch \
    -p "$PATCHES_MPP_NAME" \
    -p update-check.mpp \
    -e "j-hc Update Check" \
    --keystore=morphe.keystore \
    --keystore-password=morphepass \
    --keystore-entry-alias=morphe \
    --keystore-entry-password=morphepass \
    -o youtube-morphe.apk \
    youtube-stock.apk

# Fix permissions
docker run --rm -v "$SCRIPT_DIR:/app" alpine chown -R "$(id -u):$(id -g)" /app/youtube-morphe.apk

# Clean up
rm -f "$STOCK_APK"
rm -rf "$SCRIPT_DIR/morphe-data/tmp" 2>/dev/null || true

# Update version file
echo "$RECOMMENDED_VER" > "$SCRIPT_DIR/version.txt"

echo "=========================================="
echo "[+] SUCCÈS ! APK avec In-App Update généré avec succès :"
echo "    -> $SCRIPT_DIR/youtube-morphe.apk ($(du -h "$SCRIPT_DIR/youtube-morphe.apk" | cut -f1))"
echo "    -> Version : $RECOMMENDED_VER"
echo "=========================================="
