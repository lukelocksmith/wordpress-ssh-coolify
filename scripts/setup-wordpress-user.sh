#!/bin/bash
#
# WordPress User Setup Script for Coolify
# Creates system user with SSH/SFTP access to WordPress files
#
# Usage: ./setup-wordpress-user.sh <username> <volume-prefix>
# Example: ./setup-wordpress-user.sh natanek j4sos8ccooskswk04c08sc00
#
# The volume-prefix is the Coolify container ID prefix, found in:
#   docker volume ls | grep wordpress-files
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Arguments
USERNAME=$1
VOLUME_PREFIX=$2

if [ -z "$USERNAME" ] || [ -z "$VOLUME_PREFIX" ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo "Usage: $0 <username> <volume-prefix>"
    echo ""
    echo "Find your volume prefix with:"
    echo "  docker volume ls | grep wordpress-files"
    exit 1
fi

# Paths
VOLUME_PATH="/var/lib/docker/volumes/${VOLUME_PREFIX}_wordpress-files/_data"
WP_CLI_PATH="/usr/local/bin/wp-${USERNAME}"

# Check if volume exists
if [ ! -d "$VOLUME_PATH" ]; then
    echo -e "${RED}Error: Volume path not found: $VOLUME_PATH${NC}"
    echo ""
    echo "Available WordPress volumes:"
    docker volume ls | grep wordpress-files || echo "No WordPress volumes found"
    exit 1
fi

echo -e "${YELLOW}Setting up WordPress user: $USERNAME${NC}"
echo "Volume path: $VOLUME_PATH"

# Generate random password
PASSWORD=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)

# Create user with UID 33 (www-data) if doesn't exist
if id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}User $USERNAME already exists, updating...${NC}"
    usermod -d "$VOLUME_PATH" -s /bin/bash "$USERNAME"
else
    echo "Creating user $USERNAME..."
    useradd -u 33 -o -g 33 -d "$VOLUME_PATH" -s /bin/bash -M "$USERNAME"
fi

# Set password
echo "${USERNAME}:${PASSWORD}" | chpasswd

# Ensure proper permissions on volume path
echo "Setting permissions..."
chmod 755 /var/lib/docker/volumes
chmod 755 "/var/lib/docker/volumes/${VOLUME_PREFIX}_wordpress-files"
chmod 755 "$VOLUME_PATH"

# Create WP-CLI wrapper script for this user
echo "Creating WP-CLI wrapper..."
cat > "$WP_CLI_PATH" << 'WPCLI_SCRIPT'
#!/bin/bash
# WP-CLI wrapper - runs inside WordPress container

VOLUME_PREFIX="__VOLUME_PREFIX__"
CONTAINER=$(docker ps --filter "name=${VOLUME_PREFIX}" --filter "ancestor=wordpress:latest" -q | head -1)

if [ -z "$CONTAINER" ]; then
    echo "Error: WordPress container not running"
    exit 1
fi

# Run WP-CLI command inside container
docker exec -u 33 "$CONTAINER" wp "$@"
WPCLI_SCRIPT

# Replace placeholder with actual volume prefix
sed -i "s/__VOLUME_PREFIX__/${VOLUME_PREFIX}/" "$WP_CLI_PATH"
chmod +x "$WP_CLI_PATH"

# Create symlink so 'wp' command works for this user
USER_BIN_PATH="${VOLUME_PATH}/.local/bin"
mkdir -p "$USER_BIN_PATH"
ln -sf "$WP_CLI_PATH" "${USER_BIN_PATH}/wp"
chown -R 33:33 "${VOLUME_PATH}/.local"

# Add .local/bin to PATH in .bashrc
BASHRC="${VOLUME_PATH}/.bashrc"
if [ ! -f "$BASHRC" ] || ! grep -q ".local/bin" "$BASHRC"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
    chown 33:33 "$BASHRC"
fi

# Output summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}WordPress User Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Username:    ${YELLOW}${USERNAME}${NC}"
echo -e "Password:    ${YELLOW}${PASSWORD}${NC}"
echo -e "Server:      ${YELLOW}$(hostname -I | awk '{print $1}')${NC}"
echo ""
echo "SSH/SFTP Connection:"
echo -e "  ${YELLOW}ssh ${USERNAME}@$(hostname -I | awk '{print $1}')${NC}"
echo -e "  ${YELLOW}sftp ${USERNAME}@$(hostname -I | awk '{print $1}')${NC}"
echo ""
echo "WP-CLI (after SSH login):"
echo -e "  ${YELLOW}wp plugin list${NC}"
echo -e "  ${YELLOW}wp theme list${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
