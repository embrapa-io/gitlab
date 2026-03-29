FROM node:22-alpine AS builder

RUN apk add --no-cache git

RUN git clone --depth 1 https://github.com/zereight/gitlab-mcp.git /app

WORKDIR /app

RUN npm ci --ignore-scripts
RUN npm run build
RUN npm ci --ignore-scripts --omit=dev

FROM node:22-alpine

WORKDIR /app

COPY --from=builder /app/build /app/build
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/package.json /app/package.json

ENV NODE_ENV=production

EXPOSE 3002

ENTRYPOINT ["node", "build/index.js"]
