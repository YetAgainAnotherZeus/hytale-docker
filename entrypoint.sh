#!/bin/bash
set -e

DOWNLOADER="${HYTALE_HOME}/downloader/hytale-downloader-linux-amd64"
GAME_DIR="${HYTALE_HOME}/game"
SERVER_DIR="${HYTALE_HOME}/server"
CREDENTIALS_FILE="${HYTALE_HOME}/credentials/.hytale-downloader-credentials.json"

# Check if credentials file exists and is valid (not empty)
if [ ! -f "${CREDENTIALS_FILE}" ] || [ ! -s "${CREDENTIALS_FILE}" ]; then
    # Remove empty/invalid credentials file if it exists
    [ -f "${CREDENTIALS_FILE}" ] && rm "${CREDENTIALS_FILE}"
    echo "========================================"
    echo "No credentials found!"
    echo "========================================"
    echo "Please run the following to authenticate:"
    echo "  docker compose exec hytale /hytale/downloader/hytale-downloader-linux-amd64 -credentials-path ${CREDENTIALS_FILE}"
    echo ""
    echo "IMPORTANT: After completing OAuth login, press Ctrl+C to exit the downloader!"
    echo "The container will automatically detect the credentials and download game files."
    echo "Do NOT let the downloader download files - the container handles this."
    echo "========================================"
    echo ""
    echo "Waiting for credentials... (container will stay running)"
    echo "Press Ctrl+C to stop the container."
    
    # Keep container running so user can exec into it
    while [ ! -f "${CREDENTIALS_FILE}" ]; do
        sleep 10
        echo "Still waiting for credentials at ${CREDENTIALS_FILE}..."
    done
    
    echo "Credentials found! Starting server..."
fi

# Download/update game files if needed
echo "Checking for Hytale updates..."
cd "${HYTALE_HOME}/downloader"

# Get version info
VERSION=$("${DOWNLOADER}" -print-version -patchline="${PATCHLINE:-release}" -credentials-path="${CREDENTIALS_FILE}" 2>/dev/null || echo "unknown")
echo "Target version: ${VERSION}"

# Download if game directory doesn't exist or is empty
if [ ! -d "${GAME_DIR}" ] || [ -z "$(ls -A ${GAME_DIR})" ]; then
    echo "Downloading Hytale ${VERSION}..."
    DOWNLOAD_ZIP="/tmp/hytale-${VERSION}.zip"
    
    "${DOWNLOADER}" \
        -credentials-path="${CREDENTIALS_FILE}" \
        -download-path="${DOWNLOAD_ZIP}" \
        -patchline="${PATCHLINE:-release}"
    
    echo "Extracting game files..."
    mkdir -p "${GAME_DIR}"
    aunpack "${DOWNLOAD_ZIP}" -X "${GAME_DIR}"
    rm "${DOWNLOAD_ZIP}"
    
    echo "Game files downloaded to ${GAME_DIR}"
fi

# Find the versioned directory (e.g., 2026.01.13-dcad8778f) or use game root
GAME_VERSION_DIR=$(find "${GAME_DIR}" -maxdepth 1 -type d -name "20*" | head -n 1)

if [ -z "${GAME_VERSION_DIR}" ]; then
    echo "No versioned subdirectory found, checking if files are in root..."
    # Check if Server directory exists directly in GAME_DIR
    if [ -d "${GAME_DIR}/Server" ] && [ -f "${GAME_DIR}/Server/HytaleServer.jar" ]; then
        GAME_VERSION_DIR="${GAME_DIR}"
        echo "Using game files from: ${GAME_VERSION_DIR}"
    else
        echo "Error: Could not find game files in ${GAME_DIR}"
        exit 1
    fi
else
    echo "Using game files from: ${GAME_VERSION_DIR}"
fi

# Setup server directory
mkdir -p "${SERVER_DIR}"
cd "${SERVER_DIR}"

# Build Java command
JAVA_CMD="java -Xms${JAVA_MIN_MEMORY} -Xmx${JAVA_MAX_MEMORY} -jar ${GAME_VERSION_DIR}/Server/HytaleServer.jar"

# Add required assets parameter
JAVA_CMD="${JAVA_CMD} --assets ${GAME_VERSION_DIR}/Assets.zip"

# Add optional parameters from environment variables
[ -n "${SERVER_BIND}" ] && JAVA_CMD="${JAVA_CMD} --bind ${SERVER_BIND}"
[ -n "${AUTH_MODE}" ] && JAVA_CMD="${JAVA_CMD} --auth-mode ${AUTH_MODE}"
[ -n "${OWNER_NAME}" ] && JAVA_CMD="${JAVA_CMD} --owner-name ${OWNER_NAME}"
[ -n "${OWNER_UUID}" ] && JAVA_CMD="${JAVA_CMD} --owner-uuid ${OWNER_UUID}"
[ -n "${BACKUP_DIR}" ] && JAVA_CMD="${JAVA_CMD} --backup-dir ${BACKUP_DIR}"
[ -n "${BOOT_COMMANDS}" ] && {
    IFS=',' read -ra COMMANDS <<< "${BOOT_COMMANDS}"
    for cmd in "${COMMANDS[@]}"; do
        JAVA_CMD="${JAVA_CMD} --boot-command \"${cmd}\""
    done
}

# Enable backups by default if backup directory is mounted
if [ -d "/hytale/backups" ]; then
    JAVA_CMD="${JAVA_CMD} --backup --backup-dir /hytale/backups"
fi

echo "========================================"
echo "Starting Hytale Server"
echo "========================================"
echo "Command: ${JAVA_CMD}"
echo "========================================"

# Start the server
exec ${JAVA_CMD}