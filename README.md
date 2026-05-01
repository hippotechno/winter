# my_wintercms

Repo này là WinterCMS core fork riêng của bạn.
Mục tiêu vận hành:

- Bạn tự quản lý và sửa code trong repo này.
- Chạy local ổn định bằng Docker (PostgreSQL + HTTPS domain local).
- Build ra Docker image để deploy server bằng `pull` + `up`.

## Quick Start (60 giây)

Luồng này dành cho người lần đầu pull bộ khung về và muốn chạy local nhanh nhất.

### 1. Chuẩn bị env

```bash
cp -n .env.example .env
```

Chỉnh nhanh trong `.env` nếu cần:

- `APP_URL`
- `APP_DOMAIN`
- `DB_*`
- `APP_KEY` nếu đã có key sẵn

### 2. Pull plugin/theme source

Root `composer.json` không còn pull plugin/theme repo. Source plugin/theme được clone theo manifest:

```bash
./scripts/clone_hippo_repos.sh
```

Manifest nằm ở:

```text
config/hippo-repos.yaml
```

### 3. Cài dependency root

Local stack đang bind-mount source từ máy vào container, nên fresh clone cần có `vendor/` và `node_modules/` ở workspace local.

```bash
composer install
npm install
```

Không chạy `npm install` trong từng theme. NPM dependency quản lý ở root project.

### 4. Chạy setup plugin/theme

```bash
php artisan hippo:setup --phase=build
```

Lệnh này đọc `setup.yaml` trong plugin/theme, chạy các bước setup cần thiết, và tự skip command nào đã đủ `checks`.

### 5. Map domain local vào hosts

Thêm domain local vào `/etc/hosts`:

```text
127.0.0.1 tulutala-local.test
127.0.0.1 demo.tulutala-local.test tombo.tulutala-local.test tltl.tulutala-local.test
```

### 6. Build và chạy local

```bash
docker compose -f docker-compose.local.yml up -d --build
```

### 7. Chạy setup database lần đầu

```bash
docker compose -f docker-compose.local.yml exec winter-app php artisan winter:up --no-interaction
```

### 8. Truy cập app

```text
https://tulutala-local.test
```

Nếu đổi HTTPS port thì dùng:

```text
https://tulutala-local.test:8443
```

Ghi chú: nếu `APP_KEY` đang trống thì làm theo phần `Nâng cao: Chạy local` -> `Bước 5` bên dưới để ghi key vào `.env`.

## Stack

- WinterCMS (core fork)
- PHP `8.3`
- Twig `1`
- Docker + Docker Compose
- PostgreSQL (local)
- Redis (cache/session/queue)
- Caddy (reverse proxy HTTPS local)

## File Docker chính

- `docker-compose.local.yml`: chạy local (app + postgres + redis + caddy)
- `docker-compose.runtime.yml`: chạy server/runtime từ image đã build (chỉ app)
- `docker/Dockerfile`: image app
- `docker/entrypoint.sh`: entrypoint app
- `docker/Caddyfile`: HTTPS local theo domain
- `docker/build-image.sh`: script build & push image
- `scripts/release.sh`: script release image lên Harbor theo version
- `.env.example`: biến môi trường local/app
- `docker/.env.runtime.example`: biến môi trường runtime

## Nâng Cao: Biến Môi Trường

Repo này có 2 lớp env, mỗi lớp dùng cho mục đích khác nhau:

1. `.env`: env local/app, dùng cho artisan local và Docker local (`docker-compose.local.yml`).
2. `docker/.env.runtime`: env server/runtime, dùng khi pull image về chạy bằng `docker-compose.runtime.yml`.

Nguyên tắc dùng:

- Local dev: dùng `.env`.
- Deploy server: dùng `docker/.env.runtime`.
- Không commit file env thật (`.env`, `docker/.env.runtime`) lên git.

### Tạo env đúng cách

```bash
# local docker
cp .env.example .env

# runtime server
cp docker/.env.runtime.example docker/.env.runtime
```

### Các biến bắt buộc cho local

Trong `.env`, cần kiểm tra tối thiểu:

