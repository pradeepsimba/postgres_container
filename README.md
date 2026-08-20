# postgres_container

PostgreSQL for the algo stack, sized **automatically to whatever host it runs on**.

```bash
sudo bash deploy.sh          # detect host -> tune -> start -> follow logs
sudo bash remove.sh          # stop (keeps ./data)
sudo bash clear.sh           # stop and DELETE all data (asks first)
```

## Why deploy.sh tunes at runtime

Resource limits have to match the machine. Hardcoding them fails two ways:

* `cpus` **greater than the host's CPU count** makes Docker refuse to create the
  container outright:
  `range of CPUs is from 0.01 to 4.00, as there are only 4 CPUs available`
* `memory` / `shm_size` / `shared_buffers` above real RAM are accepted
  **silently**, then surface later as a Postgres that won't start or an OOM kill.

So `deploy.sh` reads `nproc` and `/proc/meminfo`, derives a profile, exports it,
and `docker-compose.yml` interpolates it. The same checkout works on a 1-core VM
and a 32-core server with no edits.

| Derived | Rule |
|---|---|
| `cpus` | host CPUs − 0.5 (leaves headroom; never exceeds the host) |
| `memory` | 75% of RAM |
| `shm_size` | shared_buffers × 1.25 (Docker's 64MB default is far too small) |
| `shared_buffers` | 25% of RAM |
| `effective_cache_size` | 60% of RAM |
| `work_mem` | (RAM − shared_buffers) × 25% ÷ max_connections, clamped 4–64MB |
| `maintenance_work_mem` | RAM ÷ 16, capped 2GB |
| `max_worker_processes`, `max_parallel_workers` | host CPUs |
| `..._per_gather`, `..._maintenance_workers` | host CPUs ÷ 2 |
| `autovacuum_max_workers` | host CPUs ÷ 2, clamped 2–8 |

Pin any value by exporting it first (`sudo -E` passes it through):

```bash
DB_CPUS=2 PG_SHARED_BUFFERS_MB=512 sudo -E bash deploy.sh
```

## How the settings reach Postgres

`postgres.conf` stays the hand-maintained base. Only the **size-dependent**
settings are injected, as `-c` flags in `docker-compose.yml`, because
command-line flags override the config file. That means:

* the `shared_buffers` / `effective_cache_size` / `work_mem` /
  `maintenance_work_mem` / parallelism values **in `postgres.conf` are inert** —
  the `-c` flags win. Everything else in that file applies normally.
* `deploy.sh` never rewrites `postgres.conf`.

Running `docker compose up -d` **directly** (not via `deploy.sh`) skips detection
and falls back to the conservative defaults baked into `docker-compose.yml`
(~2 cores / 4GB). Use `deploy.sh` to get host-tuned values.

## Secrets

`POSTGRES_PASSWORD` is currently set inline in `docker-compose.yml`. `deploy.sh`
deliberately does **not** write `.env`, so that file is free to hold the password
as an override — note there is no `.gitignore` in this repo yet, so anything you
put in `.env` is not automatically excluded from git.
