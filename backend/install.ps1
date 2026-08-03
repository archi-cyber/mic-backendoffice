# =============================================================================
# SysteMIC Backend — installation des dépendances
# =============================================================================
# À lancer depuis le dossier backend/ :
#     .\install.ps1
#
# Si PowerShell refuse d'exécuter le script :
#     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
# =============================================================================

Write-Host "`n=== Nettoyage ===" -ForegroundColor Cyan

# Une installation partielle laisse node_modules dans un état incohérent :
# certains paquets présents, d'autres non, avec un lockfile qui ne correspond
# plus. Repartir de zéro est plus rapide que diagnostiquer.
if (Test-Path node_modules) {
    Write-Host "Suppression de node_modules..."
    Remove-Item -Recurse -Force node_modules
}
if (Test-Path package-lock.json) {
    Remove-Item -Force package-lock.json
}

Write-Host "`n=== Dependances de production ===" -ForegroundColor Cyan

npm install `
  "@nestjs/common@^11.0.1" `
  "@nestjs/config@^4.0.0" `
  "@nestjs/core@^11.0.1" `
  "@nestjs/jwt@^11.0.0" `
  "@nestjs/passport@^11.0.5" `
  "@nestjs/platform-express@^11.0.1" `
  "@nestjs/platform-socket.io@^11.0.1" `
  "@nestjs/schedule@^5.0.1" `
  "@nestjs/swagger@^8.1.0" `
  "@nestjs/throttler@^6.4.0" `
  "@nestjs/websockets@^11.0.1" `
  "@prisma/client@^6.3.0" `
  "argon2@^0.41.1" `
  "class-transformer@^0.5.1" `
  "class-validator@^0.14.1" `
  "compression@^1.7.5" `
  "date-fns@^4.1.0" `
  "helmet@^8.0.0" `
  "joi@^17.13.3" `
  "passport@^0.7.0" `
  "passport-jwt@^4.0.1" `
  "reflect-metadata@^0.2.2" `
  "rxjs@^7.8.1" `
  "socket.io@^4.8.1" `
  --save --ignore-scripts

Write-Host "`n=== Dependances de developpement ===" -ForegroundColor Cyan

npm install `
  "@nestjs/cli@^11.0.0" `
  "@nestjs/schematics@^11.0.0" `
  "@nestjs/testing@^11.0.1" `
  "@types/compression@^1.7.5" `
  "@types/express@^5.0.0" `
  "@types/node@^22.10.0" `
  "@types/passport-jwt@^4.0.1" `
  "prisma@^6.3.0" `
  "ts-node@^10.9.2" `
  "tsconfig-paths@^4.2.0" `
  "typescript@^5.7.3" `
  --save-dev --ignore-scripts

Write-Host "`n=== Generation du client Prisma ===" -ForegroundColor Cyan

# Cette étape crée les types TypeScript à partir de schema.prisma.
# Sans elle, tous les imports depuis '@prisma/client' resteront en erreur.
npx prisma generate

Write-Host "`n=== Termine ===" -ForegroundColor Green
Write-Host "Verifie qu'il ne reste aucune erreur dans VS Code, puis lance :"
Write-Host "    npm run start:dev" -ForegroundColor Yellow