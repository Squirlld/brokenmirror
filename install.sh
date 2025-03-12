#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define colors
if command -v tput >/dev/null 2>&1; then
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    RESET=$(tput sgr0)
else
    GREEN=""; RED=""; YELLOW=""; BLUE=""; RESET=""
fi

# Log setup
LOGFILE="install.log"
exec > >(tee -a "$LOGFILE") 2>&1

# Usage function
usageFunction() {
    echo -e "${GREEN}Usage: $0 (-n) (-h)${RESET}"
    echo -e "\t-n Non-interactive installation (Optional)"
    echo -e "\t-h Show usage"
    exit 1
}

# Banner
echo -e "${GREEN}"
cat web/art/reNgine.txt
echo -e "${RESET}"

echo -e "${RED}Before running this script, ensure Docker is running and update the .env file.${RESET}"
echo -e "${YELLOW}Changing the Postgres username & password in .env is highly recommended.${RESET}"

# Check for required tools
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${RESET}"
    exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker Compose is not installed. Please install it first.${RESET}"
    exit 1
fi

# Environment file check
ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Error: .env file not found! Please create and configure it before proceeding.${RESET}"
    exit 1
fi

# Parse command-line arguments
isNonInteractive=false
while getopts "nh" opt; do
    case "$opt" in
        n) isNonInteractive=true ;;
        h) usageFunction ;;
        ?) usageFunction ;;
    esac
done

# Prompt user to confirm .env modifications (if interactive)
if [[ "$isNonInteractive" == "false" ]]; then
    while true; do
        read -p "Have you updated the .env file? (y/n) " answer
        case "$answer" in
            [Yy]*) break ;;  # Proceed with installation
            [Nn]*) echo -e "${RED}Please update .env before proceeding.${RESET}"; exit 1 ;;
            *) echo -e "${YELLOW}Invalid input. Please enter 'y' or 'n'.${RESET}" ;;
        esac
    done
else
    echo -e "${YELLOW}Non-interactive installation mode enabled. Proceeding with installation.${RESET}"
fi

echo -e "\n${BLUE}#########################################################################${RESET}"
echo -e "${YELLOW}This installation script is intended for Linux.${RESET}"
echo -e "${YELLOW}For Mac and Windows, refer to the official guide: https://rengine.wiki${RESET}"
echo -e "${BLUE}#########################################################################${RESET}\n"

# Ensure required packages are installed
echo -e "${GREEN}Updating package list and installing dependencies...${RESET}"
sudo apt-get update -y && sudo apt-get install -y \
    curl \
    git \
    unzip \
    nano \
    python3 \
    python3-pip \
    docker.io \
    docker-compose

echo -e "${GREEN}Installing project dependencies...${RESET}"
pip3 install -r requirements.txt

# Ensure correct file permissions
echo -e "${GREEN}Setting up file permissions...${RESET}"
chmod +x start.sh stop.sh

# Start services
echo -e "${GREEN}Starting Docker services...${RESET}"
docker-compose up -d

echo -e "${GREEN}Installation complete! You can now access the application.${RESET}"
