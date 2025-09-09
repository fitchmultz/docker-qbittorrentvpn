# Repository Guidelines

## Project Structure & Module Organization

- `/Dockerfile` — builds Debian-based image with qBittorrent, libtorrent, and VPN tooling.
- `/docker-compose.yml` — local run template (maps `8282:8080`, adds `NET_ADMIN`).
- `/qbittorrent/` — init/start scripts, iptables rules, default config.
- `/openvpn/` — OpenVPN helper scripts.
- `/.github/workflows/` — CI to build/push to GHCR and scan.
- `/README.md`, `/LICENSE` — usage and license details.

## Build, Test, and Development Commands

- Build image: `docker buildx build --platform linux/amd64 -t ghcr.io/<owner>/docker-qbittorrentvpn:dev .`
- Run (Compose): create `.env`, then `docker compose --env-file .env up -d`.
  - Minimal `.env` example:
    - `CONFIG_PATH=$PWD/config`
    - `DOWNLOADS_PATH=$PWD/downloads`
    - `VPN_ENABLED=yes`
    - `VPN_TYPE=openvpn` (or `wireguard`)
    - `LAN_NETWORK=192.168.1.0/24`
    - `NAME_SERVERS=1.1.1.1,1.0.0.1`
- Logs: `docker logs -f <container>`; WebUI: `https://localhost:8282` (set `ENABLE_SSL=no` to serve HTTP).
- CI publish: pushing to `dev` or `main` builds and tags `ghcr.io/<owner>/docker-qbittorrentvpn:dev|latest`.

## Coding Style & Naming Conventions

- Bash scripts: use `bash`, 2‑space indent, `set -Eeuo pipefail`; prefer lowercase vars and quoted expansions.
- YAML: 2‑space indent; kebab‑case keys; avoid trailing whitespace.
- Dockerfile: group `RUN` chains, pin versions (as done for qBittorrent), minimize layers, keep final image slim.

## Testing Guidelines

- No unit tests. Perform smoke tests:
  - Container starts; logs show “Starting qBittorrent daemon…”.
  - Periodic “Network is up” when VPN is connected.
  - WebUI reachable; files under `/config` and `/downloads` owned by `PUID:PGID`.
- Optional checks: stop VPN to confirm iptables killswitch blocks traffic.

## Commit & Pull Request Guidelines

- Branch from `dev`; open PRs into `dev`. Maintainers promote to `main`.
- Subject: imperative, concise; add scope when helpful (e.g., `Dockerfile: pin qBittorrent 4.6.7`).
- PRs include: rationale, test notes (build/run commands), related issue, and logs/screenshots for behavior changes.
- Never commit secrets, `.env`, or `config/` contents.

## Security & Configuration Tips

- Provide `/dev/net/tun` and `NET_ADMIN` only when required.
- Keep VPN credentials in secrets; redact in issues/PRs.
- Validate `LAN_NETWORK` to avoid WebUI lockout from your local subnet.
