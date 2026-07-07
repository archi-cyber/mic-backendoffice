# Copies the branded favicon into the Windows runner resources.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$source = Join-Path $root "assets\images\favicon.ico"
$dest = Join-Path $root "windows\runner\resources\app_icon.ico"

if (-not (Test-Path $source)) {
  throw "Favicon not found at $source"
}

Copy-Item -Force $source $dest
Write-Host "Copied $source -> $dest"
