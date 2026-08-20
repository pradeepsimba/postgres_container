#!/bin/bash
# ---------------------------------------------------------------------------
# Host-adaptive deploy.
#
# Postgres and Docker resource limits have to match the machine they run on.
# Hardcoding them breaks portability in two different ways:
#   * cpus > host CPU count  -> Docker REFUSES to create the container
#     ("range of CPUs is from 0.01 to 4.00, as there are only 4 CPUs available")
#   * memory / shared_buffers > host RAM -> accepted silently, then Postgres
#     fails to start or the OOM killer takes it.
#
# So this script measures the host, derives a profile, exports it, and lets
# docker-compose.yml interpolate it. Run it on any server, unchanged.
#
# Pin any value by exporting it first, e.g.:
#     DB_CPUS=2 PG_SHARED_BUFFERS=512MB sudo -E bash deploy.sh
#
# postgres.conf is NOT rewritten. The size-dependent settings are injected as
# `-c` flags in docker-compose.yml, which override the config file, so
# postgres.conf stays the hand-maintained base for everything else.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

# ── Measure the host ───────────────────────────────────────────────────────
if [ ! -r /proc/meminfo ]; then
    echo "ERROR: /proc/meminfo unreadable - this script targets Linux hosts." >&2
    exit 1
fi
HOST_CPUS=$(nproc)
HOST_MEM_MB=$(( $(awk '/^MemTotal:/ {print $2}' /proc/meminfo) / 1024 ))

if [ "$HOST_CPUS" -lt 1 ] || [ "$HOST_MEM_MB" -lt 512 ]; then
    echo "ERROR: detected ${HOST_CPUS} CPU / ${HOST_MEM_MB}MB RAM - too small." >&2
    exit 1
fi

# ── Derive the profile (all overridable from the environment) ──────────────
# Container CPU cap: leave half a core for the OS unless there is only one.
# awk (not bash) because this is fractional and must never exceed HOST_CPUS.
: "${DB_CPUS:=$(awk -v c="$HOST_CPUS" 'BEGIN{printf "%.2f", (c>1 ? c-0.5 : 1)}')}"

# Container memory cap: 75% of RAM, so the host keeps room for the kernel,
# page cache and anything else running.
: "${DB_MEMORY_MB:=$(( HOST_MEM_MB * 75 / 100 ))}"

# Postgres shared_buffers: the standard 25%-of-RAM starting point.
: "${PG_SHARED_BUFFERS_MB:=$(( HOST_MEM_MB * 25 / 100 ))}"

# /dev/shm must be at least shared_buffers (parallel workers also use it);
# Docker's 64MB default is far too small. +25% headroom.
: "${DB_SHM_MB:=$(( PG_SHARED_BUFFERS_MB * 125 / 100 ))}"

# Planner hint for "how much of this table is probably cached" - not an
# allocation, so it may safely exceed shared_buffers.
: "${PG_EFFECTIVE_CACHE_MB:=$(( HOST_MEM_MB * 60 / 100 ))}"

# Per-sort/hash memory, and it is per operation per connection - the classic
# way to OOM a box. (RAM - shared_buffers) * 25% / max_connections, clamped.
_maxconn=$(awk '/^ *max_connections/ {print $3}' postgres.conf 2>/dev/null | tail -1)
_maxconn=${_maxconn:-100}
: "${PG_WORK_MEM_MB:=$(( (HOST_MEM_MB - PG_SHARED_BUFFERS_MB) * 25 / 100 / _maxconn ))}"
[ "$PG_WORK_MEM_MB" -lt 4 ]  && PG_WORK_MEM_MB=4
[ "$PG_WORK_MEM_MB" -gt 64 ] && PG_WORK_MEM_MB=64

# Maintenance (VACUUM/CREATE INDEX): RAM/16, capped at 2GB.
: "${PG_MAINT_WORK_MEM_MB:=$(( HOST_MEM_MB / 16 ))}"
[ "$PG_MAINT_WORK_MEM_MB" -lt 64 ]   && PG_MAINT_WORK_MEM_MB=64
[ "$PG_MAINT_WORK_MEM_MB" -gt 2048 ] && PG_MAINT_WORK_MEM_MB=2048

