# DOS Games Arcade

A retro-themed web portal for playing classic DOS games and Heroes of Might and Magic III directly in your browser.
A live version of this deployment is available at https://yaron.today

## Features

- **DOS Games**: Play classic DOS games via js-dos emulator
- **Heroes of Might and Magic III**: Full Windows game running via Wine/VNC
- **Random Game Button**: Instantly launch a random DOS game
- **Retro UI**: Beautiful CRT/arcade aesthetic with neon colors

## Requirements

- Docker and Docker Compose
- Node.js 16+ (for adding DOS games)

## Quick Start

After cloning, you need to add games (game files are not included in the repo):

```bash
# Add your first game
./create_game.sh
# Enter a game name like: doom, princeofpersia, lionking

# Build and run
docker compose up --build
```

Open http://localhost to access the arcade.

## Adding DOS Games

```bash
# Add a new game
./create_game.sh
# Enter a game name like: doom, princeofpersia, lionking

# Rebuild
docker compose up --build
```

Popular games that work: doom, doomii, princeofpersia, lionking, aladdin, duke3d, wolfenstein, quake, lemmings, pacman, and many more.

## Removing Games

```bash
# Remove a game
./delete_game.sh
# Select the game to remove

# Rebuild
docker compose up --build
```

## Syncing Configuration

If you manually add/remove game folders, run:

```bash
./sync_games.sh
```

This regenerates `docker-compose.yml`, `nginx/nginx.conf`, and `nginx/index.html`.

## Project Structure

```
.
├── docker-compose.yml     # Generated - all services
├── create_game.sh         # Add new DOS games
├── delete_game.sh         # Remove games
├── sync_games.sh          # Regenerate configs
├── nginx/                 # Web server
│   ├── index.html         # Game portal (generated)
│   ├── player.html        # DOS game player
│   └── player-homm3.html  # HoMM3 player (noVNC)
├── homm3/                 # HoMM3 (Wine/VNC)
│   └── HoMM3/             # Game files go here
└── [game folders]/        # Created by create_game.sh
```

## Heroes of Might and Magic III

HoMM3 runs via Wine in a container with VNC streaming. To set it up:

1. Place your HoMM3 game files in `homm3/HoMM3/`
2. Run `docker compose up --build`
3. Wait 10-20 seconds for Wine to initialize
4. Click the game in the portal to play

**Note**: HoMM3 requires a desktop browser (mouse/keyboard). Mobile devices will see a "Desktop Only" message.

**Audio**: Click the "Sound: OFF" button to enable audio streaming. For best audio quality, use HTTPS.

## Deployment

For production deployment with HTTPS:

```bash
# Change Docker to use internal port
# In docker-compose.yml, change nginx ports to "8080:80"

# Install and run Caddy for automatic HTTPS
sudo snap install caddy
sudo caddy reverse-proxy --from yourdomain.com --to localhost:8080
```

## Customization

Edit `nginx/index.html` to customize colors, fonts, and layout. Changes will be overwritten when running `sync_games.sh` - either modify the script or make changes after syncing.

## License

MIT
