#!/usr/bin/env bash
# Runs on the server, from the project directory:
#   bash scripts/deploy.sh <git-sha> [healthcheck-url]
# All PHP/composer/artisan work happens inside the docker compose stack;
# only git, docker and the (throwaway) node container run on the host.
set -euo pipefail

SHA="${1:?usage: deploy.sh <git-sha> [healthcheck-url]}"
HEALTH_URL="${2:-}"

export COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml:docker-compose.prod.yml:docker-compose.db.yml}"
# Make the container user match the host user so storage/ and vendor/ stay writable.
export HOST_UID="$(id -u)" HOST_GID="$(id -g)"

PREVIOUS="$(git rev-parse HEAD)"

release() {
    git fetch --prune origin
    git reset --hard "$1"

    # Directories git ignores but Laravel needs to write to.
    mkdir -p storage/framework/{cache/data,sessions,views} storage/logs bootstrap/cache

    # Frontend assets (the image has no node).
    docker run --rm -v "$PWD":/app -w /app node:22-alpine sh -c 'npm ci && npm run build'

    docker compose up -d --build --remove-orphans

    # Fix ownership from inside the container (root there), so it works even when
    # files were created by another UID. exec runs as root; php-fpm workers run as `app`.
    docker compose exec -T app chown -R app:app storage bootstrap/cache
    docker compose exec -T app chmod -R ug+rwX storage bootstrap/cache
    docker compose exec -T app composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader
    docker compose exec -T app php artisan config:cache
    docker compose exec -T app php artisan route:cache
    docker compose exec -T app php artisan view:cache
    docker compose exec -T app php artisan event:cache
    docker compose exec -T app php artisan queue:restart
}

healthy() {
    [ -z "$HEALTH_URL" ] && return 0
    for _ in 1 2 3 4 5; do
        curl -fsS --max-time 10 "$HEALTH_URL" >/dev/null && return 0
        sleep 3
    done
    return 1
}

echo "Deploying $SHA (previous: $PREVIOUS)"

release "$SHA"

# Migrations must be backward-compatible: the old code is the rollback target.
docker compose exec -T app php artisan migrate --force

if ! healthy; then
    echo "Health check failed - rolling code back to $PREVIOUS" >&2
    release "$PREVIOUS"
    exit 1
fi

echo "Deployed $SHA"
