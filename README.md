# my_wintercms

Repo này là WinterCMS core fork riêng của bạn.
Mục tiêu vận hành:

- Bạn tự quản lý và sửa code trong repo này.
- Chạy local ổn định bằng Docker (PostgreSQL + HTTPS domain local).
- Build ra Docker image để deploy server bằng `pull` + `up`.

## Quick Start (60 giây)

1. Tạo file env local và chỉnh nhanh các biến chính trong `.env.local`: `APP_URL`, `LOCAL_DOMAIN`, `DB_*`, `APP_KEY`

```bash
cp .env.local.example .env.local
```

2. Map domain local vào hosts (thêm subdomain nếu dùng multisite):

```text
127.0.0.1 tulutala-local.test
127.0.0.1 demo.tulutala-local.test tombo.tulutala-local.test tltl.tulutala-local.test
```

3. Nếu build có private package GitHub thì export token trước khi build:

```bash
export GITHUB_TOKEN=ghp_xxx_or_github_pat_xxx
```

4. Build và chạy local:

```bash
docker compose --env-file .env.local -f docker-compose.local.yml up -d --build
```

5. Chạy setup database lần đầu:

```bash
docker compose --env-file .env.local -f docker-compose.local.yml exec winter-app php artisan winter:up --no-interaction
```

6. Truy cập app: `https://tulutala-local.test` (hoặc `:8443` nếu bạn đổi HTTPS port)

Ghi chú: nếu `APP_KEY` đang trống thì làm theo phần `1) Chạy local` -> `Bước 5` bên dưới để ghi key vào `.env.local`.

## Stack

- WinterCMS (core fork)
- PHP `8.3`
- Twig `1`
- Docker + Docker Compose
- PostgreSQL (local)
- Caddy (reverse proxy HTTPS local)

## File Docker chính

- `docker-compose.local.yml`: chạy local (app + postgres + caddy)
- `docker-compose.runtime.yml`: chạy server/runtime từ image đã build
- `docker/Dockerfile`: image app
- `docker/entrypoint.sh`: entrypoint app
- `docker/Caddyfile`: HTTPS local theo domain
- `docker/build-image.sh`: script build & push image
- `.env.local.example`: biến môi trường local
- `.env.runtime.example`: biến môi trường runtime

## Biến môi trường (quan trọng)

Repo này có 3 lớp env, mỗi lớp dùng cho mục đích khác nhau:

1. `.env`: env của ứng dụng Winter/Laravel khi chạy trực tiếp.
2. `.env.local`: env cho Docker local (`docker-compose.local.yml`).
3. `.env.runtime`: env cho server/runtime (`docker-compose.runtime.yml`).

Nguyên tắc dùng:

- Local dev: ưu tiên `.env.local`.
- Deploy server: dùng `.env.runtime`.
- Không commit file env thật (`.env`, `.env.local`, `.env.runtime`) lên git.

### Tạo env đúng cách

```bash
# local docker
cp .env.local.example .env.local

# runtime server
cp .env.runtime.example .env.runtime

# app env (nếu chưa có)
cp -n .env.example .env
```

### Các biến bắt buộc cho local

Trong `.env.local`, cần kiểm tra tối thiểu:

- `APP_URL`, `LOCAL_DOMAIN`
- `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
- `HTTP_BIND_PORT`, `HTTPS_BIND_PORT`, `DB_EXPOSE_PORT`
- `APP_KEY`

### `GITHUB_TOKEN` dùng thế nào

Build local / build image deploy dùng token để tải private package từ GitHub.

Lưu ý quan trọng:

- Token được truyền qua BuildKit `secret` (ưu tiên), không ghi cứng vào Dockerfile.
- `env_file: .env.local` không tự đẩy biến sang build secret; cần `export` biến ở shell trước khi build.

Cách dùng:

```bash
export GITHUB_TOKEN=ghp_xxx_or_github_pat_xxx
docker compose --env-file .env.local -f docker-compose.local.yml build --no-cache winter-app
```

Build image deploy:

```bash
export GITHUB_TOKEN=ghp_xxx_or_github_pat_xxx
./docker/build-image.sh --tag registry.example.com/team/winter-app:2026.04.20 --platform linux/amd64
```

## 1) Chạy local (khuyên dùng trước)

Domain local mặc định: `https://tulutala-local.test`

### Bước 1: tạo env local

```bash
cp .env.local.example .env.local
```

Sau khi copy, sửa ngay các biến:

- `APP_URL=https://tulutala-local.test`
- `LOCAL_DOMAIN=tulutala-local.test`
- `DB_*` theo database local của bạn
- `APP_KEY` (nếu trống thì tạo ở Bước 5)

### Bước 2: map domain vào hosts (kể cả multisite)

Thêm vào `/etc/hosts` domain gốc và các subdomain bạn dùng:

```text
127.0.0.1 tulutala-local.test
127.0.0.1 demo.tulutala-local.test tombo.tulutala-local.test tltl.tulutala-local.test
```

Nếu bạn dùng DNS local kiểu Valet / dnsmasq wildcard thì không cần liệt kê hết từng subdomain trong hosts.

