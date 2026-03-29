#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Parando serviços..."
docker compose down

echo "==> Baixando imagens atualizadas..."
docker compose pull

echo "==> Subindo serviços..."
docker compose up -d

echo "==> Removendo imagens órfãs..."
docker image prune -f

echo "==> Status:"
docker compose ps

echo ""
echo "==> Logs (últimas 20 linhas):"
docker compose logs --tail=20
