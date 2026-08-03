# Phase 1 — Fondation du backend

Guide d'installation. À la fin de cette phase, le backend démarre, se connecte à
PostgreSQL sur Railway, et les 37 tables existent.

---

## 1. Où placer chaque fichier

Le dossier `backend/` existe déjà dans ton projet, avec un squelette NestJS vide.
Les fichiers ci-dessous viennent le compléter.

```
mic_backoffice/
├── lib/                          ← application Flutter (inchangée pour l'instant)
├── android/  ios/  web/
└── backend/                      ← ICI
    │
    ├── ARCHITECTURE.md                          [NOUVEAU]
    ├── INSTALLATION_PHASE1.md                   [NOUVEAU]  ce fichier
    ├── package.json                             [REMPLACER]
    ├── tsconfig.json                            [REMPLACER]
    ├── tsconfig.build.json                      [REMPLACER]
    ├── nest-cli.json                            [REMPLACER]
    ├── .gitignore                               [REMPLACER]
    ├── .dockerignore                            [NOUVEAU]
    ├── .env.example                             [NOUVEAU]
    ├── .env                                     [À CRÉER TOI-MÊME, voir §3]
    ├── Dockerfile                               [NOUVEAU]
    ├── railway.json                             [NOUVEAU]
    │
    ├── prisma/
    │   ├── schema.prisma                        [NOUVEAU]
    │   └── migrations/
    │       └── 00000000000000_partial_indexes/
    │           └── migration.sql                [NOUVEAU]  à renommer, voir §5
    │
    └── src/
        ├── main.ts                              [REMPLACER]
        ├── app.module.ts                        [REMPLACER]
        ├── health.controller.ts                 [NOUVEAU]
        │
        ├── config/
        │   ├── configuration.ts                 [NOUVEAU]
        │   └── env.validation.ts                [NOUVEAU]
        │
        ├── prisma/
        │   ├── prisma.module.ts                 [NOUVEAU]
        │   └── prisma.service.ts                [NOUVEAU]
        │
        └── common/
            ├── dto/
            │   └── pagination.dto.ts            [NOUVEAU]
            ├── filters/
            │   ├── all-exceptions.filter.ts     [NOUVEAU]
            │   └── prisma-exception.filter.ts   [NOUVEAU]
            └── interceptors/
                └── transform.interceptor.ts     [NOUVEAU]
```

### Fichiers à supprimer

Le squelette généré par `nest new` contient trois fichiers de démonstration qui
ne servent plus :

```
backend/src/app.controller.ts
backend/src/app.service.ts
backend/src/app.controller.spec.ts
```

Supprime-les — `app.module.ts` ne les référence plus, ils feraient échouer la
compilation.

---

## 2. Créer la base de données sur Railway

