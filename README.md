# WordPress Blueprint for Coolify

Deploy WordPress with SSH/SFTP access and WP-CLI for each client.

## Features

- **Standard WordPress** - Uses official `wordpress:latest` image
- **Higher PHP Limits** - 512MB upload, 600s execution time
- **SSH/SFTP Access** - Each client gets isolated access to their WordPress files
- **WP-CLI** - Command-line WordPress management via SSH
- **MariaDB 11** - Modern database with automatic healthchecks

## Quick Start

### 1. Deploy via Coolify

1. In Coolify, create new project or use existing
2. Add new Resource → Docker Compose
3. Select "GitHub" and connect to this repo
4. Set domain (e.g., `client.yourdomain.com`)
5. Click Deploy

### 2. Set Up SSH User

After deployment, SSH to your server and run:

```bash
# Find your volume prefix
docker volume ls | grep wordpress-files

# Run setup script (copy to server first)
./scripts/setup-wordpress-user.sh <client-name> <volume-prefix>
```

Example:
```bash
./scripts/setup-wordpress-user.sh natanek j4sos8ccooskswk04c08sc00
```

This creates:
- SSH/SFTP user `natanek` with access only to their WordPress files
- WP-CLI available via `wp` command after SSH login

### 3. Client Connection

Provide client with:
- **SSH**: `ssh natanek@your-server-ip`
- **SFTP**: `sftp natanek@your-server-ip` (or use FileZilla, WinSCP, etc.)

## Automation (Optional)

For automated provisioning with Coolify API:

1. Copy `scripts/config.example.sh` to `scripts/config.sh`
2. Fill in your Coolify API credentials
3. Run: `./scripts/new-wordpress.sh <client-name> <domain>`

## File Structure

```
.
├── docker-compose.yml          # Main Coolify deployment file
├── README.md                   # This file
└── scripts/
    ├── setup-wordpress-user.sh # Creates SSH user for client
    ├── new-wordpress.sh        # Full automation script
    └── config.example.sh       # Configuration template
```

## PHP Configuration

PHP limits are set in `docker-compose.yml` under `uploads.ini`:

- `upload_max_filesize`: 512M
- `post_max_size`: 512M
- `memory_limit`: 512M
- `max_execution_time`: 600
- `max_input_time`: 600
- `max_input_vars`: 10000

To change, edit the values and redeploy.

## WP-CLI Usage

Via Coolify Terminal (select `wpcli` container):
```bash
wp plugin list --allow-root
wp theme list --allow-root
wp core update --allow-root
```

Via SSH (after running setup-wordpress-user.sh):
```bash
wp plugin list
wp theme list
wp core update
```

## Troubleshooting

### SSH Permission Denied

1. Check volume permissions:
```bash
ls -la /var/lib/docker/volumes/*_wordpress-files/
```

2. Fix if needed:
```bash
chmod 755 /var/lib/docker/volumes
chmod 755 /var/lib/docker/volumes/*_wordpress-files
chmod 755 /var/lib/docker/volumes/*_wordpress-files/_data
```

### WP-CLI Not Working via SSH

Make sure the WordPress container is running:
```bash
docker ps | grep wordpress
```

### Finding Volume Prefix

Each Coolify deployment gets a unique prefix. Find it with:
```bash
docker volume ls | grep wordpress-files
```

The prefix is everything before `_wordpress-files`.
