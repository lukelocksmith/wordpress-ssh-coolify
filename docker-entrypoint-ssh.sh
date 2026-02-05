#!/bin/bash
set -e

# Set root password from environment variable (or default)
if [ -n "$SSH_PASSWORD" ]; then
    echo "root:$SSH_PASSWORD" | chpasswd
else
    # Generate random password if not set
    RANDOM_PASS=$(openssl rand -base64 12)
    echo "root:$RANDOM_PASS" | chpasswd
    echo "=========================================="
    echo "SSH root password (auto-generated): $RANDOM_PASS"
    echo "Set SSH_PASSWORD env var to use custom password"
    echo "=========================================="
fi

# Create www-data user for WP-CLI if needed
if ! id "wpuser" &>/dev/null; then
    useradd -m -s /bin/bash wpuser
    usermod -aG www-data wpuser
    if [ -n "$SSH_PASSWORD" ]; then
        echo "wpuser:$SSH_PASSWORD" | chpasswd
    fi
fi

# Start SSH daemon in background
/usr/sbin/sshd

# Call original WordPress entrypoint
exec docker-entrypoint.sh "$@"
