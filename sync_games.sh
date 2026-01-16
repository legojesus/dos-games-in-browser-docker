#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read metadata from game.json file
# Falls back to defaults if file doesn't exist
get_display_name() {
    local game="$1"
    local game_json="$SCRIPT_DIR/$game/game.json"
    if [[ -f "$game_json" ]]; then
        grep -o '"displayName"[[:space:]]*:[[:space:]]*"[^"]*"' "$game_json" | cut -d'"' -f4
    else
        # Fallback: capitalize first letter
        echo "$game" | sed 's/./\U&/'
    fi
}

get_description() {
    local game="$1"
    local game_json="$SCRIPT_DIR/$game/game.json"
    if [[ -f "$game_json" ]]; then
        grep -o '"description"[[:space:]]*:[[:space:]]*"[^"]*"' "$game_json" | cut -d'"' -f4
    else
        echo "Classic DOS Game"
    fi
}

get_icon() {
    local game="$1"
    local game_json="$SCRIPT_DIR/$game/game.json"
    if [[ -f "$game_json" ]]; then
        grep -o '"icon"[[:space:]]*:[[:space:]]*"[^"]*"' "$game_json" | cut -d'"' -f4
    else
        echo "🎮"
    fi
}

get_game_type() {
    local game="$1"
    local game_json="$SCRIPT_DIR/$game/game.json"
    if [[ -f "$game_json" ]]; then
        local type=$(grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' "$game_json" | cut -d'"' -f4)
        echo "${type:-dos}"
    else
        echo "dos"
    fi
}

# Find all game directories (exclude nginx, hidden dirs, and files)
get_games() {
    local games=()
    for dir in "$SCRIPT_DIR"/*/; do
        dirname=$(basename "$dir")
        # Skip nginx and hidden directories
        if [[ "$dirname" != "nginx" && "$dirname" != .* ]]; then
            # Check if it has a Dockerfile (valid game folder)
            if [[ -f "$dir/Dockerfile" ]]; then
                games+=("$dirname")
            fi
        fi
    done
    echo "${games[@]}"
}

# Generate docker-compose.yml
generate_docker_compose() {
    local games=("$@")
    local compose_file="$SCRIPT_DIR/docker-compose.yml"

    cat > "$compose_file" << 'EOF'
name: dos-games-website

services:
EOF

    # Add each game service
    for game in "${games[@]}"; do
        local game_type="$(get_game_type "$game")"

        if [[ "$game_type" == "wine" ]]; then
            # Wine-based game (like HoMM3) - needs special config with persistent saves
            cat >> "$compose_file" << EOF
  $game:
    build:
      context: ./$game
      dockerfile: Dockerfile
    environment:
      - DISPLAY_SETTINGS=1024x768x16
    volumes:
      - ./$game/HoMM3/Games:/home/heroes/.wine/drive_c/Program Files (x86)/3DO/Heroes III Demo/Games
    restart: unless-stopped

EOF
        else
            # Standard DOS game
            cat >> "$compose_file" << EOF
  $game:
    build:
      context: ./$game
      dockerfile: Dockerfile
    restart: unless-stopped

EOF
        fi
    done

    # Add nginx service
    cat >> "$compose_file" << 'EOF'
  nginx:
    build:
      context: ./nginx
      dockerfile: Dockerfile
    ports:
      - "80:80"
    restart: unless-stopped
EOF

    # Add depends_on if there are games
    if [[ ${#games[@]} -gt 0 ]]; then
        echo "    depends_on:" >> "$compose_file"
        for game in "${games[@]}"; do
            echo "      - $game" >> "$compose_file"
        done
    fi

    echo "" >> "$compose_file"
}

# Generate nginx.conf
generate_nginx_conf() {
    local games=("$@")
    local nginx_conf="$SCRIPT_DIR/nginx/nginx.conf"

    cat > "$nginx_conf" << 'EOF'
worker_processes auto;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
EOF

    # Add upstream blocks for each game
    for game in "${games[@]}"; do
        local game_type="$(get_game_type "$game")"

        if [[ "$game_type" == "wine" ]]; then
            # Wine-based game needs upstreams for both VNC and audio
            cat >> "$nginx_conf" << EOF

    # Upstream for $game (VNC)
    upstream ${game}_vnc {
        server $game:8080;
    }

    # Upstream for $game (Audio)
    upstream ${game}_audio {
        server $game:8081;
    }
EOF
        else
            cat >> "$nginx_conf" << EOF

    # Upstream for $game
    upstream $game {
        server $game:8080;
    }
EOF
        fi
    done

    # Add the rest of the http block
    cat >> "$nginx_conf" << 'EOF'

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 256;
    gzip_types
        application/javascript
        application/json
        application/wasm
        application/xml
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Main server
    server {
        listen 80;
        server_name localhost;

        # Root location - serve index page
        location = / {
            root /etc/nginx/html/;
            index index.html;
        }

        # Player page for on-demand games
        location = /player.html {
            root /etc/nginx/html/;
        }

        # Player page for HoMM3 (Wine-based games)
        location = /player-homm3.html {
            root /etc/nginx/html/;
        }

EOF

    # Add location blocks for each game
    for game in "${games[@]}"; do
        local game_type="$(get_game_type "$game")"

        if [[ "$game_type" == "wine" ]]; then
            # Wine-based game needs WebSocket proxy for VNC and audio
            cat >> "$nginx_conf" << EOF

        # VNC WebSocket route for $game
        location /${game}-vnc/ {
            proxy_pass http://${game}_vnc/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_read_timeout 86400;
        }

        # Audio WebSocket route for $game
        location /${game}-audio/ {
            proxy_pass http://${game}_audio/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_read_timeout 86400;
        }
EOF
        else
            cat >> "$nginx_conf" << EOF

        # Route for $game
        location /$game {
            return 302 /$game/;
        }

        location /$game/ {
            proxy_pass http://$game/;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
EOF
        fi
    done

    # Close server and http blocks
    cat >> "$nginx_conf" << 'EOF'
    }
}
EOF
}

# Generate index.html
generate_index_html() {
    local games=("$@")
    local index_file="$SCRIPT_DIR/nginx/index.html"

    cat > "$index_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DOS Games Arcade</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Press+Start+2P&family=VT323&display=swap" rel="stylesheet">
    <style>
        :root {
            --neon-pink: #ff00ff;
            --neon-cyan: #00ffff;
            --neon-green: #39ff14;
            --dark-bg: #0a0a0a;
            --card-bg: #1a1a2e;
            --card-hover: #16213e;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'VT323', monospace;
            background: var(--dark-bg);
            min-height: 100vh;
            color: #fff;
            overflow-x: hidden;
        }

        /* Animated background */
        .bg-grid {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-image:
                linear-gradient(rgba(0, 255, 255, 0.03) 1px, transparent 1px),
                linear-gradient(90deg, rgba(0, 255, 255, 0.03) 1px, transparent 1px);
            background-size: 50px 50px;
            animation: gridMove 20s linear infinite;
            pointer-events: none;
            z-index: 0;
        }

        @keyframes gridMove {
            0% { transform: translate(0, 0); }
            100% { transform: translate(50px, 50px); }
        }

        /* Scanline effect */
        .scanlines {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: repeating-linear-gradient(
                0deg,
                rgba(0, 0, 0, 0.15),
                rgba(0, 0, 0, 0.15) 1px,
                transparent 1px,
                transparent 2px
            );
            pointer-events: none;
            z-index: 1000;
        }

        .container {
            position: relative;
            z-index: 1;
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }

        header {
            text-align: center;
            padding: 3rem 0;
        }

        h1 {
            font-family: 'Press Start 2P', cursive;
            font-size: clamp(1.5rem, 5vw, 3rem);
            background: linear-gradient(45deg, var(--neon-pink), var(--neon-cyan));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            text-shadow: 0 0 40px rgba(255, 0, 255, 0.5);
            animation: glow 2s ease-in-out infinite alternate;
            margin-bottom: 1rem;
        }

        @keyframes glow {
            from { filter: drop-shadow(0 0 20px var(--neon-pink)); }
            to { filter: drop-shadow(0 0 30px var(--neon-cyan)); }
        }

        .subtitle {
            font-size: 1.5rem;
            color: var(--neon-green);
            letter-spacing: 3px;
        }

        .random-btn {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            margin-top: 1.5rem;
            padding: 1rem 2rem;
            font-family: 'Press Start 2P', cursive;
            font-size: 0.9rem;
            background: linear-gradient(135deg, var(--neon-pink), var(--neon-cyan));
            border: none;
            border-radius: 8px;
            color: var(--dark-bg);
            cursor: pointer;
            transition: all 0.3s ease;
            text-transform: uppercase;
        }

        .random-btn:hover {
            transform: scale(1.05);
            box-shadow: 0 0 30px var(--neon-pink), 0 0 60px var(--neon-cyan);
        }

        .random-btn:active {
            transform: scale(0.98);
        }

        .random-icon {
            font-size: 1.2rem;
            animation: shake 2s ease-in-out infinite;
        }

        @keyframes shake {
            0%, 100% { transform: rotate(0deg); }
            25% { transform: rotate(-10deg); }
            75% { transform: rotate(10deg); }
        }

        /* Section Headers */
        .section-header {
            font-family: 'Press Start 2P', cursive;
            font-size: 0.9rem;
            color: var(--neon-pink);
            margin: 2rem 0 1rem;
            padding-bottom: 0.5rem;
            border-bottom: 2px solid var(--card-bg);
        }

        .games-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 2rem;
            padding: 1rem 0 2rem;
        }

        .game-card {
            background: var(--card-bg);
            border: 2px solid transparent;
            border-radius: 12px;
            padding: 2rem;
            text-decoration: none;
            color: #fff;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .game-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(
                90deg,
                transparent,
                rgba(255, 255, 255, 0.1),
                transparent
            );
            transition: left 0.5s ease;
        }

        .game-card:hover::before {
            left: 100%;
        }

        .game-card:hover {
            transform: translateY(-8px) scale(1.02);
            border-color: var(--neon-cyan);
            box-shadow:
                0 0 20px rgba(0, 255, 255, 0.3),
                0 20px 40px rgba(0, 0, 0, 0.4);
            background: var(--card-hover);
        }

        .game-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
            display: block;
        }

        .game-card h2 {
            font-family: 'Press Start 2P', cursive;
            font-size: 1rem;
            margin-bottom: 0.5rem;
            text-transform: uppercase;
            color: var(--neon-pink);
        }

        .game-card p {
            font-size: 1.2rem;
            color: #888;
        }

        .play-btn {
            display: inline-block;
            margin-top: 1rem;
            padding: 0.5rem 1rem;
            background: transparent;
            border: 2px solid var(--neon-green);
            color: var(--neon-green);
            font-family: 'Press Start 2P', cursive;
            font-size: 0.6rem;
            text-transform: uppercase;
            transition: all 0.3s ease;
        }

        .game-card:hover .play-btn {
            background: var(--neon-green);
            color: var(--dark-bg);
            box-shadow: 0 0 20px var(--neon-green);
        }

        /* Featured Game Card */
        .game-card.featured {
            grid-column: span 2;
            background: linear-gradient(135deg, #1a1a2e 0%, #2d1f3d 100%);
            border: 2px solid #ffd700;
            box-shadow: 0 0 20px rgba(255, 215, 0, 0.3);
            position: relative;
        }

        .game-card.featured::after {
            content: '★ FEATURED';
            position: absolute;
            top: 1rem;
            right: 1rem;
            background: linear-gradient(135deg, #ffd700, #ffaa00);
            color: #000;
            padding: 0.3rem 0.8rem;
            font-family: 'Press Start 2P', cursive;
            font-size: 0.5rem;
            border-radius: 4px;
            text-transform: uppercase;
        }

        .game-card.featured .desktop-badge {
            display: inline-block;
            margin-top: 0.5rem;
            padding: 0.2rem 0.5rem;
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid #888;
            border-radius: 4px;
            font-size: 0.9rem;
            color: #888;
        }

        .game-card.featured h2 {
            color: #ffd700;
            font-size: 1.2rem;
        }

        .game-card.featured .play-btn {
            border-color: #ffd700;
            color: #ffd700;
        }

        .game-card.featured:hover {
            border-color: #ffd700;
            box-shadow:
                0 0 30px rgba(255, 215, 0, 0.5),
                0 20px 40px rgba(0, 0, 0, 0.4);
        }

        .game-card.featured:hover .play-btn {
            background: #ffd700;
            color: var(--dark-bg);
            box-shadow: 0 0 20px #ffd700;
        }

        @media (max-width: 700px) {
            .game-card.featured {
                grid-column: span 1;
            }
        }

        .no-games {
            text-align: center;
            padding: 4rem;
            color: #666;
            font-size: 1.5rem;
        }

        .no-games code {
            display: block;
            margin-top: 1rem;
            padding: 1rem;
            background: var(--card-bg);
            border-radius: 8px;
            color: var(--neon-green);
            font-family: 'VT323', monospace;
        }

        footer {
            text-align: center;
            padding: 3rem 0;
            margin-top: 2rem;
            border-top: 1px solid #333;
        }

        footer p {
            font-size: 1.2rem;
            color: #666;
            margin-bottom: 0.5rem;
        }

        footer a {
            color: var(--neon-cyan);
            text-decoration: none;
            transition: color 0.3s ease;
        }

        footer a:hover {
            color: var(--neon-pink);
            text-shadow: 0 0 10px var(--neon-pink);
        }

        /* Mobile responsiveness */
        @media (max-width: 600px) {
            .container {
                padding: 1rem;
            }

            header {
                padding: 2rem 0;
            }

            .games-grid {
                grid-template-columns: 1fr;
                gap: 1rem;
            }

            .game-card {
                padding: 1.5rem;
            }
        }

        /* Keyboard navigation focus styles */
        .game-card:focus {
            outline: none;
            border-color: var(--neon-pink);
            box-shadow: 0 0 30px var(--neon-pink);
        }

        /* Loading animation for game icons */
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        .game-card:hover .game-icon {
            animation: pulse 1s ease-in-out infinite;
        }
    </style>
</head>
<body>
    <div class="bg-grid"></div>
    <div class="scanlines"></div>

    <div class="container">
        <header>
            <h1>DOS Games Arcade</h1>
            <p class="subtitle">[ SELECT YOUR GAME ]</p>
            <button class="random-btn" id="random-btn" onclick="playRandomGame()">
                <span class="random-icon">🎲</span> Random Game
            </button>
        </header>

        <main>
EOF

    # Add featured games section if there are games
    if [[ ${#games[@]} -gt 0 ]]; then
        cat >> "$index_file" << 'EOF'
            <h2 class="section-header">★ FEATURED GAMES</h2>
            <div class="games-grid" id="featured-games">
EOF
        # First pass: Add featured/wine games at the top
        for game in "${games[@]}"; do
            game_type="$(get_game_type "$game")"
            if [[ "$game_type" == "wine" ]]; then
                display_name="$(get_display_name "$game")"
                description="$(get_description "$game")"
                icon="$(get_icon "$game")"
                # Wine-based game links to special player (featured, desktop only)
                cat >> "$index_file" << EOF
                <a href="/player-homm3.html" class="game-card featured" tabindex="0" data-type="wine">
                    <span class="game-icon">$icon</span>
                    <h2>$display_name</h2>
                    <p>$description</p>
                    <span class="desktop-badge">🖥️ Desktop Only</span>
                    <span class="play-btn">► Play Now</span>
                </a>
EOF
            fi
        done

        # Second pass: Add standard DOS games
        for game in "${games[@]}"; do
            game_type="$(get_game_type "$game")"
            if [[ "$game_type" != "wine" ]]; then
                display_name="$(get_display_name "$game")"
                description="$(get_description "$game")"
                icon="$(get_icon "$game")"
                # Standard DOS game
                cat >> "$index_file" << EOF
                <a href="/$game" class="game-card" tabindex="0">
                    <span class="game-icon">$icon</span>
                    <h2>$display_name</h2>
                    <p>$description</p>
                    <span class="play-btn">► Play Now</span>
                </a>
EOF
            fi
        done
        cat >> "$index_file" << 'EOF'
            </div>
EOF
    fi

    # Close the HTML
    cat >> "$index_file" << 'EOF'
        </main>

        <footer>
            <p>Built with ❤️ by <a href="https://www.linkedin.com/in/yaronka/" target="_blank" rel="noopener">Yaron K.</a></p>
            <p>Source code on <a href="https://github.com/legojesus/dos-games-in-browser-docker" target="_blank" rel="noopener">GitHub</a></p>
            <p style="margin-top: 1rem; font-size: 1rem;">Powered by <a href="https://js-dos.com/" target="_blank" rel="noopener">js-dos</a></p>
        </footer>
    </div>

    <script>
        // Add keyboard navigation to game cards
        document.addEventListener('keydown', (e) => {
            if (e.target.classList.contains('game-card')) {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    e.target.click();
                }
            }
        });

        // Random Game function - picks a random DOS game from featured games
        function playRandomGame() {
            const gameCards = document.querySelectorAll('#featured-games .game-card:not([data-type="wine"])');
            if (gameCards.length === 0) {
                alert('No games available!');
                return;
            }
            const randomIndex = Math.floor(Math.random() * gameCards.length);
            const randomGame = gameCards[randomIndex];
            window.location.href = randomGame.href;
        }
    </script>
</body>
</html>
EOF
}

# Main execution
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       DOS Games Website - Sync Configs     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo

# Get list of games
games=($(get_games))

if [[ ${#games[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No games found. Config files will be generated with no games.${NC}"
else
    echo -e "${GREEN}Found ${#games[@]} game(s):${NC} ${games[*]}"
fi

echo
echo -e "${CYAN}Generating docker-compose.yml...${NC}"
generate_docker_compose "${games[@]}"

echo -e "${CYAN}Generating nginx/nginx.conf...${NC}"
generate_nginx_conf "${games[@]}"

echo -e "${CYAN}Generating nginx/index.html...${NC}"
generate_index_html "${games[@]}"

echo
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Sync Complete!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo
echo -e "Config files have been synchronized with existing game folders."
echo
if [[ ${#games[@]} -gt 0 ]]; then
    echo -e "To start the website, run:"
    echo -e "  ${YELLOW}docker compose up --build${NC}"
fi
