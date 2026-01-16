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

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     DOS Games Website - Delete Game        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo

# List available games
echo -e "${CYAN}Available games:${NC}"
game_count=0
for dir in "$SCRIPT_DIR"/*/; do
    dirname=$(basename "$dir")
    if [[ "$dirname" != "nginx" && "$dirname" != .* && -f "$dir/Dockerfile" ]]; then
        echo "  - $dirname"
        ((game_count++)) || true
    fi
done

if [[ $game_count -eq 0 ]]; then
    echo -e "${YELLOW}No games installed.${NC}"
    exit 0
fi

echo
echo -e "${YELLOW}Enter the game name to delete:${NC}"
read -r game

# Validate input
if [[ -z "$game" ]]; then
    echo -e "${RED}Error: Game name cannot be empty${NC}"
    exit 1
fi

# Check if game exists
if [[ ! -d "$SCRIPT_DIR/$game" ]]; then
    echo -e "${RED}Error: Game '$game' does not exist${NC}"
    exit 1
fi

# Prevent deleting nginx
if [[ "$game" == "nginx" ]]; then
    echo -e "${RED}Error: Cannot delete nginx folder${NC}"
    exit 1
fi

# Confirm deletion
echo
echo -e "${YELLOW}Are you sure you want to delete '$game'? (y/n)${NC}"
read -r confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${RED}Aborted.${NC}"
    exit 1
fi

# Delete the game folder
echo
echo -e "${CYAN}Deleting game folder...${NC}"
rm -rf "$SCRIPT_DIR/$game"

# Run sync to update all config files
echo -e "${CYAN}Syncing config files...${NC}"
"$SCRIPT_DIR/sync_games.sh"

echo
echo -e "${GREEN}Game '$game' has been deleted successfully!${NC}"
