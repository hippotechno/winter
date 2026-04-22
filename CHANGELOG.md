# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-04-22

### Added

- Integrated Redis for caching.

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