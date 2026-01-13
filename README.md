# Hytale Server Docker Setup

This Docker setup allows you to run a Hytale server in a container with automatic game file downloading and updates.

## Setup Instructions

### 1. Create docker compose

An example can be found here [docker-compose.example.yml](https://github.com/YetAgainAnotherZeus/hytale-docker/blob/main/docker-compose.example.yml)

### 2. Start the container

```bash
docker-compose up -d
```

### 3. Authenticate cli

Follow the instructions to authenticate the cli to download the server files:

```bash
docker compose exec hytale /hytale/authenticate.sh
```

### 4. Authenticate server

Next, you'll need to authenticate your server:

```bash
# Install socat
sudo apt install socat

# Connect to your server console (replacing `hytale-server` by the name of your container)
socat EXEC:"docker attach hytale-server",pty STDIO

# When in the server console
/auth login device

# Optionnally, store your credentials on the server
/auth persistence Encrypted
```

### Updates

The server automatically checks for updates on startup. To force a re-download, delete the game files (ex: `/hytale/game-files`) and restart the container.
