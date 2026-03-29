# GitLab MCP Server — Kanban Embrapa I/O

MCP Server para gestão de Kanban (issues, milestones, labels) no GitLab CE da Embrapa (`git.embrapa.io`).

Baseado em [`@zereight/gitlab-mcp`](https://github.com/zereight/gitlab-mcp) com autenticação MCP OAuth — cada usuário autentica diretamente no GitLab, e o MCP opera com as permissões desse usuário.

## Arquitetura

```
Cliente MCP (Claude, Cursor, VS Code...)
        |
        | Streamable HTTP + OAuth autodiscovery
        v
   mcp.git.embrapa.io (Nginx reverse proxy)
        |
        v
   gitlab-mcp container (:3002)
        |
        | OAuth proxy (GITLAB_MCP_OAUTH)
        v
   git.embrapa.io (GitLab CE API)
```

**Fluxo de autenticação:**

1. Cliente MCP acessa `https://mcp.git.embrapa.io/`
2. Recebe `401` com `WWW-Authenticate` contendo URL do metadata OAuth
3. Cliente descobre endpoints via `/.well-known/oauth-authorization-server`
4. Cliente registra-se via Dynamic Client Registration (`POST /register`)
5. Browser do usuário abre página de login do GitLab
6. Usuário autentica → redirect de volta ao cliente
7. Token enviado como `Authorization: Bearer <token>` em cada request

## Pré-requisitos

- Docker e Docker Compose v2+
- Domínio `mcp.git.embrapa.io` apontando para o servidor
- Certificado TLS (Let's Encrypt ou institucional)
- Acesso admin ao GitLab CE em `git.embrapa.io`

## Configuração do GitLab

### Criar OAuth Application

1. Acessar `https://git.embrapa.io` como **Admin**
2. Ir em **Admin Area > Applications**
3. Clicar **New Application**
4. Preencher:

| Campo | Valor |
|-------|-------|
| Name | `GitLab MCP Server` |
| Redirect URI | Ver lista abaixo |
| Trusted | Desmarcado |
| Confidential | Desmarcado (usa PKCE) |
| Scopes | `api` + `read_api` + `read_user` |

**Redirect URIs** (uma por linha):
```
https://claude.ai/api/mcp/auth_callback
cursor://anysphere.cursor-mcp/oauth/callback
http://127.0.0.1/oauth/callback
http://127.0.0.1/callback
http://127.0.0.1/mcp-auth/callback
http://localhost/oauth/callback
http://localhost/callback
```

O GitLab CE (Doorkeeper) implementa RFC 8252 §7.3: para loopback IPs (`127.0.0.1`),
a porta é ignorada na comparação. `localhost` (hostname) exige match exato.

5. Salvar e copiar o **Application ID**

## Instalação

```bash
# Clonar/copiar este diretório no servidor
cd /path/to/gitlab/mcp

# Copiar e preencher variáveis
cp .env.example .env
nano .env  # preencher GITLAB_OAUTH_APP_ID

# Subir
docker compose up --force-recreate --build --remove-orphans --wait -d

# Verificar
docker compose ps
docker compose logs -f mcp
```

## Variáveis de Ambiente

| Variável | Obrigatória | Padrão | Descrição |
|----------|-------------|--------|-----------|
| `COMPOSE_PROJECT_NAME` | Sim | — | Nome do projeto Docker (`io_gitlab-mcp`) |
| `PORT` | Sim | — | Porta exposta (ex: `127.0.0.1:3002`) |
| `GITLAB_OAUTH_APP_ID` | Sim | — | Application ID do OAuth App no GitLab |
| `GITLAB_API_URL` | Sim | — | URL da API do GitLab (ex: `https://git.embrapa.io/api/v4`) |
| `MCP_SERVER_URL` | Sim | — | URL pública do MCP Server (ex: `https://mcp.git.embrapa.io`) |
| `MAX_SESSIONS` | Não | `500` | Máximo de sessões simultâneas |
| `MAX_REQUESTS_PER_MINUTE` | Não | `30` | Rate limit por sessão |
| `SESSION_TIMEOUT_SECONDS` | Não | `3600` | Timeout de inatividade da sessão (segundos) |

## Toolsets Habilitados

Apenas ferramentas relevantes para gestão de kanban estão expostas:

| Toolset | Tools | Descrição |
|---------|-------|-----------|
| `issues` | 14 | CRUD de issues, notas, links, discussões |
| `labels` | 5 | CRUD de labels (project-level) |
| `milestones` | 9 | CRUD de milestones, burndown, promote |
| `projects` | 8 | Listar projetos/grupos, namespaces, membros |

**Total: 36 tools expostas** (de 96+ disponíveis).

Para habilitar GraphQL (operações avançadas em nível de grupo), adicionar no `docker-compose.yaml`:
```yaml
GITLAB_TOOLS: "execute_graphql"
```

## Atualização

```bash
./update.sh
```

O script:
1. Builda a imagem a partir do código-fonte (clona `github.com/zereight/gitlab-mcp` no Dockerfile) e recria os serviços (`docker compose up --force-recreate --build --remove-orphans --wait -d`)
2. Remove imagens órfãs (`docker image prune -f`)
3. Exibe status e logs

> **Nota**: A imagem é buildada a partir do GitHub via Dockerfile local e não do Docker Hub (`zereight050/gitlab-mcp`), pois a imagem do Hub não inclui funcionalidades recentes como `GITLAB_MCP_OAUTH`.

## Configuração do Reverse Proxy

O MCP com Streamable HTTP usa conexões long-lived (SSE server→client) que exigem configuração específica no reverse proxy.

### Requisitos do protocolo MCP

- `POST /mcp` — JSON-RPC requests (request/response normal)
- `GET /mcp` — SSE stream para notificações server→client (long-lived, chunked)
- `DELETE /mcp` — Encerramento de sessão
- `GET /.well-known/oauth-authorization-server` — OAuth discovery
- `POST /register` — Dynamic Client Registration
- `GET /authorize`, `POST /token`, `GET /callback` — Fluxo OAuth
- Headers críticos: `Mcp-Session-Id`, `Last-Event-ID` (resumabilidade)

> **Importante**: A URL do MCP é `https://mcp.git.embrapa.io/mcp` (com `/mcp` no path).
> O reverse proxy deve encaminhar **todos os paths** ao backend sem rewrite.

### Nginx Proxy Manager (NPM)

O proxy é feito via Nginx Proxy Manager em VM separada. Configuração:

**Aba Details:**
- Domain: `mcp.git.embrapa.io`
- Scheme: `http`
- Forward Hostname/IP: IP interno do servidor (ex: `200.202.148.18`)
- Forward Port: porta do `.env` (ex: `8016`)
- Websockets Support: ativado
- Cache Assets: desativado
- Block Common Exploits: desativado

**Aba SSL:**
- Certificado SSL configurado para o domínio
- Force SSL: opcional

**Aba Advanced — Custom Nginx Configuration:**
```nginx
proxy_buffering off;
proxy_cache off;
proxy_read_timeout 86400s;
proxy_send_timeout 86400s;
proxy_set_header Connection $http_connection;
proxy_set_header X-Forwarded-Proto $scheme;
chunked_transfer_encoding on;
```

| Configuração | Motivo |
|--------------|--------|
| `proxy_buffering off` | SSE requer que chunks sejam enviados imediatamente ao cliente |
| `proxy_cache off` | Respostas MCP não devem ser cacheadas |
| `proxy_read_timeout 86400s` | Conexões SSE ficam abertas por horas/dias |
| `proxy_send_timeout 86400s` | Idem para envio |
| `chunked_transfer_encoding on` | SSE usa chunked transfer |
| `Connection $http_connection` | Preserva upgrade/keepalive do cliente |

## Configuração dos Clientes MCP

Após o deploy, os usuários configuram seus clientes assim:

### Claude Desktop / Claude Code

```json
{
  "mcpServers": {
    "gitlab-kanban": {
      "url": "https://mcp.git.embrapa.io/mcp"
    }
  }
}
```

### Cursor IDE

```json
{
  "mcpServers": {
    "gitlab-kanban": {
      "url": "https://mcp.git.embrapa.io/mcp"
    }
  }
}
```

### VS Code (GitHub Copilot)

`.vscode/mcp.json`:
```json
{
  "servers": {
    "gitlab-kanban": {
      "type": "http",
      "url": "https://mcp.git.embrapa.io/mcp"
    }
  }
}
```

### OpenCode CLI

`opencode.json`:
```json
{
  "mcp": {
    "gitlab-kanban": {
      "type": "remote",
      "url": "https://mcp.git.embrapa.io/mcp"
    }
  }
}
```

## Monitoramento

```bash
# Status do container
docker compose ps

# Logs em tempo real
docker compose logs -f mcp

# Health check
curl -s https://mcp.git.embrapa.io/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"healthcheck","version":"1.0"}}}'

# Verificar OAuth discovery
curl -s https://mcp.git.embrapa.io/.well-known/oauth-authorization-server | jq .
```

## Troubleshooting

### Conexão recusada na porta 3002

```bash
docker compose logs mcp | tail -20
# Verificar se o container está rodando
docker compose ps
```

### OAuth redirect não funciona

1. Verificar se o `MCP_SERVER_URL` no `.env` bate com o domínio público
2. Verificar se o `Redirect URI` no OAuth App do GitLab bate com `MCP_SERVER_URL/callback`
3. Verificar logs: `docker compose logs mcp | grep -i oauth`

### SSE timeout / conexão fechada

1. Verificar `proxy_read_timeout` no Nginx (deve ser >= 86400s)
2. Verificar se `proxy_buffering off` está configurado
3. Verificar se não há balanceador/CDN intermediário limitando conexões

### Certificado TLS autoassinado no GitLab

Adicionar no `docker-compose.yaml`:
```yaml
environment:
  NODE_TLS_REJECT_UNAUTHORIZED: "0"
```

## Limitações Conhecidas

1. **Labels/Milestones são project-level**: As tools operam em projetos, não em grupos. Os labels do kanban (To Do, Doing, etc.) já são criados pelo Embrapa I/O na criação do grupo, então a atribuição a issues funciona normalmente.

2. **Issue Boards**: Não há tools para criar/gerenciar boards. O board do grupo precisa ser criado manualmente ou via API direta do GitLab.

3. **Apenas Streamable HTTP**: O modo MCP OAuth não suporta SSE como transporte principal. GET /mcp para notificações server→client usa SSE internamente, mas o transporte de entrada é Streamable HTTP.
