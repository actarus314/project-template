# Docker hardening — deployment security

> Reference. Extracted from `claude-code-project-standard.md` §14.
> Security practices validated for **any self-hosted Docker service**. Derived from the `docker-compose-security` skill + the Docker cheatsheet (Security section). Complements `repo-controls.md` (workflow & version pin).

## Absolute rules

| Rule | Detail |
|---|---|
| `version:` in compose | **Never** — a forbidden line in every `docker-compose.yml` |
| `sudo` | Always prefix docker commands (NUC) |
| Volume convention | `/docker/<service>/` for every bind mount on the host |
| Image naming | Full path from the build onward: `ghcr.io/<owner>/<image>:tag` |
| `--privileged` | **Never**, except for a documented, absolute necessity |
| Internal ports | `127.0.0.1:HOST_PORT:CONTAINER_PORT` unless explicit public exposure |
| Network | A dedicated **bridge network** per service/stack |

## Hardening philosophy

`root:root` is **kept** (Docker default). A non-root UID *shared* across containers buys nothing: lateral movement is still possible. The real gain comes from **compose directives**. Real order of impact:

1. Regular kernel + docker-ce updates → blocks CVE escapes.
2. `cap_drop: [ALL]` + `no-new-privileges` → strong, easy to add.
3. `read_only: true` + `tmpfs` → blocks write payloads.
4. `pids_limit` + `mem_limit` → anti host-resource-exhaustion.
5. Non-root UID **distinct per service** → useful only when a different UID per service matters.

## Hardened compose template

```yaml
services:
  backend:
    image: ghcr.io/<owner>/my-image:${IMAGE_TAG:-latest}
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp                      # only write path in the container, in RAM
    cap_drop: [ALL]               # zero Linux capability
    security_opt:
      - no-new-privileges:true    # blocks escalation via setuid/setgid
    pids_limit: 256               # fork bomb protection
    mem_limit: 512m               # memory exhaustion protection
    volumes:
      - /docker/myapp/data:/app/data    # bind mount: stays writable despite read_only
    env_file: .env
    networks: [myapp]
    # pure backend: NO ports: block (reachable through the internal network only)

  frontend:
    image: ghcr.io/<owner>/my-image-frontend:${IMAGE_TAG:-latest}
    restart: unless-stopped
    ports:
      - "127.0.0.1:${PORT:-3000}:8080"
    read_only: true
    tmpfs:                        # nginx-unprivileged writes to these 3 paths
      - /tmp
      - /var/cache/nginx
      - /var/run
    cap_drop: [ALL]
    cap_add: [CHOWN, SETGID, SETUID]   # bare minimum for nginx-unprivileged (init, then drop)
    security_opt:
      - no-new-privileges:true
    pids_limit: 128
    mem_limit: 128m
    depends_on: [backend]
    networks: [myapp]

networks:
  myapp:
    driver: bridge
```

## Key directives

- **`cap_drop: [ALL]`**: strips every Linux capability (the highest-impact one). `cap_add` at the strict minimum, case by case — nginx-unprivileged: `CHOWN`/`SETGID`/`SETUID` (init then drop to non-root); Caddy Alpine (`setcap +ep` on the binary): `NET_BIND_SERVICE` even on a high port.
- **`read_only: true`**: container FS read-only (blocks a dropped payload). **Mounted volumes stay writable** (SQLite/file case). Complement with `tmpfs` for the image's write paths (backend: `/tmp`; nginx-unprivileged: + `/var/cache/nginx` + `/var/run`). Crash on startup → often a missing `tmpfs` path.
- **`no-new-privileges: true`**: blocks escalation via setuid/setgid binaries in the image.
- **`pids_limit` / `mem_limit`**: anti fork-bomb / anti host-OOM. Indicative: backend 256 pids / 512m, light frontend 128 / 128m.
- **`user:` (if used)**: always **numeric UID:GID** (the image has no host `/etc/passwd`). Images with an embedded process manager (PM2, supervisord): **no `user:`**, manage via `chown` of the volume host-side.

## Special cases

- **Pure backend (no exposed port)**: no `ports:` block at all; reachable only via the internal Docker network by the other containers in the stack.
- **SQLite / file bind mount**: `read_only` does not affect mounted volumes → the volume stays writable. Hardened as `root:root`, root writes to the bind mount → **avoids the `repo-controls.md` pitfall** (distroless `:nonroot` UID 65532 → silent write loss, `SQLITE_READONLY_DIRECTORY`). Keep a **write probe at boot** (loud failure + non-zero exit) as defense-in-depth. Under `read_only`, a SQLite writer sets `PRAGMA temp_store=MEMORY` (+ `SQLITE_TMPDIR=/tmp`).
- **Embedded process manager (PM2/supervisord)**: starts as root and manages its own drop → no `user:`.

## The runtime must NOT carry its package manager

**`npm` is a BUILD tool.** Leaving it in the runtime image ships **its entire dependency tree — and its CVEs — along with it**.
A Trivy scan already found **CRITICAL/HIGH** CVEs (`pacote`, `picomatch`, bundled inside `npm`) on an app with **zero production dependencies**. The vulnerabilities didn't come from the code, but from the **tool that was forgotten and left in**.

```dockerfile
RUN npm ci --omit=dev \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /root/.npm
```
Scan **green** after this one line. *(A second-stage `distroless` image produces the same effect — heavier to maintain for an identical gain here.)*

## Before prod

- **CVE scan**: `trivy image <image-name>:<tag>` before every deployment — **and as a CI gate** (`repo-controls.md`), not only by hand: scanning at deployment time is scanning too late.
- **Per-service audit checklist**: `cap_drop:[ALL]` · `read_only:true` · `tmpfs` covering every write · `no-new-privileges:true` · `pids_limit` · `mem_limit` · ports on `127.0.0.1` if internal · dedicated bridge network · no `--privileged` · no `version:`.
