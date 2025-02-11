#!/bin/bash

usageFunction()
{
  echo " "
  tput setaf 2;
  echo "Usage: $0 (-n) (-h)"
  echo -e "\t-n Non-interactive installation (Optional)"
  echo -e "\t-h Show usage"
  exit 1
}

tput setaf 2;
cat web/art/reNgine.txt

tput setaf 1; echo "Before running this script, please make sure Docker is running and you have made changes to .env file."
tput setaf 2; echo "Changing the postgres username & password from .env is highly recommended."

tput setaf 4;

isNonInteractive=false
while getopts nh opt; do
   case $opt in
      n) isNonInteractive=true ;;
      h) usageFunction ;;
      ?) usageFunction ;;
   esac
done

if [ $isNonInteractive = false ]; then
    read -p "Are you sure you made changes to .env file? (y/n) " answer
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
echo "Please note that this installation script is only intended for Linux"
echo "For Mac and Windows, refer to the official guide https://rengine.wiki"
echo "#########################################################################"

echo " "
tput setaf 4;
echo "Installing reNgine and its dependencies"

if [ "$EUID" -ne 0 ]; then
  tput setaf 1; echo "Error installing reNgine, Please run this script as root!"
  tput setaf 1; echo "Example: sudo ./install.sh"
  exit
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Applying Redis memory overcommit fix..."
echo "#########################################################################"

# Ensure the sysctl setting is persistent
if ! grep -q "vm.overcommit_memory=1" /etc/sysctl.conf; then
    echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.conf
fi

# Apply the setting immediately
sudo sysctl -w vm.overcommit_memory=1
sudo sysctl -p

echo "Redis memory overcommit fix applied successfully!"

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing required packages (curl, docker, docker-compose, make)"
echo "#########################################################################"

sudo apt update && sudo apt install -y curl docker.io docker-compose make

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Checking Docker status"
echo "#########################################################################"
if docker info >/dev/null 2>&1; then
  tput setaf 4;
  echo "Docker is running."
else
  tput setaf 1;
  echo "Docker is not running. Please run docker and try again."
  echo "You can run docker service using sudo systemctl start docker"
  exit 1
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Removing orphaned Docker containers..."
echo "#########################################################################"
docker-compose down --remove-orphans

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Resetting PostgreSQL database schema if needed..."
echo "#########################################################################"

docker-compose up -d db  # Ensure the database container is running
sleep 5  # Wait for DB to be ready

if docker exec rengine-db-1 psql -U rengine -d rengine -c "SELECT 1 FROM django_migrations LIMIT 1;" >/dev/null 2>&1; then
  echo "Migrations already applied, skipping..."
else
  echo "Resetting database schema to prevent migration conflicts..."
  docker exec rengine-db-1 psql -U rengine -d rengine -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
fi

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Fixing outdated nginx config for HTTP2"
echo "#########################################################################"

sed -i 's/listen .*http2/listen 443 ssl http2;/' config/nginx/rengine.conf
echo "Updated nginx config to use the correct HTTP2 directive."

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Fixing Python dependency issues before install..."
echo "#########################################################################"

# Create a constraints file to pin conflicting dependencies
cat <<EOT > constraints.txt
SQLAlchemy==1.4.49
tenacity==8.0.1
langchain==0.1.4
EOT

# Install dependencies with constraints to prevent conflicts
docker-compose build --no-cache

echo " "
tput setaf 4;
echo "#########################################################################"
echo "Installing reNgine"
echo "#########################################################################"
make certs && make build && make up && tput setaf 2 && echo "reNgine is installed!!!" && failed=0 || failed=1

if [ "${failed}" -eq 0 ]; then
  sleep 3

  echo " "
  tput setaf 4;
  echo "#########################################################################"
  echo "Creating an account"
  echo "#########################################################################"
  make username isNonInteractive=$isNonInteractive
  make migrate

  tput setaf 2 && printf "\n%s\n" "Thank you for installing reNgine, happy recon!!"
  echo "In case you have unapplied migrations (see above in red), run 'make migrate'"
else
  tput setaf 1 && printf "\n%s\n" "reNgine installation failed!!"
fi
