# VPS Infrastructure Reference

> **Status: this repo is being retired.** The user is consolidating everything into a
> new monorepo (backend + frontend + modpack builds side by side). This file documents
> how the VPS, Coolify, Crafty, and the packwiz auto-sync pipeline are wired up today,
> so the same pattern can be reproduced in the new repo. Read this before touching the
> VPS from a fresh session — nothing here is derivable from code alone.

## VPS

- IP: `137.74.160.61`, Ubuntu 24.04.4, 6 vCPU, ~12GB RAM, no swap.
- SSH: key-only (`ubuntu` user). Password auth is disabled on purpose — see "SSH hardening
  gotcha" below before re-enabling anything password-related.
- Store the private key locally (e.g. `~/.ssh/vps_hryvnia_key`) — it was generated and
  handed off during initial setup, it is not recoverable from the server.
- UFW is active: 22 (SSH), 80/443 (HTTP/HTTPS via Traefik), 8000/6001/6002 (Coolify),
  25565 (Minecraft). Everything else is denied by default.
- fail2ban is active on sshd.

## Two workloads share this box

1. **Coolify** — self-hosted Railway-style PaaS. Runs as a docker-compose stack under
   `/data/coolify/`. Dashboard: `http://137.74.160.61:8000` (first registered user
   becomes admin; public registration should be off after that). Use it to deploy the
   new monorepo's backend/frontend: connect the GitHub repo, pick Nixpacks or a
   Dockerfile, it handles build + auto-deploy on push + Let's Encrypt SSL for any domain
   you point at the box.
2. **Crafty Controller** — Minecraft server manager. Runs as a single docker container
   (`docker-compose.yml` in `/opt/crafty/`), **not** in host network mode — it's attached
   to Coolify's `coolify` docker network so Coolify's own Traefik instance can reverse-proxy
   it (see below). Panel: `https://hryvnia.duckdns.org`. Server files live in
   `/opt/crafty/servers/31d91af7-eab2-43ef-8696-628690f9857d/` (symlinked as
   `/opt/crafty/servers/minecraft` for convenience over SFTP).

Both share the same Traefik instance (`coolify-proxy` container) for HTTPS termination —
there's only one process allowed to bind host ports 80/443, so anything new that needs a
public HTTPS domain on this box must go through Coolify's Traefik, not run its own.

## How Crafty got its SSL (pattern to reuse for anything else needing HTTPS)

Coolify's Traefik reads **dynamic file-provider configs** from
`/data/coolify/proxy/dynamic/*.yaml` in addition to Docker-label-based routing. Crafty's
route lives at `/data/coolify/proxy/dynamic/crafty.yaml`: a router for
`Host(\`hryvnia.duckdns.org\`)` on the `letsencrypt` cert resolver, pointing at
`https://crafty:8443` (container DNS name on the `coolify` network) with
`insecureSkipVerify: true` on the serversTransport, since Crafty terminates its own
self-signed TLS internally. This is the template for exposing any non-Coolify-managed
service on this box under its own domain.

## Minecraft server internals

- Forge **1.19.2, build 43.5.0** (the *recommended* build — Crafty's own installer
  defaults to *latest*, which was 43.5.2; don't let it re-drift back to latest on a
  reinstall).
- Java is pinned explicitly to **17** (`/usr/lib/jvm/java-17-openjdk-amd64/bin/java`).
  The Crafty container ships Java 8/11/17/21/25 side by side and `java` on PATH resolves
  to 25 by default, which is incompatible with this Forge/Mixin version and fails with
  `Unsupported class file major version 69`. Never rely on bare `java` in any script here.
- `user_jvm_args.txt` has explicit `-Xms2G -Xmx6G`. Leave this set — do not go back to
  auto-detected heap sizing.