# Parallelism must track CPUs: more workers than cores is pure contention.
: "${PG_MAX_WORKERS:=$HOST_CPUS}"
: "${PG_MAX_PARALLEL:=$HOST_CPUS}"
: "${PG_PARALLEL_PER_GATHER:=$(( HOST_CPUS / 2 > 0 ? HOST_CPUS / 2 : 1 ))}"
: "${PG_PARALLEL_MAINT:=$(( HOST_CPUS / 2 > 0 ? HOST_CPUS / 2 : 1 ))}"
_av=$(( HOST_CPUS / 2 ))
[ "$_av" -lt 2 ] && _av=2
[ "$_av" -gt 8 ] && _av=8
: "${PG_AUTOVACUUM_WORKERS:=$_av}"

# ── Guard rails ────────────────────────────────────────────────────────────
# The one failure Docker rejects outright - catch it here with a clear message
# rather than a daemon error, in case someone pinned DB_CPUS too high.
if awk -v d="$DB_CPUS" -v h="$HOST_CPUS" 'BEGIN{exit !(d>h)}'; then
    echo "ERROR: DB_CPUS=$DB_CPUS exceeds the host's $HOST_CPUS CPUs." >&2
    echo "       Docker would refuse to create the container." >&2
    exit 1
fi
if [ $(( DB_SHM_MB + 256 )) -gt "$DB_MEMORY_MB" ]; then
    echo "WARN: shm ${DB_SHM_MB}MB is close to the ${DB_MEMORY_MB}MB memory cap;" >&2
    echo "      shared memory counts toward it. Lowering PG_SHARED_BUFFERS_MB." >&2
fi

# -- Publish for docker-compose.yml ----------------------------------------
# EXPORTED, not written to .env. Compose interpolates ${VAR} from the process
# environment as well as from .env, and the environment wins - so this leaves
# .env alone for POSTGRES_PASSWORD (see README) instead of overwriting the one
# file that holds a secret.
DB_MEMORY="${DB_MEMORY_MB}M"
DB_SHM="${DB_SHM_MB}m"
PG_SHARED_BUFFERS="${PG_SHARED_BUFFERS_MB}MB"
PG_EFFECTIVE_CACHE="${PG_EFFECTIVE_CACHE_MB}MB"
PG_WORK_MEM="${PG_WORK_MEM_MB}MB"
PG_MAINT_WORK_MEM="${PG_MAINT_WORK_MEM_MB}MB"
export DB_CPUS DB_MEMORY DB_SHM
export PG_SHARED_BUFFERS PG_EFFECTIVE_CACHE PG_WORK_MEM PG_MAINT_WORK_MEM
export PG_MAX_WORKERS PG_MAX_PARALLEL PG_PARALLEL_PER_GATHER
export PG_PARALLEL_MAINT PG_AUTOVACUUM_WORKERS

printf '%s\n' \
  "--------------------------------------------------------------" \
  " Host        : ${HOST_CPUS} CPU / ${HOST_MEM_MB} MB RAM" \
  " Container   : cpus=${DB_CPUS}  memory=${DB_MEMORY_MB}M  shm=${DB_SHM_MB}m" \
  " Postgres    : shared_buffers=${PG_SHARED_BUFFERS_MB}MB" \
  "               effective_cache_size=${PG_EFFECTIVE_CACHE_MB}MB" \
  "               work_mem=${PG_WORK_MEM_MB}MB (x ${_maxconn} conns)" \
  "               maintenance_work_mem=${PG_MAINT_WORK_MEM_MB}MB" \
  " Parallelism : workers=${PG_MAX_WORKERS} parallel=${PG_MAX_PARALLEL}" \
  "               per_gather=${PG_PARALLEL_PER_GATHER} autovacuum=${PG_AUTOVACUUM_WORKERS}" \
  "--------------------------------------------------------------"

docker compose up -d
docker compose logs -f --tail=20