- `APP_URL`, `APP_DOMAIN`
- `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
- `REDIS_HOST`, `REDIS_PORT`
- `HTTP_BIND_PORT`, `HTTPS_BIND_PORT`, `DB_EXPOSE_PORT`
- `APP_KEY`

Nếu muốn bật Redis cho cache/session/queue, đặt trong `.env` hoặc `docker/.env.runtime`:

```env
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
REDIS_HOST=redis
REDIS_PORT=6379
```

### `GITHUB_TOKEN` dùng thế nào

Build local / build image deploy có thể truyền token cho Composer khi tải package từ GitHub.
Token hiện là tùy chọn, chỉ cần khi gặp rate-limit hoặc package GitHub private.

Lưu ý quan trọng:

- Token được truyền qua BuildKit `secret` (ưu tiên), không ghi cứng vào Dockerfile.
- `env_file: .env` không tự đẩy biến sang build secret; cần `export` biến ở shell trước khi build.

Cách dùng:

```bash
export GITHUB_TOKEN=ghp_xxx_or_github_pat_xxx
docker compose -f docker-compose.local.yml build --no-cache winter-app
```

Build image deploy nếu cần token:

```bash
export GITHUB_TOKEN=ghp_xxx_or_github_pat_xxx
./docker/build-image.sh --tag registry.example.com/team/winter-app:2026.04.20 --platform linux/amd64
```

## Nâng Cao: Chạy Local

Domain local mặc định: `https://tulutala-local.test`

### Bước 1: tạo env

```bash
cp .env.example .env
```

Sau khi copy, sửa ngay các biến:

- `APP_URL=https://tulutala-local.test`
- `APP_DOMAIN=tulutala-local.test`
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

Nếu bị đụng port với Valet/Nginx/Apache, sửa `.env`:

```env
HTTP_BIND_PORT=8081
HTTPS_BIND_PORT=8443
```

Khi đó truy cập bằng `https://tulutala-local.test:8443`.

### Bước 4: build và chạy local

```bash
docker compose -f docker-compose.local.yml up -d --build
```

### Bước 5: tạo APP_KEY cho `.env` (nếu đang trống)

Không dùng `key:generate --force` ở đây vì lệnh đó ghi vào file `.env` trong container, dễ lệch với `.env`.

Dùng lệnh sau để tạo key và ghi thẳng vào `.env`:

```bash
APP_KEY_VALUE=$(docker compose -f docker-compose.local.yml exec -T winter-app php artisan key:generate --show | tr -d '\r')
awk -v k="$APP_KEY_VALUE" 'BEGIN{done=0} /^APP_KEY=/{print "APP_KEY=" k; done=1; next} {print} END{if(!done) print "APP_KEY=" k}' .env > .env.tmp && mv .env.tmp .env
docker compose -f docker-compose.local.yml exec winter-app php artisan config:clear
```

### Bước 6: migrate/setup lần đầu

```bash
docker compose -f docker-compose.local.yml exec winter-app php artisan winter:up --no-interaction
```

### Bước 7: truy cập

- Nếu dùng port mặc định: `https://tulutala-local.test`
- Nếu đã đổi port HTTPS: `https://tulutala-local.test:8443`

## Nâng Cao: Trust Cert HTTPS Local Trên macOS

Caddy đang dùng `tls internal`, nên lần đầu có thể báo cert warning.

### Export root cert

```bash
docker compose -f docker-compose.local.yml cp caddy:/data/caddy/pki/authorities/local/root.crt ./docker/caddy-local-root.crt
```

### Trust cert vào System Keychain

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./docker/caddy-local-root.crt
```

## Nâng Cao: Lệnh Local Thường Dùng

### Xem logs toàn stack

```bash
docker compose -f docker-compose.local.yml logs -f
```

### Restart app + web

```bash
docker compose -f docker-compose.local.yml restart winter-app caddy
```

### Dừng local stack

```bash
docker compose -f docker-compose.local.yml down
```

### Xóa cả volume local (mất DB local)

```bash
docker compose -f docker-compose.local.yml down -v
```

## Nâng Cao: Build Image (Deploy)

Section này chỉ dành cho việc build image deploy.

### 4.1) Chuẩn bị plugin/theme source

Danh sách repo plugin/theme nằm ở:

```text
config/hippo-repos.yaml
```

Format manifest:

```yaml
plugins:
    - folder: core
      repo: git@github.com:hippotechno/wn-core-plugin.git
      branch: dev

themes:
    - folder: wn-tombo-theme
      repo: git@github.com:hippotechno/wn-tombo-theme.git
      branch: main
