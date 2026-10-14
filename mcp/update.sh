#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# O Dockerfile clona o upstream (zereight/gitlab-mcp) numa camada RUN. Sem
# --no-cache o Docker reaproveita essa camada e a imagem "nova" sai com o
# código antigo: foi assim que o servidor ficou meses sem a correção que
# libera as sessões expiradas (14/10/2026, MAX_SESSIONS esgotado).
echo "==> Reconstruindo a imagem sem cache (traz o upstream atual)..."
docker compose build --no-cache --pull

echo "==> Recriando serviços..."
docker compose up --force-recreate --remove-orphans --wait -d

echo "==> Removendo imagens órfãs..."
docker image prune -f

echo "==> Status:"
docker compose ps

echo ""
echo "==> Versão do upstream embutida na imagem:"
docker compose exec -T mcp node -e "console.log(require('/app/package.json').version)"

echo ""
echo "==> Logs (últimas 20 linhas):"
docker compose logs --tail=20
