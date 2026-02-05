# WordPress Blueprint for Coolify

Gotowy template WordPress z:
- ✅ Zwiększonymi limitami PHP (512M upload, 512M memory, 10000 max_input_vars)
- ✅ SSH access + WP-CLI

## Opcja 1: Pełna wersja z SSH (zalecana)

### Krok 1: Zbuduj i wypchnij obraz do registry

```bash
# Na serwerze lub lokalnie
cd wordpress-coolify-blueprint

# Zbuduj obraz
docker build -t wordpress-ssh:latest .

# Tag dla GitHub Container Registry
docker tag wordpress-ssh:latest ghcr.io/TWOJ_USERNAME/wordpress-ssh:latest

# Zaloguj się do GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u TWOJ_USERNAME --password-stdin

# Wypchnij
docker push ghcr.io/TWOJ_USERNAME/wordpress-ssh:latest
```

### Krok 2: W Coolify

1. **New Resource** → **Docker Compose**
2. Wklej zawartość `docker-compose.yml`
3. Zmień `build:` na `image: ghcr.io/TWOJ_USERNAME/wordpress-ssh:latest`
4. Dodaj zmienne środowiskowe:
   - `SSH_PASSWORD` - hasło do SSH
5. W sekcji **Ports** dodaj mapowanie dla SSH (np. `2222:22`)
6. Deploy!

### Łączenie przez SSH

```bash
ssh -p 2222 root@twoja-domena.com
# lub
ssh -p 2222 wpuser@twoja-domena.com

# WP-CLI
wp plugin list --path=/var/www/html
wp theme list --path=/var/www/html
```

---

## Opcja 2: Prosta wersja (bez SSH)

Jeśli nie potrzebujesz SSH, tylko zwiększone limity PHP:

### Krok 1: W Coolify

1. **New Resource** → **Docker Compose**
2. Wklej zawartość `docker-compose-simple.yml`
3. Deploy

### Krok 2: Dodaj uploads.ini

1. Wejdź w **Storages** → **Add Storage**
2. **Source Path**: `/data/coolify/services/TWOJ_SERVICE_ID/uploads.ini`
3. **Destination Path**: `/usr/local/etc/php/conf.d/uploads.ini`
4. Stwórz plik na serwerze z zawartością `uploads.ini`
5. Restart service

---

## Alternatywa: Szybka zmiana przez .htaccess

Jeśli masz już działający WordPress, edytuj `.htaccess`:

```apache
# PHP Limits
php_value upload_max_filesize 512M
php_value post_max_size 512M
php_value memory_limit 512M
php_value max_execution_time 600
php_value max_input_time 600
php_value max_input_vars 10000
```

---

## WP-CLI bez SSH (przez docker exec)

Nawet bez SSH możesz używać WP-CLI:

```bash
# Na serwerze
docker exec -it wordpress-CONTAINER_ID wp plugin list --allow-root

# Lub przez Coolify Terminal
```

---

## Limity PHP (domyślne w tym blueprint)

| Parametr | Wartość | Opis |
|----------|---------|------|
| `upload_max_filesize` | 512M | Max rozmiar uploadu |
| `post_max_size` | 512M | Max rozmiar POST |
| `memory_limit` | 512M | Limit pamięci PHP |
| `max_execution_time` | 600s | Timeout wykonania |
| `max_input_vars` | 10000 | Limit zmiennych (MainWP!) |
