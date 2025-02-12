#!/bin/bash

usageFunction() {
  echo " "
  tput setaf 2;
  echo "Usage: $0 (-n) (-h)"
  echo -e "\t-n Non-interactive installation (Optional)"
  echo -e "\t-h Show usage"
  exit 1
}

tput setaf 2;
cat web/art/reNgine.txt

tput setaf 1; echo "Before running this script, please make sure Docker is running and you have made changes to the .env file."
tput setaf 2; echo "Changing the PostgreSQL username & password from .env is highly recommended."

tput setaf 4;

isNonInteractive=false
while getopts nh opt; do
   case $opt in
      n) isNonInteractive=true ;;
      h) usageFunction ;;
      ?) usageFunction ;;
   esac
done

if [ "$EUID" -ne 0 ]; then
  tput setaf 1; echo "Error: Please run this script as root!"
  tput setaf 1; echo "Example: sudo ./install.sh"
  exit 1
fi

if [ $isNonInteractive = false ]; then
    read -p "Are you sure, you made changes to .env file (y/n)? " answer
    case ${answer:0:1} in
        y|Y|yes|YES|Yes )
          echo "Continuing Installation!"
        ;;
        * )
          nano .env
        ;;
    esac
else
  echo "Non-interactive installation parameter set. Installation begins."
fi

echo " "
tput setaf 3;
echo "#########################################################################"
echo "This installation script is only intended for Linux."
echo "For Mac and Windows, refer to the official guide https://rengine.wiki"
echo "#########################################################################"

echo " "
tput setaf 4;
echo "Applying Redis memory overcommit fix..."
echo "#########################################################################"

if ! grep -q "vm.overcommit_memory=1" /etc/sysctl.conf; then
    echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.conf
fi

sudo sysctl -w vm.overcommit_memory=1
sudo sysctl -p

echo "Redis memory overcommit fix applied successfully!"

echo " "
tput setaf 4;
echo "Installing dependencies (curl, make, docker, docker-compose)..."
echo "#########################################################################"

sudo apt update -y
sudo apt install -y curl make

if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
  systemctl enable docker
  systemctl start docker
  tput setaf 2; echo "Docker installed!"
else
  tput setaf 2; echo "Docker already installed, skipping."
fi

if ! command -v docker-compose &> /dev/null; then
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
  tput setaf 2; echo "Docker Compose installed!"
else
  tput setaf 2; echo "Docker Compose already installed, skipping."
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Checking Docker status..."
echo "#########################################################################"

if docker info >/dev/null 2>&1; then
  tput setaf 4;
  echo "Docker is running."
else
  tput setaf 1;
  echo "Docker is not running. Please start Docker and try again."
  echo "You can run Docker service using: sudo systemctl start docker"
  exit 1
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Starting PostgreSQL and Redis containers..."
echo "#########################################################################"

docker-compose down --remove-orphans
docker-compose up -d db redis

echo "Waiting for PostgreSQL to start..."
sleep 10

if docker exec rengine-db-1 psql -U rengine -d rengine -c "SELECT 1;" >/dev/null 2>&1; then
  echo "PostgreSQL is running."
else
  echo "Error: PostgreSQL failed to start."
  exit 1
fi

if docker logs rengine-redis-1 2>&1 | grep -q "Fatal error"; then
  echo "Error: Redis is not running properly."
  exit 1
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing reNgine"
echo "#########################################################################"

make certs && make build && make up && tput setaf 2 && echo "reNgine is installed!" && failed=0 || failed=1

if [ "${failed}" -eq 0 ]; then
  sleep 3

  echo " "
  tput setaf 4;
  echo "#########################################################################"
  echo "Creating an account"
  echo "#########################################################################"
  make username isNonInteractive=$isNonInteractive
  make migrate

  tput setaf 2 && printf "\n%s\n" "Thank you for installing reNgine, happy recon!"
  echo "In case you have unapplied migrations, run: 'make migrate'"
else
  tput setaf 1 && printf "\n%s\n" "reNgine installation failed!"
fi
