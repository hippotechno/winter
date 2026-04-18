# Docker cho repo WinterCMS core

## 1) Local test với PostgreSQL (khuyên dùng trước)

1. Tạo file env local:

```bash
cp .env.local.example .env.local
```

2. Tạo `APP_KEY` rồi dán vào `.env.local`:

```bash
php -r 'echo "base64:".base64_encode(random_bytes(32)).PHP_EOL;'
```

3. Build và chạy local (Compose sẽ tự build image):

```bash
docker compose --env-file .env.local -f docker-compose.local.yml up -d --build
```

4. Chạy migrate / setup lần đầu:

```bash
docker compose --env-file .env.local -f docker-compose.local.yml exec winter-app php artisan winter:up --no-interaction
```

5. Truy cập app:

- `http://localhost:8081`

Lệnh hữu ích:

```bash
# Xem log app
docker compose --env-file .env.local -f docker-compose.local.yml logs -f winter-app

# Dừng hệ thống local
docker compose --env-file .env.local -f docker-compose.local.yml down

# Reset sạch cả database local
docker compose --env-file .env.local -f docker-compose.local.yml down -v
```

## 2) Build image để deploy server

```bash
./docker/build-image.sh \
  --tag ghcr.io/your-org/winter-app:2026.04.18 \
  --platform linux/amd64 \
  --push
```

Nếu chỉ test local thì không cần `--push`.

## 3) Chạy server bằng image đã build

```bash
cp .env.runtime.example .env.runtime
```

Sửa `.env.runtime` với `APP_IMAGE`, `APP_KEY`, `DB_*`.

```bash
docker compose -f docker-compose.runtime.yml --env-file .env.runtime up -d
```

## 4) Deploy bản mới

```bash
docker compose -f docker-compose.runtime.yml --env-file .env.runtime pull
docker compose -f docker-compose.runtime.yml --env-file .env.runtime up -d
```