```

Nếu máy build chưa có source plugin/theme trong `plugins/` và `themes/`, clone trước bằng script:

```bash
./scripts/clone_hippo_repos.sh
```

Image hiện tại copy trực tiếp `plugins/` và `themes/` từ workspace, root `composer.json` không còn pull các repo Hippo này.
Build/release script sẽ chạy `scripts/preflight-build.sh` trước khi build. Nếu thiếu plugin/theme source theo `config/hippo-repos.yaml`, preflight sẽ tự gọi `scripts/clone_hippo_repos.sh` rồi kiểm tra lại.

Flow build hiện tại là snapshot từ workspace local:

```text
local source -> preflight -> optional setup -> docker build copy source -> runtime image
```

Dockerfile không tự pull plugin/theme repo và không tự chạy setup bên trong image. Mọi thứ cần sinh ra trước khi copy vào image phải có sẵn trong workspace local.

Build contract:

- `composer.json` và `composer.lock` phải tồn tại và hợp lệ.
- `plugins/hippo/*` và `themes/*` cần cho image phải có source đầy đủ trước khi Docker copy.
- Repo trong `config/hippo-repos.yaml` mặc định là bắt buộc. Nếu đặt `required: false`, clone script vẫn biết repo đó, nhưng preflight không fail khi repo đó thiếu hoặc chưa đủ source. Dùng cho repo đang thử nghiệm, docs-only, hoặc chưa cần vào runtime image.
- `config/hippo/core/config.php` và `config/hippo/core/ckfinder.php` là file local-only; image tạo chúng từ `*.example.php`.
- Theme dùng Vite nên có production assets sẵn trong `assets/dist` hoặc `dist` trước khi build image. Nếu thiếu, `scripts/preflight-build.sh` sẽ warning; khi chạy qua build/release script, prompt sẽ hiện danh sách theme thiếu assets, cho phép nhấn Enter để tiếp tục tất cả, nhập số để xác nhận từng theme, hoặc tự tiếp tục sau 60 giây.
- Plugin/theme có `setup.yaml` nên khai báo `checks` cho từng command. Preflight sẽ kiểm tra các path này để biết setup đã tạo đủ file/folder cần thiết hay chưa. Nếu thiếu checks, preflight sẽ hỏi có muốn chạy `php artisan hippo:setup --phase=build` trước khi build image không.

Ví dụ `setup.yaml`:

```yaml
version: 1
name: Hippo.Core

build:
    commands:
        - id: publish-ckfinder-assets
          title: Publish CKFinder assets
          run: php artisan vendor:publish --tag=ckfinder-assets --force
          checks:
              - path: plugins/hippo/core/assets/js/vendor/ckfinder
```

Chạy setup:

```bash
php artisan hippo:setup --list
php artisan hippo:setup --check
php artisan hippo:setup --phase=build
```

Nếu `--check` thấy thiếu path, command sẽ hỏi có muốn chạy setup ngay không. Dùng `--no-prompt` cho CI hoặc script không muốn hỏi:

```bash
php artisan hippo:setup --check --no-prompt
```

Chạy một command cụ thể:

```bash
php artisan hippo:setup --only=publish-ckfinder-assets
```

Ép chạy lại command dù `checks` đã đủ:

```bash
php artisan hippo:setup --phase=build --fresh
```

Lưu ý với theme dùng Vite/npm workspace:

- Không chạy `npm install`, `npm update`, hoặc `npm ci` bên trong từng theme `setup.yaml`.
- NPM dependency là layer chung của root project, xử lý ở root khi thật sự cần.
- Theme setup chỉ nên compile assets, ví dụ `php artisan vite:compile -p theme-wn-tombo-theme --production`.
- Nếu gặp lỗi `Cannot find module '../lightningcss.darwin-arm64.node'`, kiểm tra lại root `node_modules` và không sửa bằng cách install riêng trong theme.

### 4.2) Build image bằng script chung

```bash
./docker/build-image.sh \
  --tag ghcr.io/your-org/winter-app:2026.04.18 \
  --platforms linux/amd64 \
  --push
```

Tùy chọn:

- Multi-platform: `--platforms linux/amd64,linux/arm64`
- Giữ seed assets trong image: `--include-seed-assets`

Quy ước seed theo plugin:

- Mỗi plugin đặt seed data vào folder cố định: `plugins/<author>/<plugin>/seed`
- Ví dụ: `plugins/hippo/core/seed`, `plugins/hippo/servit/seed`

Mặc định script build/release sẽ loại toàn bộ folder `seed` theo pattern trên khỏi runtime image.
Lý do: server runtime không cần seed data nếu dữ liệu đã migrate trước đó.
Local build (`docker-compose.local.yml`) vẫn giữ seed assets.

### 4.3) Release lên Harbor (project `library/tulutala`)

Repo Harbor:

- `harbor.tuimuon.xyz/library/tulutala`

Đăng nhập:

```bash
docker login harbor.tuimuon.xyz
```

Tạo tag release:

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

Build + push release:

```bash
./scripts/release.sh 1.0.0
```

Tùy chọn:

- Không push `latest`: `--no-latest`
- Chỉ build 1 platform: `--platforms linux/amd64`
- Giữ seed assets trong image: `--include-seed-assets`

Ví dụ:

```bash
./scripts/release.sh 1.0.1 --no-latest
./scripts/release.sh 1.1.0 --platforms linux/amd64
./scripts/release.sh 1.1.1 --platforms linux/amd64,linux/arm64
```

Lưu ý:

- Image dùng base Linux (`php:8.3-apache-bookworm`), không build Windows container.
- Trước khi push GHCR: `docker login ghcr.io`.

## Nâng Cao: Chạy Runtime Trên Server Từ Image

### Bước 1: tạo env runtime

```bash
cp docker/.env.runtime.example docker/.env.runtime
```

### Bước 2: điền biến bắt buộc trong `docker/.env.runtime`

- `APP_IMAGE`
- `APP_URL`
- `APP_KEY`
- `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`

### Bước 3: chạy

```bash
docker compose --env-file docker/.env.runtime -f docker-compose.runtime.yml up -d
```

### Deploy bản mới

```bash
docker compose --env-file docker/.env.runtime -f docker-compose.runtime.yml pull
docker compose --env-file docker/.env.runtime -f docker-compose.runtime.yml up -d
```

## Nâng Cao: Troubleshooting Nhanh

### Lỗi `ports are not available`

Nguyên nhân: trùng port `80`/`443`.

Cách xử lý:

- Tắt service đang chiếm port (Valet/Nginx/Apache), hoặc
- Đổi `HTTP_BIND_PORT` / `HTTPS_BIND_PORT` trong `.env`.

### Recreate toàn bộ local container

Khi đổi Dockerfile, compose, env, hoặc container chạy sai trạng thái, recreate toàn bộ local stack:

```bash
docker compose -f docker-compose.local.yml up -d --build --force-recreate
```

Nếu muốn dừng container cũ trước rồi tạo lại:

```bash
docker compose -f docker-compose.local.yml down
docker compose -f docker-compose.local.yml up -d --build --force-recreate
```

Nếu muốn xóa luôn volume local, gồm database/cache, dùng `down -v`.

Lưu ý: lệnh này sẽ mất database local.

```bash
docker compose -f docker-compose.local.yml down -v
docker compose -f docker-compose.local.yml up -d --build --force-recreate
```

### Lỗi `no such host registry-1.docker.io`

Nguyên nhân: Docker Desktop không resolve DNS tới Docker Hub.

Cách xử lý:

- Kiểm tra kết nối mạng.
- Kiểm tra DNS/network trong Docker Desktop.

### Build fail ở `pecl install redis`

Nếu thấy lỗi tương tự:

```text
ERROR: unable to unpack /tmp/pear/download/redis-*.tgz
```

Nguyên nhân thường là PECL tải gói bị lỗi giữa chừng. Dockerfile đã có retry cho bước này, nhưng nếu vẫn fail thì prune cache rồi build lại:

```bash
docker buildx prune -f
docker compose -f docker-compose.local.yml build --no-cache winter-app
docker compose -f docker-compose.local.yml up -d --force-recreate
```

Lưu ý: nếu build fail nhưng container vẫn `Created` hoặc `Started`, Docker có thể đang dùng image cũ. Cần nhìn dòng build cuối cùng để xác nhận image mới có build thành công hay không.

### Artisan trong container báo `git: not found`

Một số command dev, ví dụ `winter:util git pull`, cần `git` bên trong container.

Local image đã cài `git` và `openssh-client`. Nếu vẫn gặp lỗi, rebuild lại local image:

```bash
docker compose -f docker-compose.local.yml build --no-cache winter-app
docker compose -f docker-compose.local.yml up -d --force-recreate
```

### Lỗi `Internal Server Error`

Chạy log để biết lỗi thật:

```bash
docker compose -f docker-compose.local.yml logs -f winter-app caddy postgres
```

### Lỗi mixed content (HTTPS page nhưng asset HTTP)

Đảm bảo `.env`:

```env
APP_URL=https://tulutala-local.test
APP_DOMAIN=tulutala-local.test
```

Sau đó clear cache:

```bash
docker compose -f docker-compose.local.yml exec winter-app php artisan config:clear
docker compose -f docker-compose.local.yml exec winter-app php artisan cache:clear
```

### Docker local chậm hơn Valet

Nếu cùng data/code mà Docker chậm hơn Valet, thường do:

- Xdebug đang bật cho mọi request.
- Bind mount code trên Docker Desktop (macOS) chậm I/O hơn chạy native.

Repo này đã đặt local theo hướng nhanh hơn:

- `XDEBUG_MODE=off`
- `XDEBUG_START_WITH_REQUEST=trigger`
- Bind mount app dùng `:cached`

Khi cần debug lại, chỉ cần sửa `.env`:

```env
XDEBUG_MODE=debug,develop
XDEBUG_START_WITH_REQUEST=trigger
```

Rồi restart app:

```bash
docker compose -f docker-compose.local.yml restart winter-app
```
