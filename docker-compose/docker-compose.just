set windows-shell := ["pwsh.exe", "-NoLogo", "-NoProfile", "-Command"]
set shell := ["bash", "-cu"]
set working-directory := '.'

# Default: list available recipes.
default:
    @just --list --justfile {{justfile()}}

# Detect the primary LAN IPv4 and write it to .env. (Just the HOST_IP line is
# updated — user-edited values like passwords are preserved.)
[windows]
_detect-ip:
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $detected = (
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object {
                $_.PrefixOrigin -in 'Dhcp','Manual' -and
                $_.IPAddress -notlike '169.254.*' -and
                $_.IPAddress -ne '127.0.0.1' -and
                $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL|Bluetooth'
            } |
            Sort-Object -Property InterfaceMetric |
            Select-Object -First 1 -ExpandProperty IPAddress
    )
    if (-not $detected) { $detected = '127.0.0.1' }
    if (-not (Test-Path .env)) { Copy-Item .env.example .env }
    (Get-Content .env) -replace '^HOST_IP=.*', "HOST_IP=$detected" | Set-Content .env
    Write-Host "HOST_IP=$detected written to docker-compose/.env"

[unix]
_detect-ip:
    #!/usr/bin/env bash
    set -euo pipefail
    detected=$(ip -4 -o addr show scope global 2>/dev/null \
        | awk 'NR==1{print $4}' | cut -d/ -f1)
    : "${detected:=127.0.0.1}"
    [ -f .env ] || cp .env.example .env
    awk -v ip="$detected" '/^HOST_IP=/{print "HOST_IP=" ip; next} {print}' .env > .env.new
    mv .env.new .env
    echo "HOST_IP=$detected written to docker-compose/.env"

# Build the baked Keycloak image, deriving HOST_IP / HOST_PORT from .env
# so redirect URIs in the realm match what the browser will actually hit.
[windows]
init: _detect-ip
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    $env_kv = Get-Content .env | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $_ -split '=', 2 }
    $env_table = @{}
    Get-Content .env | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object {
        $k, $v = $_ -split '=', 2
        $env_table[$k] = $v
    }
    just build-keycloak $env_table['HOST_IP'] $env_table['HOST_PORT']

[unix]
init: _detect-ip
    #!/usr/bin/env bash
    set -euo pipefail
    set -a; source .env; set +a
    just build-keycloak "$HOST_IP" "$HOST_PORT"

# Bring the stack up in the background and wait for healthchecks.
up: init
    docker compose up -d --wait

# Tear the stack down (keeps volumes by default).
down:
    docker compose down

# Tear down and remove volumes.
nuke:
    docker compose down -v

# Tail logs for all services (or one: `just compose logs keycloak`).
logs service="":
    docker compose logs -f {{service}}

# Show the URLs to open once the stack is healthy.
urls:
    #!/usr/bin/env sh
    set -e
    host=$(grep '^HOST_IP=' .env | cut -d= -f2)
    port=$(grep '^HOST_PORT=' .env | cut -d= -f2)
    echo "Landing (auth required): http://$host:$port/"
    echo "Protected page:          http://$host:$port/page"
    echo "Keycloak admin:          http://$host:$port/auth/admin/"
    echo "oauth2-proxy sign-out:   http://$host:$port/oauth/sign_out"