### Bước 3: kiểm tra port

Local mặc định dùng:

- HTTP: `80`
- HTTPS: `443`
- PostgreSQL host port: `5433`

Nếu bị đụng port với Valet/Nginx/Apache, sửa `.env.local`:

```env
HTTP_BIND_PORT=8081
HTTPS_BIND_PORT=8443
```

Khi đó truy cập bằng `https://tulutala-local.test:8443`.

### Bước 4: build và chạy local

```bash
docker compose --env-file .env.local -f docker-compose.local.yml up -d --build
```

### Bước 5: tạo APP_KEY cho `.env.local` (nếu đang trống)

Không dùng `key:generate --force` ở đây vì lệnh đó ghi vào file `.env` trong container, dễ lệch với `.env.local`.

Dùng lệnh sau để tạo key và ghi thẳng vào `.env.local`:

```bash
APP_KEY_VALUE=$(docker compose --env-file .env.local -f docker-compose.local.yml exec -T winter-app php artisan key:generate --show | tr -d '\r')
awk -v k="$APP_KEY_VALUE" 'BEGIN{done=0} /^APP_KEY=/{print "APP_KEY=" k; done=1; next} {print} END{if(!done) print "APP_KEY=" k}' .env.local > .env.local.tmp && mv .env.local.tmp .env.local
docker compose --env-file .env.local -f docker-compose.local.yml exec winter-app php artisan config:clear
```

### Bước 6: migrate/setup lần đầu

```bash
docker compose --env-file .env.local -f docker-compose.local.yml exec winter-app php artisan winter:up --no-interaction
```

### Bước 7: truy cập

- Nếu dùng port mặc định: `https://tulutala-local.test`
- Nếu đã đổi port HTTPS: `https://tulutala-local.test:8443`

## 2) Trust cert HTTPS local trên macOS

Caddy đang dùng `tls internal`, nên lần đầu có thể báo cert warning.

### Export root cert

```bash
docker compose --env-file .env.local -f docker-compose.local.yml cp caddy:/data/caddy/pki/authorities/local/root.crt ./docker/caddy-local-root.crt
```

### Trust cert vào System Keychain

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./docker/caddy-local-root.crt
```

## 3) Lệnh local thường dùng

### Xem logs toàn stack

```bash
docker compose --env-file .env.local -f docker-compose.local.yml logs -f
```

### Restart app + web

```bash
docker compose --env-file .env.local -f docker-compose.local.yml restart winter-app caddy
```

### Dừng local stack

```bash
docker compose --env-file .env.local -f docker-compose.local.yml down
```

### Xóa cả volume local (mất DB local)

```bash
docker compose --env-file .env.local -f docker-compose.local.yml down -v
```

## 4) Build image để deploy server

Tại repo này:

```bash
./docker/build-image.sh \
  --tag ghcr.io/your-org/winter-app:2026.04.18 \
  --platform linux/amd64 \
  --push
```

Ghi chú:

- Trước khi `--push`, cần login registry, ví dụ GHCR:

```bash
docker login ghcr.io
```

- Username GHCR là username GitHub của bạn.
- Nếu chỉ test build local thì bỏ `--push`.

## 5) Chạy runtime trên server từ image

### Bước 1: tạo env runtime

```bash
cp .env.runtime.example .env.runtime
```

### Bước 2: điền biến bắt buộc trong `.env.runtime`

- `APP_IMAGE`
- `APP_URL`
- `APP_KEY`
- `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`

### Bước 3: chạy

```bash
docker compose -f docker-compose.runtime.yml --env-file .env.runtime up -d
```

### Deploy bản mới

```bash
docker compose -f docker-compose.runtime.yml --env-file .env.runtime pull
docker compose -f docker-compose.runtime.yml --env-file .env.runtime up -d
```

## 6) Troubleshooting nhanh

### Lỗi `ports are not available`

Nguyên nhân: trùng port `80`/`443`.

Cách xử lý:

- Tắt service đang chiếm port (Valet/Nginx/Apache), hoặc
- Đổi `HTTP_BIND_PORT` / `HTTPS_BIND_PORT` trong `.env.local`.

### Lỗi `no such host registry-1.docker.io`

Nguyên nhân: Docker Desktop không resolve DNS tới Docker Hub.

Cách xử lý:

- Kiểm tra kết nối mạng.
- Kiểm tra DNS/proxy trong Docker Desktop.

### Lỗi `Internal Server Error`

Chạy log để biết lỗi thật:

```bash
docker compose --env-file .env.local -f docker-compose.local.yml logs -f winter-app caddy postgres
```

### Lỗi mixed content (HTTPS page nhưng asset HTTP)

Đảm bảo `.env.local`:

```env
APP_URL=https://tulutala-local.test
LOCAL_DOMAIN=tulutala-local.test
```

Sau đó clear cache:

```bash
docker compose --env-file .env.local -f docker-compose.local.yml exec winter-app php artisan config:clear
docker compose --env-file .env.local -f docker-compose.local.yml exec winter-app php artisan cache:clear
```
