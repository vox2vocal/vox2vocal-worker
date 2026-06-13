# syntax=docker/dockerfile:1.7
FROM node:22-alpine AS deps
WORKDIR /app
ENV npm_config_audit=false \
  npm_config_fund=false \
  npm_config_progress=false \
  npm_config_update_notifier=false
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
  npm ci \
  --prefer-offline \
  --fetch-retries=5 \
  --fetch-retry-mintimeout=20000 \
  --fetch-retry-maxtimeout=120000 \
  --fetch-timeout=300000

FROM node:22-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
EXPOSE 3003
CMD ["node", "dist/src/main.js"]
