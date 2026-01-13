#!/bin/bash
# Helper script for authentication that automatically exits after login

CREDENTIALS_FILE="/hytale/credentials/.hytale-downloader-credentials.json"
DOWNLOADER="/hytale/downloader/hytale-downloader-linux-amd64"

echo "========================================="
echo "Hytale Authentication Helper"
echo "========================================="
echo ""

# Run downloader with a timeout that watches for credentials file
timeout 300 bash -c "
    ${DOWNLOADER} -credentials-path ${CREDENTIALS_FILE} &
    PID=\$!
    
    echo 'Waiting for OAuth login to complete...'
    echo 'Follow the link above to authenticate.'
    echo ''
    
    # Wait for credentials file to be created and populated
    while [ ! -s '${CREDENTIALS_FILE}' ]; do
        sleep 1
        # Check if downloader is still running
        if ! kill -0 \$PID 2>/dev/null; then
            echo 'Downloader exited unexpectedly'
            exit 1
        fi
    done
    
    # Credentials found! Kill the downloader before it downloads
    echo ''
    echo '========================================='
    echo 'Authentication successful!'
    echo 'Stopping downloader (container will handle downloads)...'
    echo '========================================='
    kill \$PID 2>/dev/null
    wait \$PID 2>/dev/null
    exit 0
"

RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "Success! The container will now download game files and start the server."
    echo "Check logs with: docker compose logs -f hytale"
    exit 0
elif [ $RESULT -eq 124 ]; then
    echo ""
    echo "Timeout: Authentication took too long (5 minutes)"
    exit 1
else
    echo ""
    echo "Authentication failed or was interrupted"
    exit 1
fi