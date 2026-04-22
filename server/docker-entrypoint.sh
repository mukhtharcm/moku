#!/bin/sh
set -e

# If no admin exists yet and env vars are provided, create one
if [ -n "$PB_SUPERUSER_EMAIL" ] && [ -n "$PB_SUPERUSER_PASSWORD" ]; then
    if [ ! -f /app/pb_data/data.db ]; then
        echo "[moku] Initialising PocketBase and creating superuser..."
        /app/moku-server superuser upsert "$PB_SUPERUSER_EMAIL" "$PB_SUPERUSER_PASSWORD" || true
    fi
fi

exec /app/moku-server "$@"
