#!/bin/bash

# Exit immediately if a command fails
set -e

# Define colors for readability
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

echo -e "${RED}Before running this script, ensure you have updated the .env file.${RESET}"
echo -e "${YELLOW}Changing the Postgres username & password in .env is highly recommended.${RESET}"

# Check if running as root (for package installation)
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (use sudo).${RESET}"
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

# Ensure required packages are installed
echo -e "${GREEN}Updating package list and installing dependencies...${RESET}"
apt-get update -y && apt-get install -y \
    curl \
    git \
    unzip \
    nano \
    python3 \
    python3-pip

# Install Docker if not installed
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}Docker is not installed. Installing now...${RESET}"
    apt-get install -y docker.io
    systemctl enable --now docker
fi

# Install Docker Compose if not installed
if ! command -v docker-compose >/dev/null 2>&1; then
    echo -e "${YELLOW}Docker Compose is not installed. Installing now...${RESET}"
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Ensure Docker is running
if ! systemctl is-active --quiet docker; then
    echo -e "${RED}Docker is installed but not running. Starting Docker...${RESET}"
    systemctl start docker
fi

# Environment file check
ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Error: .env file not found! Please create and configure it before proceeding.${RESET}"
    exit 1
fi

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

echo -e "${GREEN}Installing project dependencies...${RESET}"
pip3 install -r requirements.txt

# Ensure correct file permissions
echo -e "${GREEN}Setting up file permissions...${RESET}"
chmod +x start.sh stop.sh

# Start services
echo -e "${GREEN}Starting Docker services...${RESET}"
docker-compose up -d

echo -e "${GREEN}Installation complete! You can now access the application.${RESET}"
