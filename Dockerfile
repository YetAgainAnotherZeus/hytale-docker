FROM eclipse-temurin:25-jre-jammy

# Set environment variables
ENV HYTALE_HOME=/hytale \
    JAVA_MIN_MEMORY=4G \
    JAVA_MAX_MEMORY=8G \
    HYTALE_VERSION=latest

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    atool \
    unzip && \
    rm -rf /var/lib/apt/lists/*

# Create hytale user and directories
RUN useradd -m -U -d ${HYTALE_HOME} -s /bin/bash hytale && \
    mkdir -p ${HYTALE_HOME}/downloader && \
    chown -R hytale:hytale ${HYTALE_HOME}

# Set working directory
WORKDIR ${HYTALE_HOME}

# Switch to hytale user
USER hytale

# Download and setup hytale-downloader
RUN curl -o /tmp/hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip && \
    aunpack /tmp/hytale-downloader.zip -X ${HYTALE_HOME}/downloader && \
    chmod +x ${HYTALE_HOME}/downloader/hytale-downloader-linux-amd64 && \
    rm /tmp/hytale-downloader.zip

# Expose UDP port for Hytale server
EXPOSE 5520/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD pgrep -f HytaleServer.jar || exit 1

# Copy entrypoint and auth helper scripts
COPY --chown=hytale:hytale entrypoint.sh /hytale/entrypoint.sh
COPY --chown=hytale:hytale authenticate.sh /hytale/authenticate.sh
RUN chmod +x /hytale/entrypoint.sh /hytale/authenticate.sh

ENTRYPOINT ["/hytale/entrypoint.sh"]