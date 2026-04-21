# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-04-21

### Added

- `3505d8ce1`: Initialize Docker setup for WinterCMS runtime.
- `4028e4de7`: Add default Twig filters to support Tulutala multisite.

### Changed

- `fc0c9e8e2`: Improve `PermissionEditor` formwidget (search, grouping, quick actions).
- `b76fa2c3e`: Improve `System EventLog` to log errors with accurate multisite URL context.
- `5ca1e8221`: Update trusted proxy configuration.
- `b12fb1dd4`: Change backend URI from `backend` to `app`.
- `b7d01f3ba`: Update Caddy config to support local subdomains.
- `e42eb196d`: Update Docker Compose setup.
- `c5cfdc2fa`: Update Dockerfile and README.
- `1ec957dcf`: Switch local `storage` to bind-mount instead of Docker volume.
- `c47225e33`: Update `.env.example`.
- `afd0b073c`: Improve local web response performance.

### Fixed

- `1444d9988`: Set default `attempts = 0` for `backend_user_throttle` table.
- `3814fdc0d`: Fix `system_files.attachment_id` column type for PostgreSQL compatibility.
- `f4dd349fa`: Fix `CodeEditor` formwidget error when user preference data is incomplete.

## [1.0.0] - 2026-04-18

### Added

- Initial fork from WinterCMS version 1.2.12 as the base for Tulutala customization.