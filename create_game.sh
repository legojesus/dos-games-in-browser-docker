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

# Game metadata lookup (folder_name|display_name|description|icon)
declare -A GAME_METADATA=(
    ["doom"]="Doom|First-person shooter classic|💀"
    ["doomii"]="Doom II|Hell on Earth|💀"
    ["doom2"]="Doom II|Hell on Earth|💀"
    ["princeofpersia"]="Prince of Persia|Action platformer|🗡️"
    ["princeofpersia2"]="Prince of Persia 2|The Shadow and the Flame|🗡️"
    ["lionking"]="The Lion King|Disney platformer|🦁"
    ["aladdin"]="Aladdin|Disney platformer|🧞"
    ["dave"]="Dangerous Dave|Classic platformer|🏃"
    ["wolf3d"]="Wolfenstein 3D|First-person shooter|🔫"
    ["wolfenstein"]="Wolfenstein 3D|First-person shooter|🔫"
    ["quake"]="Quake|First-person shooter|🔫"
    ["heretic"]="Heretic|Fantasy shooter|🧙"
    ["hexen"]="Hexen|Dark fantasy action|⚔️"
    ["duke3d"]="Duke Nukem 3D|Action shooter|💣"
    ["dukenukemii"]="Duke Nukem II|Side-scrolling action|💣"
    ["keen"]="Commander Keen|Sci-fi platformer|🚀"
    ["keen4"]="Commander Keen 4|Sci-fi platformer|🚀"
    ["lemmings"]="Lemmings|Puzzle game|🐹"
    ["simcity"]="SimCity|City builder|🏙️"
    ["simcity2000"]="SimCity 2000|City builder|🏙️"
    ["civilization"]="Civilization|Strategy game|🏛️"
    ["civ"]="Civilization|Strategy game|🏛️"
    ["warcraft"]="Warcraft|Real-time strategy|⚔️"
    ["warcraft2"]="Warcraft II|Tides of Darkness|⚔️"
    ["diablo"]="Diablo|Action RPG|👹"
    ["xcom"]="X-COM|Tactical strategy|👽"
    ["transport"]="Transport Tycoon|Business simulation|🚂"
    ["carmageddon"]="Carmageddon|Vehicular combat|🏎️"
    ["needforspeed"]="Need for Speed|Racing game|🏎️"
    ["gta"]="Grand Theft Auto|Action adventure|🚗"
    ["monkey"]="Monkey Island|Point and click adventure|🐒"
    ["monkeyisland"]="Monkey Island|Point and click adventure|🐒"
    ["monkey2"]="Monkey Island 2|Point and click adventure|🐒"
    ["indiana"]="Indiana Jones|Adventure game|🤠"
    ["tomb"]="Tomb Raider|Action adventure|🏺"
    ["tombraider"]="Tomb Raider|Action adventure|🏺"
    ["tetris"]="Tetris|Puzzle classic|🧱"
    ["pacman"]="Pac-Man|Arcade classic|👻"
    ["spaceinvaders"]="Space Invaders|Arcade shooter|👾"
    ["asteroids"]="Asteroids|Arcade classic|☄️"
    ["frogger"]="Frogger|Arcade classic|🐸"
    ["digger"]="Digger|Arcade classic|💎"
    ["mario"]="Mario|Platformer classic|🍄"
    ["sonic"]="Sonic|Platformer classic|🦔"
    ["mortal"]="Mortal Kombat|Fighting game|🥋"
    ["mortalkombat"]="Mortal Kombat|Fighting game|🥋"
    ["mk"]="Mortal Kombat|Fighting game|🥋"
    ["mk2"]="Mortal Kombat II|Fighting game|🥋"
    ["streetfighter"]="Street Fighter|Fighting game|🥊"
    ["sf2"]="Street Fighter II|Fighting game|🥊"
    ["tekken"]="Tekken|Fighting game|🥋"
    ["fifa"]="FIFA|Soccer game|⚽"
    ["nba"]="NBA|Basketball game|🏀"
    ["nfl"]="NFL|Football game|🏈"
    ["golf"]="Golf|Sports game|⛳"
    ["chess"]="Chess|Strategy game|♟️"
    ["solitaire"]="Solitaire|Card game|🃏"
    ["minesweeper"]="Minesweeper|Puzzle game|💣"
    ["oregon"]="Oregon Trail|Educational adventure|🤠"
    ["carmen"]="Carmen Sandiego|Educational game|🔍"
    ["reader"]="Reader Rabbit|Educational game|🐰"
    ["math"]="Math Blaster|Educational game|🔢"
    ["raptor"]="Raptor|Shoot 'em up|✈️"
    ["tyrian"]="Tyrian|Shoot 'em up|🚀"
    ["jazz"]="Jazz Jackrabbit|Platformer|🐰"
    ["jill"]="Jill of the Jungle|Platformer|🌴"
    ["bio"]="Bio Menace|Action platformer|🔫"
    ["crystal"]="Crystal Caves|Platformer|💎"
    ["secret"]="Secret Agent|Platformer|🕵️"
    ["cosmo"]="Cosmo's Cosmic Adventure|Platformer|👽"
    ["monster"]="Monster Bash|Platformer|👻"
    ["halloween"]="Halloween Harry|Action game|🎃"
    ["one"]="One Must Fall 2097|Fighting game|🤖"
    ["rise"]="Rise of the Triad|First-person shooter|🔫"
    ["blood"]="Blood|First-person shooter|🩸"
    ["shadow"]="Shadow Warrior|First-person shooter|🗡️"
    ["redneck"]="Redneck Rampage|First-person shooter|🤠"
    ["wacky"]="Wacky Wheels|Racing game|🏎️"
    ["liero"]="Liero|Action game|🐛"
    ["worms"]="Worms|Strategy game|🐛"
    ["theme"]="Theme Park|Simulation|🎢"
    ["themepark"]="Theme Park|Simulation|🎢"
    ["themehospital"]="Theme Hospital|Simulation|🏥"
    ["settlers"]="The Settlers|Strategy game|🏰"
    ["caesar"]="Caesar|City builder|🏛️"
    ["pharaoh"]="Pharaoh|City builder|🏺"
    ["zeus"]="Zeus|City builder|⚡"
    ["age"]="Age of Empires|Strategy game|🏰"
    ["aoe"]="Age of Empires|Strategy game|🏰"
    ["starcraft"]="StarCraft|Real-time strategy|🚀"
    ["sc"]="StarCraft|Real-time strategy|🚀"
    ["c&c"]="Command & Conquer|Real-time strategy|🎖️"
    ["cnc"]="Command & Conquer|Real-time strategy|🎖️"
    ["redalert"]="Red Alert|Real-time strategy|☢️"
    ["dune"]="Dune|Strategy game|🏜️"
    ["dune2"]="Dune II|Real-time strategy|🏜️"
)

