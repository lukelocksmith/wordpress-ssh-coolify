#!/bin/bash
#
# New WordPress Site Provisioning Script for Coolify
#
# This script creates a new WordPress site with:
# - Coolify deployment via API
# - SSH/SFTP user access
# - WP-CLI access
#
# Usage: ./new-wordpress.sh <client-name> [domain]
# Example: ./new-wordpress.sh natanek natanek.important.is
#
# Requirements:
# - COOLIFY_API_TOKEN environment variable
# - COOLIFY_URL environment variable (default: http://localhost:8000)
# - COOLIFY_PROJECT_UUID - project to add WordPress to
# - COOLIFY_SERVER_UUID - server to deploy to
# - COOLIFY_DESTINATION_UUID - Docker network destination
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - set these or use environment variables
COOLIFY_URL="${COOLIFY_URL:-http://localhost:8000}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_TEMPLATE="${SCRIPT_DIR}/../docker-compose.yml"

# Arguments
CLIENT_NAME=$1
DOMAIN=${2:-"${CLIENT_NAME}.important.is"}

# Validation
if [ -z "$CLIENT_NAME" ]; then
    echo -e "${RED}Error: Client name required${NC}"
    echo ""
    echo "Usage: $0 <client-name> [domain]"
    echo "Example: $0 natanek natanek.important.is"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}New WordPress Site: $CLIENT_NAME${NC}"
echo -e "${BLUE}Domain: $DOMAIN${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if we have Coolify API token
if [ -z "$COOLIFY_API_TOKEN" ]; then
    echo -e "${YELLOW}Note: COOLIFY_API_TOKEN not set${NC}"
    echo "You'll need to create the application manually in Coolify."
    echo ""
    echo "Steps:"
    echo "1. Go to Coolify dashboard"
    echo "2. Create new project or select existing"
    echo "3. Add new Resource -> Docker Compose"
    echo "4. Use the docker-compose.yml from this repo"
    echo "5. Set domain: $DOMAIN"
    echo "6. Deploy"
    echo ""
    read -p "Press Enter after deployment is complete..."

    # Find the volume prefix
    echo ""
    echo "Finding WordPress volume..."
    VOLUMES=$(docker volume ls --format '{{.Name}}' | grep wordpress-files)

    if [ -z "$VOLUMES" ]; then
        echo -e "${RED}No WordPress volumes found${NC}"
        exit 1
    fi

    echo "Available WordPress volumes:"
    echo "$VOLUMES" | nl
    echo ""
    read -p "Enter the number of the volume for $CLIENT_NAME: " VOLUME_NUM

    VOLUME_PREFIX=$(echo "$VOLUMES" | sed -n "${VOLUME_NUM}p" | sed 's/_wordpress-files//')
else
    echo "Creating WordPress via Coolify API..."

    # Read docker-compose template
    if [ ! -f "$DOCKER_COMPOSE_TEMPLATE" ]; then
        echo -e "${RED}Error: docker-compose.yml not found at $DOCKER_COMPOSE_TEMPLATE${NC}"
        exit 1
    fi

    DOCKER_COMPOSE_CONTENT=$(cat "$DOCKER_COMPOSE_TEMPLATE")

    # Create application via API
    RESPONSE=$(curl -s -X POST "${COOLIFY_URL}/api/v1/applications/dockercompose" \
        -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d @- << EOF
{
    "project_uuid": "${COOLIFY_PROJECT_UUID}",
    "server_uuid": "${COOLIFY_SERVER_UUID}",
    "environment_name": "production",
    "destination_uuid": "${COOLIFY_DESTINATION_UUID}",
    "name": "wordpress-${CLIENT_NAME}",
    "description": "WordPress for ${CLIENT_NAME}",
    "docker_compose_raw": $(echo "$DOCKER_COMPOSE_CONTENT" | jq -Rs .),
    "instant_deploy": true
}
EOF
    )

    APP_UUID=$(echo "$RESPONSE" | jq -r '.uuid // empty')

    if [ -z "$APP_UUID" ]; then
        echo -e "${RED}Error creating application:${NC}"
        echo "$RESPONSE"
        exit 1
    fi

    echo -e "${GREEN}Application created: $APP_UUID${NC}"
    echo "Waiting for deployment..."

    # Wait for deployment
    sleep 30

    # Find the volume
    VOLUME_PREFIX=$(docker volume ls --format '{{.Name}}' | grep wordpress-files | tail -1 | sed 's/_wordpress-files//')
fi

if [ -z "$VOLUME_PREFIX" ]; then
    echo -e "${RED}Error: Could not determine volume prefix${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Volume prefix: $VOLUME_PREFIX${NC}"

# Set up SSH user
echo ""
echo "Setting up SSH/SFTP user..."
"${SCRIPT_DIR}/setup-wordpress-user.sh" "$CLIENT_NAME" "$VOLUME_PREFIX"

# Save to config file for tracking
CONFIG_FILE="${SCRIPT_DIR}/../wordpress-sites.txt"
echo "${CLIENT_NAME}|${DOMAIN}|${VOLUME_PREFIX}|$(date +%Y-%m-%d)" >> "$CONFIG_FILE"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}WordPress Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Site Information:"
echo -e "  Domain:    ${YELLOW}https://${DOMAIN}${NC}"
echo -e "  Client:    ${YELLOW}${CLIENT_NAME}${NC}"
echo ""
echo "Next Steps:"
echo "1. Complete WordPress installation at https://${DOMAIN}"
echo "2. User can connect via SSH/SFTP (credentials shown above)"
echo ""
