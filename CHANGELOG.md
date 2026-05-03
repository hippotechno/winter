# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.6]

### Added

- Add `/var/www/html/.build-info` to runtime images with `IMAGE_VERSION`, `BUILD_DATE`, `VCS_REF`, and the Hippo.Core `Plugin.php` SHA-256 for server-side verification.
- Print version and latest image digests at the end of `scripts/release.sh`.

### Fixed

- Rebuild Composer autoload after image-scoped setup commands so generated vendor classes such as CKFinder connector classes are autoloadable in production images.
- Create WinterCMS runtime cache/storage directories before running artisan setup commands during Docker build.
- Remove the unsupported `--no-progress` option from `composer dump-autoload`.

## [1.0.5]

### Added

- Add `docker/.env.runtime.example` as the runtime image environment template.
- Add `ckfinder:download` to `plugins/hippo/core/setup.yaml` before publishing CKFinder assets.
- Add Docker troubleshooting notes for recreating local containers and PECL Redis download failures.
- Add image-scoped setup support for commands that must run after Docker `composer install`.
- Add local Docker host mapping for `storage.tuimuon.xyz` so PHP cURL and the S3 client can resolve the storage endpoint consistently.

### Changed

- Replace local Docker environment usage from `.env.local` to root `.env`.
- Replace local domain variable usage from `LOCAL_DOMAIN` to `APP_DOMAIN`.
- Update `docker-compose.runtime.yml` to read runtime env from `docker/.env.runtime`.
- Update the local S3 endpoint to use the public `storage.tuimuon.xyz` URL instead of the cluster-only MinIO service hostname.
- Route Docu markdown storage through the configured filesystem disk instead of local `File` operations.
- Update CKFinder S3 backend bootstrapping to pass custom S3 endpoint and path-style options to the AWS client.
- Improve preflight theme asset prompt wording with concrete input examples.
- Simplify preflight output so local setup, image-scoped setup, and theme asset warnings are easier to distinguish.
- Add a 60-second confirmation prompt before building and pushing release images to Harbor.
- Add retry handling for `pecl install redis` in Dockerfile to recover from partial PECL downloads.
- Run image-scoped setup commands during Docker build so vendor-generated files like CKFinder connector code exist in runtime images.
- Refactor preflight setup validation to call `hippo:setup --scope=local` instead of parsing `setup.yaml` separately.
- Update README env, runtime, and local workflow documentation for the simplified `.env` setup.

### Fixed

- Fix Docu markdown files being written to a project-root `fm` folder when `FILESYSTEM_DISK=s3`.
- Fix Docu create/update handlers reporting success when S3 writes fail.
- Fix Docu index cleanup and file listing to work with S3 prefixes safely.
- Fix CKFinder using the default AWS S3 hostname instead of the configured custom S3 endpoint.
- Fix Docker image setup failing when artisan runs before `storage/framework` exists.
- Fix CKFinder connector file being present but not autoloadable after image-scoped setup by regenerating Composer autoload during Docker build.
- Fix CKFinder connector bootstrap by loading the downloaded connector file directly when Composer autoload does not know it yet.

## [1.0.4]

### Added

- Add `scripts/clone_hippo_repos.sh` to bootstrap Hippo plugin and theme source repositories for local image builds.
- Add `config/hippo-repos.yaml` as the plugin/theme repository manifest used by clone and preflight scripts, with optional `required: false` entries.
- Add `scripts/preflight-build.sh` to validate build prerequisites and clone missing plugin/theme source before image builds.
- Add `php artisan hippo:setup` to run plugin/theme `setup.yaml` build commands with `--list`, `--check`, `--only`, `--fresh`, `--force`, and `--no-prompt` support.
- Add `setup.yaml` support for plugin/theme build setup checks, including Hippo.Core vendor publish setup and Tombo theme production asset setup.
- Add `plugins/hippo/core/docs/setup_console.md` documenting the setup console workflow and `setup.yaml` conventions.
- Add `composer.lock` to lock framework and vendor dependencies for reproducible image builds.

### Changed

- Remove Hippo plugin/theme package repositories from root `composer.json`; plugin and theme source is now copied from local `plugins/` and `themes/`.
- Build image config files from `config/hippo/core/*.example.php` instead of copying local-only config files.
- Make `GITHUB_TOKEN` optional for build and release scripts.
- Remove the `.vite-packages.production` workflow from build and release scripts.
- Update preflight to check `setup.yaml` paths, prompt to run `php artisan hippo:setup --phase=build` when setup checks are missing, and continue build when the user chooses to pass warnings.
- Update Tombo theme setup to compile production assets through Winter Vite instead of running npm install inside the theme workspace.
- Refactor README Quick Start for fresh framework pulls, including plugin/theme clone, root dependency install, and setup command flow; move detailed sections under advanced headings.
- Simplify local environment handling to root `.env`, move runtime environment template to `docker/.env.runtime.example`, and update Docker Compose usage accordingly.

## [1.0.3]

### Added

- Add `scripts/vite-compile-production.sh` to compile Vite assets in production mode from a configurable package list.
- Add `.vite-packages.production.example` as the template for selecting Vite packages to compile.
- Add interactive package selection before compile (`all` or indexes like `1,2,5,6`) with 60-second timeout defaulting to all packages.

### Changed

- Update `scripts/release.sh` to run Vite production compile before image build (with `--skip-vite-compile` support).
- Move release script to `scripts/release.sh` and remove root-level `release.sh`.
- Update `docker/build-image.sh` to run Vite production compile before image build (with `--skip-vite-compile` support).
- Migrate `docker/build-image.sh` from single-arch `docker build` to `docker buildx build` with multi-platform support.
- Improve build scripts to bootstrap/use named Buildx builders and inspect pushed manifests.
- Optimize Docker build context and runtime artifact pruning (`.dockerignore` + Dockerfile prune step) to reduce image size.
- Add `INCLUDE_SEED_ASSETS` build strategy with plugin seed convention `plugins/<author>/<plugin>/seed`: keep seed data for local builds, exclude by default in deploy builds (with `--include-seed-assets` override).
- Ensure Redis PHP driver is present in runtime image and add build-time fail-fast check when `redis` module is missing.
- Update README with a dedicated **Build Image (Deploy)** section and Vite compile workflow documentation.

## [1.0.2] - 2026-04-22

### Added

- Integrated Redis for caching locally.

### Updated

- Improved S3 configuration handling (only applied when S3 disk is enabled).

## [1.0.1] - 2026-04-21

### Added

- Initialize Docker setup for WinterCMS runtime.
- Add default Twig filters to support Tulutala multisite.

### Changed

- Improve `PermissionEditor` formwidget (search, grouping, quick actions).
- Improve `System EventLog` to log errors with accurate multisite URL context.
- Update trusted proxy configuration.
- Change backend URI from `backend` to `app`.
- Update Caddy config to support local subdomains.
- Update Docker Compose setup.
- Update Dockerfile and README.
- Switch local `storage` to bind-mount instead of Docker volume.
- Update `.env.example`.
- Improve local web response performance.

### Fixed

- Set default `attempts = 0` for `backend_user_throttle` table.
- Fix `system_files.attachment_id` column type for PostgreSQL compatibility.
- Fix `CodeEditor` formwidget error when user preference data is incomplete.

## [1.0.0] - 2026-04-18

### Added

- Initial fork from WinterCMS version 1.2.12 as the base for Tulutala customization.