# Function to create game.json
create_game_json() {
    local game_dir="$1"
    local display_name="$2"
    local description="$3"
    local icon="$4"

    cat > "$game_dir/game.json" << EOF
{
    "displayName": "$display_name",
    "description": "$description",
    "icon": "$icon"
}
EOF
}

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     DOS Games Website - Add New Game       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo

# Get game name from user
echo -e "${YELLOW}Enter the game name (lowercase, no spaces):${NC}"
echo -e "Examples: doom, doomii, lionking, princeofpersia, dave"
read -r game

# Validate input
if [[ -z "$game" ]]; then
    echo -e "${RED}Error: Game name cannot be empty${NC}"
    exit 1
fi

if [[ "$game" =~ [^a-z0-9] ]]; then
    echo -e "${RED}Error: Game name should only contain lowercase letters and numbers${NC}"
    exit 1
fi

# Check if game already exists
if [[ -d "$SCRIPT_DIR/$game" ]]; then
    echo -e "${RED}Error: Game '$game' already exists!${NC}"
    exit 1
fi

echo
echo -e "${GREEN}Setting up '$game'...${NC}"
echo

# Run the create-dosbox tool
echo -e "${CYAN}Step 1: Running create-dosbox to download and configure the game...${NC}"
echo -e "${YELLOW}Note: When prompted, enter '$game' again to search, then select from the list.${NC}"
echo
cd "$SCRIPT_DIR"
npx create-dosbox@latest "$game"

# Check if game folder was created
if [[ ! -d "$SCRIPT_DIR/$game" ]]; then
    echo -e "${RED}Error: Game folder was not created. The game might not exist in the database.${NC}"
    exit 1
fi

# Install npm dependencies
echo
echo -e "${CYAN}Step 2: Installing npm dependencies...${NC}"
cd "$SCRIPT_DIR/$game"
npm install
npm audit fix --force 2>/dev/null || true

# Create Dockerfile for the game
echo
echo -e "${CYAN}Step 3: Creating Dockerfile...${NC}"
cat > Dockerfile << 'EOF'
FROM node:22-alpine

WORKDIR /app

# Copy package files first for better layer caching
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production 2>/dev/null || npm install --only=production

# Copy application files
COPY . .

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

EXPOSE 8080

CMD ["npm", "start"]
EOF

# Create game.json with metadata
echo
echo -e "${CYAN}Step 4: Setting up game metadata...${NC}"

if [[ -n "${GAME_METADATA[$game]}" ]]; then
    # Game found in lookup table
    display_name=$(echo "${GAME_METADATA[$game]}" | cut -d'|' -f1)
    description=$(echo "${GAME_METADATA[$game]}" | cut -d'|' -f2)
    icon=$(echo "${GAME_METADATA[$game]}" | cut -d'|' -f3)
    echo -e "${GREEN}Found metadata for '$game':${NC}"
    echo -e "  Display Name: $display_name"
    echo -e "  Description: $description"
    echo -e "  Icon: $icon"
else
    # Game not in lookup table - ask user
    echo -e "${YELLOW}Game '$game' not found in metadata table.${NC}"
    echo -e "Please provide the following information:"
    echo

    # Display name
    default_name=$(echo "$game" | sed 's/./\U&/')
    echo -e "${YELLOW}Display name${NC} (e.g., 'Prince of Persia') [default: $default_name]:"
    read -r display_name
    display_name="${display_name:-$default_name}"

    # Description
    echo -e "${YELLOW}Short description${NC} (e.g., 'Action platformer') [default: Classic DOS Game]:"
    read -r description
    description="${description:-Classic DOS Game}"

    # Icon
    echo -e "${YELLOW}Icon emoji${NC} (e.g., 🎮, 💀, 🗡️) [default: 🎮]:"
    read -r icon
    icon="${icon:-🎮}"
fi

create_game_json "$SCRIPT_DIR/$game" "$display_name" "$description" "$icon"
echo -e "${GREEN}Created game.json${NC}"

cd "$SCRIPT_DIR"

# Sync all config files
echo
echo -e "${CYAN}Step 5: Syncing config files...${NC}"
"$SCRIPT_DIR/sync_games.sh"

# Success message
echo
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Setup Complete!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo
echo -e "${CYAN}Game '$game' has been added successfully!${NC}"
echo
echo -e "To deploy the website, run:"
echo -e "  ${YELLOW}docker compose up --build${NC}"
echo
echo -e "To add another game, run this script again."
echo -e "To delete a game, run ${YELLOW}./delete_game.sh${NC}"
echo -e "To edit game metadata, modify ${YELLOW}$game/game.json${NC}"
