# Étape 1 : dépendances de production, aux versions figées par package-lock.json
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Étape 2 : image d'exécution sans npm, npx, corepack ni yarn
FROM node:24-alpine
ENV NODE_ENV=production
WORKDIR /app
RUN rm -rf /usr/local/lib/node_modules /opt/yarn-* \
      /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack /usr/local/bin/yarn /usr/local/bin/yarnpkg

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
COPY public ./public

# Exécution sans les droits root (UID 1000 = utilisateur "node" fourni par l'image)
USER 1000

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD ["wget", "-qO", "/dev/null", "http://127.0.0.1:3000/healthz"]

CMD ["node", "src/server.js"]
