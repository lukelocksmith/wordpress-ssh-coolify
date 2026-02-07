#!/bin/bash
#
# Coolify Configuration
# Copy this file to config.sh and fill in your values
#
# To get these UUIDs, go to Coolify:
# - Project UUID: Click on project -> URL shows /project/{uuid}
# - Server UUID: Servers page -> click server -> URL shows /server/{uuid}
# - Destination UUID: Usually "default" or check in project settings
#
# API Token: Settings -> Keys & Tokens -> API Tokens -> Create new token
#

export COOLIFY_URL="http://localhost:8000"
export COOLIFY_API_TOKEN="your-api-token-here"
export COOLIFY_PROJECT_UUID="project-uuid-here"
export COOLIFY_SERVER_UUID="server-uuid-here"
export COOLIFY_DESTINATION_UUID="default"

# Default domain suffix
export DEFAULT_DOMAIN_SUFFIX="important.is"
