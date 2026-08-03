# =============================================================================
# SysteMIC Backend — image de production
# =============================================================================
# Construction en plusieurs étapes : l'image finale ne contient que le code
# compilé et les dépendances d'exécution. Les outils de compilation
# (TypeScript, NestJS CLI, sources) restent dans les étapes intermédiaires.
# =============================================================================

# -----------------------------------------------------------------------------
# Étape 1 — dépendances complètes (développement inclus)
# -----------------------------------------------------------------------------
FROM node:20-alpine AS deps

WORKDIR /app

# OpenSSL est requis par les moteurs Prisma sur Alpine.
RUN apk add --no-cache openssl libc6-compat

# Seuls les manifestes sont copiés à ce stade : tant qu'ils ne changent pas,
# Docker réutilise le cache de cette couche et saute l'installation complète.
COPY package*.json ./
COPY prisma ./prisma/

# `--ignore-scripts` empêche le postinstall de tourner trop tôt ; on génère le
# client Prisma explicitement juste après, une fois le schéma présent.
RUN npm ci --ignore-scripts && npx prisma generate


# -----------------------------------------------------------------------------
# Étape 2 — compilation TypeScript
# -----------------------------------------------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

RUN apk add --no-cache openssl libc6-compat

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npx prisma generate && npm run build


# -----------------------------------------------------------------------------
# Étape 3 — dépendances de production uniquement
# -----------------------------------------------------------------------------
FROM node:20-alpine AS prod-deps

WORKDIR /app

RUN apk add --no-cache openssl libc6-compat

COPY package*.json ./
COPY prisma ./prisma/

RUN npm ci --omit=dev --ignore-scripts && npx prisma generate


# -----------------------------------------------------------------------------
# Étape 4 — image finale
# -----------------------------------------------------------------------------
FROM node:20-alpine AS runner

WORKDIR /app

RUN apk add --no-cache openssl libc6-compat dumb-init

ENV NODE_ENV=production

# Exécution sous un utilisateur non privilégié : si le processus était
# compromis, l'attaquant n'obtiendrait pas les droits root dans le conteneur.
RUN addgroup -g 1001 -S nodejs \
  && adduser -S nestjs -u 1001

COPY --from=prod-deps --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder   --chown=nestjs:nodejs /app/dist ./dist
COPY --from=builder   --chown=nestjs:nodejs /app/prisma ./prisma
COPY --chown=nestjs:nodejs package.json ./

USER nestjs

EXPOSE 3000

# dumb-init relaie correctement SIGTERM. Sans lui, Node tourne en PID 1 et
# ignore le signal : Railway devrait tuer le conteneur de force, coupant les
# requêtes en cours et laissant des connexions PostgreSQL ouvertes.
ENTRYPOINT ["dumb-init", "--"]

# Les migrations s'appliquent avant le démarrage du serveur. `migrate deploy`
# ne crée jamais de migration et ne réinitialise jamais la base : il applique
# uniquement celles déjà versionnées dans le dépôt.
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main"]