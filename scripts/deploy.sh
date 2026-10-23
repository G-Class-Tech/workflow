#!/usr/bin/env bash
# Runs on the server: bash scripts/deploy.sh <git-sha> [healthcheck-url]
set -euo pipefail

SHA="${1:?usage: deploy.sh <git-sha> [healthcheck-url]}"
HEALTH_URL="${2:-}"

PREVIOUS="$(git rev-parse HEAD)"

release() {
    git fetch --prune origin
    git reset --hard "$1"
    composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    php artisan event:cache
    php artisan queue:restart
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

php artisan down --retry=60 || true
trap 'php artisan up || true' EXIT

release "$SHA"

# Migrations must be backward-compatible: the old code is the rollback target.
php artisan migrate --force

php artisan up
trap - EXIT

if ! healthy; then
    echo "Health check failed - rolling code back to $PREVIOUS" >&2
    release "$PREVIOUS"
    exit 1
fi

echo "Deployed $SHA"
