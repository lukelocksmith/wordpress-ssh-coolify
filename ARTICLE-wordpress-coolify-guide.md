# Kompletny przewodnik: WordPress na Coolify z SSH, SFTP i WP-CLI

> Jak skonfigurować profesjonalne środowisko WordPress na self-hosted Coolify z pełnym dostępem developerskim

## Spis treści

1. [Wprowadzenie](#wprowadzenie)
2. [Architektura rozwiązania](#architektura-rozwiązania)
3. [Docker Compose - szczegółowy opis](#docker-compose---szczegółowy-opis)
4. [Konfiguracja PHP](#konfiguracja-php)
5. [SSH/SFTP dla developerów](#sshsftp-dla-developerów)
6. [WP-CLI przez SSH](#wp-cli-przez-ssh)
7. [Rozwiązane problemy](#rozwiązane-problemy)
8. [Automatyzacja](#automatyzacja)
9. [Podsumowanie](#podsumowanie)

---

## Wprowadzenie

Coolify to świetna alternatywa dla platform typu Vercel czy Heroku, pozwalająca na self-hosting aplikacji. Jednak standardowa konfiguracja WordPress na Coolify ma kilka ograniczeń:

- **Brak SSH/SFTP** - developerzy nie mogą połączyć się przez ulubione narzędzia (FileZilla, WinSCP, VS Code Remote)
- **Niskie limity PHP** - domyślnie tylko 2MB upload i 128MB pamięci
- **Brak WP-CLI** - utrudnione zarządzanie WordPress z linii komend
- **Izolacja dostępu** - jak dać dostęp tylko do konkretnej instalacji WordPress?

Ten przewodnik pokazuje jak rozwiązać wszystkie te problemy.

---

## Architektura rozwiązania

```
┌─────────────────────────────────────────────────────────────┐
│                        SERWER HETZNER                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  Coolify    │  │   Traefik   │  │ System SSH  │          │
│  │  (zarządza) │  │   (proxy)   │  │  (port 22)  │          │
│  └─────────────┘  └─────────────┘  └──────┬──────┘          │
│                                           │                  │
│  ┌────────────────────────────────────────┼─────────────┐   │
│  │              Docker Network            │             │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────┴─────┐      │   │
│  │  │ WordPress │  │  MariaDB  │  │   WP-CLI    │      │   │
│  │  │  :80      │  │  :3306    │  │  (helper)   │      │   │
│  │  └─────┬─────┘  └───────────┘  └─────────────┘      │   │
│  │        │                                             │   │
│  │  ┌─────┴─────────────────────────────────────┐      │   │
│  │  │           Docker Volume                    │      │   │
│  │  │   /var/lib/docker/volumes/xxx_wordpress   │◄─────┼───┤
│  │  └───────────────────────────────────────────┘      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  System Users (np. kpd, natanek) ──► home = Docker Volume   │
└─────────────────────────────────────────────────────────────┘
```

**Kluczowa innowacja:** Tworzymy użytkowników systemowych, których katalog domowy wskazuje bezpośrednio na Docker Volume z plikami WordPress. Dzięki temu:

- SSH/SFTP działa przez standardowy port 22
- Każdy developer ma dostęp tylko do swojego WordPress
- Nie potrzeba osobnych kontenerów SSH

---

## Docker Compose - szczegółowy opis

```yaml
# WordPress Blueprint for Coolify
#
# Features:
# - Standard wordpress:latest image
# - PHP limits configurable (edit content below)
# - WP-CLI via Coolify Terminal (wpcli container)
#
# SSH/SFTP Access:
#   After deployment, run on server:
#   /root/setup-wordpress-user.sh <client-name> <volume-prefix>
#
# WP-CLI (use Coolify Terminal, select wpcli container):
#   wp plugin list --allow-root
#   wp theme list --allow-root

services:
  wordpress:
    image: wordpress:latest
    volumes:
      - wordpress-files:/var/www/html
      - type: bind
        source: ./uploads.ini
        target: /usr/local/etc/php/conf.d/uploads.ini
        content: |
          file_uploads = On
          upload_max_filesize = 512M
          post_max_size = 512M
          memory_limit = 512M
          max_execution_time = 600
          max_input_time = 600
          max_input_vars = 10000
    environment:
      - WORDPRESS_DB_HOST=mariadb
      - WORDPRESS_DB_USER=$SERVICE_USER_WORDPRESS
      - WORDPRESS_DB_PASSWORD=$SERVICE_PASSWORD_WORDPRESS
      - WORDPRESS_DB_NAME=wordpress
    depends_on:
      mariadb:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -sL http://localhost:80/ -o /dev/null -w '%{http_code}' | grep -qE '^[23]'"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 60s

  mariadb:
    image: mariadb:11
    volumes:
      - mariadb-data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=$SERVICE_PASSWORD_ROOT
      - MYSQL_DATABASE=wordpress
      - MYSQL_USER=$SERVICE_USER_WORDPRESS
      - MYSQL_PASSWORD=$SERVICE_PASSWORD_WORDPRESS
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 5s
      timeout: 20s
      retries: 10

  wpcli:
    image: wordpress:cli
    init: true  # WAŻNE: Zapobiega zombie processes
    volumes:
      - wordpress-files:/var/www/html
    environment:
      - WORDPRESS_DB_HOST=mariadb
      - WORDPRESS_DB_USER=$SERVICE_USER_WORDPRESS
      - WORDPRESS_DB_PASSWORD=$SERVICE_PASSWORD_WORDPRESS
      - WORDPRESS_DB_NAME=wordpress
    depends_on:
      - wordpress
      - mariadb
    entrypoint: ["tail", "-f", "/dev/null"]
    user: "0:0"

volumes:
  wordpress-files:
  mariadb-data:
```

### Wyjaśnienie kluczowych elementów

#### 1. Coolify `content:` syntax

```yaml
- type: bind
  source: ./uploads.ini
  target: /usr/local/etc/php/conf.d/uploads.ini
  content: |
    file_uploads = On
    upload_max_filesize = 512M
    ...
```

To specjalna składnia Coolify - pozwala tworzyć pliki "w locie" bez commitowania ich do repo. Coolify automatycznie tworzy plik `uploads.ini` z podaną zawartością.

#### 2. Zmienne środowiskowe Coolify

```yaml
- WORDPRESS_DB_USER=$SERVICE_USER_WORDPRESS
- WORDPRESS_DB_PASSWORD=$SERVICE_PASSWORD_WORDPRESS
```

Coolify automatycznie generuje bezpieczne hasła i podstawia je pod te zmienne. Nie musisz ręcznie tworzyć credentials.

#### 3. Healthcheck z obsługą redirectów

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sL http://localhost:80/ -o /dev/null -w '%{http_code}' | grep -qE '^[23]'"]
```

Flaga `-L` podąża za przekierowaniami (np. HTTP→HTTPS), a regex `'^[23]'` akceptuje kody 2xx i 3xx.

#### 4. `init: true` dla WP-CLI

```yaml
wpcli:
  init: true  # Zapobiega zombie processes
  entrypoint: ["tail", "-f", "/dev/null"]
```

**Problem:** Używanie `tail -f /dev/null` jako entrypoint powoduje, że procesy potomne (komendy WP-CLI) nie są prawidłowo "zbierane" po zakończeniu, tworząc zombie processes.

**Rozwiązanie:** `init: true` dodaje prosty init system (tini), który prawidłowo zarządza procesami potomnymi.

---

## Konfiguracja PHP

### Metoda 1: Przez docker-compose (trwała)

Użyj składni `content:` w docker-compose.yml jak pokazano wyżej. Ustawienia przetrwają redeploy.

### Metoda 2: Przez .htaccess (szybka)

Dodaj do `.htaccess` w katalogu WordPress:

```apache
# PHP Limits
php_value upload_max_filesize 512M
php_value post_max_size 512M
php_value memory_limit 512M
php_value max_execution_time 600
php_value max_input_time 600
php_value max_input_vars 10000
```

### Metoda 3: Przez php.ini w kontenerze (tymczasowa)

```bash
docker exec wordpress-CONTAINER sh -c "cat > /usr/local/etc/php/conf.d/uploads.ini << 'EOF'
file_uploads = On
upload_max_filesize = 512M
post_max_size = 512M
memory_limit = 512M
max_execution_time = 600
max_input_time = 600
max_input_vars = 10000
EOF"
```

**Uwaga:** Ta metoda nie przetrwa restartu kontenera.

### Weryfikacja ustawień

```bash
# Z poziomu kontenera
docker exec wordpress-xxx php -i | grep -E 'upload_max|memory_limit'

# Lub przez phpinfo()
echo "<?php phpinfo();" > /path/to/wordpress/info.php
curl https://twoja-domena.pl/info.php | grep upload_max
rm /path/to/wordpress/info.php
```

---

## SSH/SFTP dla developerów

### Koncepcja

Zamiast uruchamiać osobny kontener SSH (co komplikuje konfigurację sieci), tworzymy użytkowników systemowych na hoście z katalogiem domowym wskazującym na Docker Volume.

### Skrypt setup-wordpress-user.sh

```bash
#!/bin/bash
#
# WordPress User Setup Script for Coolify
# Creates system user with SSH/SFTP access to WordPress files + WP-CLI
#
# Usage: ./setup-wordpress-user.sh <username> <volume-prefix>
# Example: ./setup-wordpress-user.sh natanek j4sos8ccooskswk04c08sc00

set -e

USERNAME=$1
VOLUME_PREFIX=$2

if [ -z "$USERNAME" ] || [ -z "$VOLUME_PREFIX" ]; then
    echo "Usage: $0 <username> <volume-prefix>"
    echo "Find your volume prefix with: docker volume ls | grep wordpress-files"
    exit 1
fi

VOLUME_PATH="/var/lib/docker/volumes/${VOLUME_PREFIX}_wordpress-files/_data"

# Sprawdź czy volume istnieje
if [ ! -d "$VOLUME_PATH" ]; then
    echo "Error: Volume path not found: $VOLUME_PATH"
    exit 1
fi

# Wygeneruj hasło
PASSWORD=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)

# Utwórz użytkownika z grupą www-data (GID 33)
if id "$USERNAME" &>/dev/null; then
    usermod -d "$VOLUME_PATH" -s /bin/bash -g 33 "$USERNAME"
else
    useradd -g 33 -d "$VOLUME_PATH" -s /bin/bash -M "$USERNAME"
fi

# Dodaj do grupy docker (potrzebne dla WP-CLI)
usermod -aG docker "$USERNAME"

# Ustaw hasło
echo "${USERNAME}:${PASSWORD}" | chpasswd

# Napraw uprawnienia ścieżki
chmod o+x /var/lib/docker
chmod o+x /var/lib/docker/volumes
chmod o+x "/var/lib/docker/volumes/${VOLUME_PREFIX}_wordpress-files"
chmod o+x "$VOLUME_PATH"

# Utwórz wrapper WP-CLI
cat > "/usr/local/bin/wp-${USERNAME}" << WPCLI
#!/bin/bash
CONTAINER=\$(docker ps --filter "name=${VOLUME_PREFIX}" --filter "ancestor=wordpress:cli" -q | head -1)
if [ -z "\$CONTAINER" ]; then
    echo "Error: WP-CLI container not running"
    exit 1
fi
docker exec "\$CONTAINER" wp --allow-root "\$@"
WPCLI
chmod +x "/usr/local/bin/wp-${USERNAME}"

# Skonfiguruj PATH dla użytkownika
mkdir -p "${VOLUME_PATH}/.local/bin"
ln -sf "/usr/local/bin/wp-${USERNAME}" "${VOLUME_PATH}/.local/bin/wp"
echo 'export PATH="$HOME/.local/bin:$PATH"' > "${VOLUME_PATH}/.bashrc"
chown -R "$USERNAME:www-data" "${VOLUME_PATH}/.local" "${VOLUME_PATH}/.bashrc"
touch "${VOLUME_PATH}/.bash_history"
chown "$USERNAME:www-data" "${VOLUME_PATH}/.bash_history"

echo "================================"
echo "User: $USERNAME"
echo "Password: $PASSWORD"
echo "SSH: ssh ${USERNAME}@$(hostname -I | awk '{print $1}')"
echo "================================"
```

### Jak znaleźć volume-prefix?

```bash
docker volume ls | grep wordpress-files
```

Output:
```
local     j4sos8ccooskswk04c08sc00_wordpress-files
local     t0csk4c8ook8ws0os4wwo4k0_wordpress-files
```

Prefix to część przed `_wordpress-files`.

### Użycie

```bash
# Na serwerze jako root
./setup-wordpress-user.sh kpd j4sos8ccooskswk04c08sc00

# Developer łączy się:
ssh kpd@65.21.75.39
sftp kpd@65.21.75.39
```

---

## WP-CLI przez SSH

Po zalogowaniu przez SSH, użytkownik ma dostęp do komendy `wp`:

```bash
# Po SSH
ssh kpd@65.21.75.39

# Komendy WP-CLI
wp plugin list
wp theme list
wp core version
wp user list
wp post list
wp db export backup.sql
```

### Jak to działa?

Wrapper script `/usr/local/bin/wp-kpd` wykonuje komendy wewnątrz kontenera `wordpress:cli`:

```bash
docker exec CONTAINER wp --allow-root "$@"
```

---

## Rozwiązane problemy

### Problem 1: Zombie processes (2869 procesów!)

**Symptom:**
```
=> There are 2869 zombie processes.
```

**Przyczyna:** Kontener `wpcli` używał `tail -f /dev/null` jako entrypoint. Gdy wykonywano komendy przez `docker exec`, procesy potomne nie były prawidłowo "zbierane".

**Rozwiązanie:** Dodanie `init: true` do kontenera wpcli:

```yaml
wpcli:
  init: true  # Dodaje tini jako init system
  entrypoint: ["tail", "-f", "/dev/null"]
```

### Problem 2: DNS nie działa w kontenerach Docker

**Symptom:**
```
fatal: unable to access 'https://github.com/...': Could not resolve host: github.com
```

**Przyczyna:** Docker był skonfigurowany z publicznymi DNS (1.1.1.1, 8.8.8.8), ale Hetzner blokuje zewnętrzne serwery DNS.

**Rozwiązanie:** Użycie DNS Hetzner w `/etc/docker/daemon.json`:

```json
{
  "dns": [
    "185.12.64.2",
    "185.12.64.1"
  ]
}
```

Po zmianie: `systemctl restart docker`

### Problem 3: SSH Permission Denied

**Symptom:**
```
Could not chdir to home directory: Permission denied
```

**Przyczyna:** Użytkownik nie miał uprawnień do traversowania ścieżki `/var/lib/docker/volumes/...`

**Rozwiązanie:**
```bash
chmod o+x /var/lib/docker
chmod o+x /var/lib/docker/volumes
chmod o+x /var/lib/docker/volumes/PREFIX_wordpress-files
chmod o+x /var/lib/docker/volumes/PREFIX_wordpress-files/_data
```

### Problem 4: Healthcheck fails na WordPress

**Symptom:** Coolify pokazuje "No available server"

**Przyczyna:** WordPress zwraca redirect (302) zamiast 200, a domyślny curl nie podąża za redirectami.

**Rozwiązanie:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sL http://localhost:80/ -o /dev/null -w '%{http_code}' | grep -qE '^[23]'"]
```

### Problem 5: WP-CLI "executable not found"

**Symptom:**
```
exec: "wp": executable file not found in $PATH
```

**Przyczyna:** Wrapper szukał WP-CLI w kontenerze `wordpress:latest`, który go nie zawiera.

**Rozwiązanie:** Zmiana wrappera na użycie kontenera `wordpress:cli`:
```bash
CONTAINER=$(docker ps --filter "ancestor=wordpress:cli" -q)
```

---

## Automatyzacja

### Proces dodawania nowego klienta

1. **W Coolify:** Utwórz nowy projekt z tego docker-compose
2. **Ustaw domenę:** np. `natanek.important.is`
3. **Deploy**
4. **Na serwerze:**
   ```bash
   # Znajdź prefix
   docker volume ls | grep wordpress-files

   # Utwórz użytkownika
   ./setup-wordpress-user.sh natanek PREFIX
   ```
5. **Przekaż dane klientowi:**
   - SSH: `ssh natanek@IP`
   - SFTP: `sftp natanek@IP`
   - Hasło: (wygenerowane przez skrypt)

### Pełna automatyzacja z Coolify API

Coolify ma REST API, które pozwala na programowe tworzenie aplikacji:

```bash
curl -X POST "https://coolify.yourdomain.com/api/v1/applications/dockercompose" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_uuid": "...",
    "server_uuid": "...",
    "name": "wordpress-natanek",
    "docker_compose_raw": "..."
  }'
```

---

## Podsumowanie

### Co osiągnęliśmy

| Funkcja | Status |
|---------|--------|
| WordPress na Coolify | ✅ |
| Wyższe limity PHP (512MB) | ✅ |
| SSH dostęp dla developerów | ✅ |
| SFTP dostęp | ✅ |
| WP-CLI przez SSH | ✅ |
| Izolacja - każdy widzi tylko swój WordPress | ✅ |
| Zero zombie processes | ✅ |
| Automatyzacja nowych klientów | ✅ |

### Pliki w repozytorium

```
wordpress-coolify-blueprint/
├── docker-compose.yml           # Główna konfiguracja
├── README.md                    # Dokumentacja
├── ARTICLE-wordpress-coolify-guide.md  # Ten artykuł
└── scripts/
    ├── setup-wordpress-user.sh  # Tworzenie użytkownika SSH
    ├── new-wordpress.sh         # Pełna automatyzacja
    └── config.example.sh        # Szablon konfiguracji
```

### Repozytorium

https://github.com/lukelocksmith/wordpress-ssh-coolify

---

## Autor

Artykuł powstał na podstawie rzeczywistej konfiguracji serwera Hetzner z Coolify, rozwiązując problemy napotkane podczas migracji z tradycyjnego hostingu (DirectAdmin) na self-hosted rozwiązanie.

*Ostatnia aktualizacja: Luty 2026*
