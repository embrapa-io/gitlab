#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Baixando imagens atualizadas..."
docker compose pull

echo "==> Recriando serviços..."
docker compose up --force-recreate --build --remove-orphans --wait -d

echo "==> Removendo imagens órfãs..."
docker image prune -f

echo "==> Status:"
docker compose ps

echo ""
echo "==> Logs (últimas 20 linhas):"
docker compose logs --tail=20