1. Va sur [railway.app](https://railway.app) et connecte-toi (GitHub fonctionne bien).
2. **New Project** → **Provision PostgreSQL**.
3. Attends que le service passe au vert (environ 30 secondes).
4. Clique sur le service **Postgres** → onglet **Variables** → copie la valeur de
   `DATABASE_URL`.

Elle ressemble à :

```
postgresql://postgres:MOTDEPASSE@monorail.proxy.rlwy.net:29432/railway
```

> **Note :** cette URL est un secret. Elle donne un accès complet en lecture et
> écriture à la base. Elle ne doit jamais être committée ni collée dans un ticket.

---

## 3. Créer le fichier `.env` local

Dans `backend/`, crée un fichier nommé exactement `.env` (il est déjà ignoré par
Git). Génère d'abord deux secrets JWT :

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

Lance la commande **deux fois** — les deux secrets doivent être différents.

Puis remplis `.env` :

```env
NODE_ENV=development
PORT=3000
API_PREFIX=api/v1

DATABASE_URL="postgresql://postgres:...@monorail.proxy.rlwy.net:29432/railway"

JWT_ACCESS_SECRET=<premier secret généré>
JWT_REFRESH_SECRET=<second secret généré>
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=30d

DEFAULT_USER_PASSWORD=Password123
SUPER_ADMIN_EMAIL=admin@systemic.church
SUPER_ADMIN_PASSWORD=ChangeMoiImmediatement2026!

CORS_ORIGINS=http://localhost:3000,http://localhost:8080

LOG_LEVEL=debug
```

Si un secret fait moins de 32 caractères, ou si les deux sont identiques,
l'application refusera de démarrer avec un message explicite. C'est voulu.

---

## 4. Installer les dépendances

Depuis `backend/` :

```bash
npm install
```

Cette commande installe NestJS, Prisma, Argon2, Socket.IO et le reste, puis
génère automatiquement le client Prisma (script `postinstall`).

Compte deux à trois minutes la première fois.

---

## 5. Créer les tables

### 5.1 Migration initiale

```bash
npx prisma migrate dev --name init
```

Prisma compare `schema.prisma` à la base, génère le SQL et l'applique. Un
nouveau dossier apparaît sous `prisma/migrations/`, avec un nom du type
`20260803140000_init`.

### 5.2 Renommer la migration des index partiels

Le dossier `00000000000000_partial_indexes` porte un horodatage volontairement
nul pour être bien visible. **Renomme-le** avec un horodatage postérieur à celui
de `init` — sinon Prisma tenterait de créer des index sur des tables qui
n'existent pas encore.

Si `init` s'appelle `20260803140000_init`, renomme en :

```
20260803140001_partial_indexes
```

Puis applique :

```bash
npx prisma migrate dev
```

### 5.3 Vérifier

```bash
npx prisma studio
```

Une interface s'ouvre sur `http://localhost:5555` : tu dois y voir les 37 tables,
vides.

---

## 6. Démarrer le serveur

```bash
npm run start:dev
```

Sortie attendue :

```
[Nest] LOG [PrismaService] Connexion PostgreSQL établie.
[Nest] LOG [PrismaService] Base active : railway sur 10.x.x.x
[Nest] LOG [Bootstrap] Documentation disponible sur /api/v1/docs
[Nest] LOG [Bootstrap] SysteMIC API démarrée sur le port 3000
```

Deux vérifications :

| URL | Résultat attendu |
|-----|------------------|
| `http://localhost:3000/health` | `{"status":"ok",...}` |
| `http://localhost:3000/health/ready` | `{"status":"ok","checks":{"database":"up"}}` |
| `http://localhost:3000/api/v1/docs` | Interface Swagger |

Si `/health/ready` renvoie `database: down`, la connexion Railway ne passe pas —
vérifie `DATABASE_URL` dans `.env`.

---

## 7. Déployer sur Railway (optionnel à ce stade)

Rien ne presse : le backend n'expose encore aucune route métier. Mais si tu veux
valider la chaîne de déploiement dès maintenant :

1. Pousse le dossier `backend/` sur un dépôt GitHub.
2. Dans ton projet Railway : **New** → **GitHub Repo** → sélectionne le dépôt.
3. **Settings** → **Root Directory** → `backend` (si le dépôt contient tout le
   projet Flutter).
4. Onglet **Variables**, ajoute :

| Variable | Valeur |
|----------|--------|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}?connection_limit=10&pool_timeout=20` |
| `NODE_ENV` | `production` |
| `JWT_ACCESS_SECRET` | *(un secret différent de celui du local)* |
| `JWT_REFRESH_SECRET` | *(idem)* |
| `CORS_ORIGINS` | *(l'URL de ton app web, quand elle existera)* |

La syntaxe `${{Postgres.DATABASE_URL}}` est résolue par Railway au déploiement :
aucun secret n'est recopié à la main, et l'URL suit automatiquement si la base
est recréée.

5. Railway détecte le `Dockerfile` et construit l'image. Les migrations
   s'appliquent au démarrage du conteneur.

---

## 8. Deux points à valider avant la phase 2

### 8.1 Mots de passe existants

Les comptes actuels vivent dans `auth.users` de Supabase, avec des hachages
bcrypt propriétaires. Ils **ne sont pas récupérables** : le nouveau backend
utilise Argon2id et son propre stockage.

Chaque utilisateur recevra `Password123` avec obligation de changement à la
première connexion — le mécanisme `mustChangePassword` existe déjà dans le code
Flutter actuel, donc l'expérience sera familière.

C'est à annoncer aux responsables avant la bascule.

### 8.2 Champs convertis en énumérations

Le schéma Supabase stockait `gender` et `marital_status` en texte libre. Le
nouveau schéma les contraint :

| Champ | Valeurs acceptées |
|-------|-------------------|
| `gender` | `male`, `female` |
| `maritalStatus` | `single`, `married`, `divorced`, `widowed` |

Si la base actuelle contient des valeurs différentes (`Male`, `M`, `Célibataire`…),
elles devront être normalisées pendant la migration des données.

Pour le vérifier, lance ceci dans le SQL Editor de Supabase :

```sql
SELECT DISTINCT gender FROM members WHERE gender IS NOT NULL;
SELECT DISTINCT marital_status FROM members WHERE marital_status IS NOT NULL;
```

Envoie-moi le résultat : s'il y a des écarts, j'ajusterai soit le schéma, soit le
script de migration.

---

## 9. Ce qui arrive en phase 2

- `AuthModule` : login, refresh, logout, changement et réinitialisation de mot de passe
- Hachage Argon2id
- Stratégie JWT et `JwtAuthGuard`
- `RolesGuard` et `PermissionsGuard` — le remplacement complet des politiques RLS
- Décorateurs `@Public()`, `@CurrentUser()`, `@Roles()`, `@RequirePermission()`
- `prisma/seed.ts` : création du compte super-administrateur et des paramètres par défaut

Dis-moi quand la phase 1 tourne et je te livre la suite.