- Startup is **not** the raw Forge-generated `run.sh`. It's a custom `start.sh` in the
  server directory that does a packwiz sync before launching Forge:

  ```bash
  #!/bin/bash
  cd "$(dirname "$(readlink -f "$0")")" || exit 1
  JAVA_BIN=/usr/lib/jvm/java-17-openjdk-amd64/bin/java
  "$JAVA_BIN" -jar packwiz-installer-bootstrap.jar --side server <PACK_TOML_URL>
  exec "$JAVA_BIN" @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.19.2-43.5.0/unix_args.txt nogui
  ```

  Crafty's DB (`servers.execution_command`) is set to `./start.sh` (edited directly via
  `sqlite3`/`python3 sqlite3` inside the container — Crafty has no UI field for "run a
  wrapper script before launch", this was the only way in).

  **The `cd "$(dirname ...)"` line at the top is load-bearing, not decoration.** Crafty
  does not reliably launch custom `execution_command` scripts with the server's own
  directory as cwd. FerriteCore (and probably other mods) write config via *relative*
  paths (`./config/...`); if cwd is wrong, it crashes with
  `Could not initialize class ...FerriteConfig` / `AccessDeniedException` on that file —
  see [FerriteCore#46](https://github.com/malte0811/FerriteCore/issues/46). This bit us
  once already: it worked every time under manual `docker exec -w <dir>` testing (because
  `-w` forced the right cwd) and only broke through Crafty's own launcher. If you're
  debugging "works when I test it manually, breaks from the panel" on this box in the
  future, suspect cwd first.

- Crafty's SQLite DB is at `/opt/crafty/config/db/crafty.sqlite` inside the container
  (`/crafty/app/config/db/crafty.sqlite` from Crafty's own perspective). Editing it live
  while Crafty is running works for quick one-off fixes (server row `execution_command`,
  `executable`) but there's no supported API path for it — treat it as a last resort, and
  expect Crafty's own migrations/reimport logic to occasionally recreate rows from disk
  state (this happened once, mid-session, for no fully diagnosed reason — an
  anti-lockout recovery account got auto-generated at the same time, visible via
  `docker logs crafty` if it ever needs using).

## packwiz / this repo's branch pattern

This repo used a **branch-per-modpack** convention, each independently published to
GitHub Pages and released as a zip:

- `main` — old draft, Forge 1.19.2 / 43.5.0. Never actually published to Pages. Effectively
  dead.
- `spontan` — the pack that was actually live and played (NeoForge 1.21.1). Published at
  `gh-pages/spontan/`, distributed to friends via Prism Launcher pointed at
  `https://hryvnia.github.io/minecraft-modpack-first/spontan/pack.toml`.
- `base` — clean template (this session's work): infra + universal QoL/perf mods only
  (JEI, Jade, Xaero's, AppleSkin, MouseTweaks, FerriteCore, ModernFix, PickUpNotifier,
  packwiz-installer-bootstrap, default-options — plus **Balm and PuzzlesLib**, which are
  hard dependencies of default-options and PickUpNotifier respectively; don't drop them
  again when trimming a future pack, the server won't boot without them). Forge
  1.19.2 / 43.5.0. Published at `gh-pages/base/`, and this is what the VPS server
  currently runs (`start.sh` points at
  `https://hryvnia.github.io/minecraft-modpack-first/base/pack.toml`).

Each branch has `.github/workflows/release.yml` (per-branch, copy-and-rename the whole
file — Actions doesn't parameterize the branch name) that does two things:

1. On push to the branch: `peaceiris/actions-gh-pages` deploys the whole branch content
   into `gh-pages/<branch>/` (`keep_files: true` so branches don't clobber each other).
2. On a tag matching `<branch>-*`: runs `build.sh` (produces `<branch>.zip`, a
   Prism-Launcher-importable instance with `packwiz-installer-bootstrap` wired into
   `PreLaunchCommand`) and attaches it to a GitHub Release.

`build.sh` and `pack.toml` both hardcode the branch name in the Pages URL — when
forking a new build off `base`, update `PACK_NAME` / `PACK_TOML_URL` / `OUTPUT_ZIP` in
`build.sh` and the workflow's branch/tag/`destination_dir` before the first push.

After editing `mods/*.pw.toml`, always run `packwiz refresh` before committing — it
regenerates `index.toml`'s hashes, which is what `packwiz-installer-bootstrap` and the
Prism zip verify against. A stale hash breaks the sync silently-ish (client/server just
won't see the change, or gets a hash-mismatch error).

## Recommended shape for the new monorepo

To keep the "hosting projects + Minecraft builds live side by side" property when this
repo goes away:

- Put modpack builds in a subdirectory of the monorepo (e.g. `minecraft/<build-name>/`)
  rather than as separate git branches — a monorepo doesn't need the branch-per-pack
  trick, and it keeps mods/pack.toml co-versioned with everything else in one history.
- Still publish each build's `pack.toml`/`index.toml` somewhere with a stable public URL
  (GitHub Pages off the monorepo works the same way — `destination_dir` per build
  subfolder; or serve it as a static path via Coolify if you'd rather not depend on
  GitHub Pages at all).
- On the VPS, `start.sh` only needs one line changed (`PACK_TOML_URL`) to point at
  whatever the new build's published URL is — everything else (Java 17 pin, cwd fix,
  memory args) carries over unchanged.
- Re-tag/re-release the same way (`build.sh` + a release workflow) if Prism-importable
  zips are still wanted for friends; otherwise the live `pack.toml` URL alone is enough
  for anyone syncing via packwiz directly.
