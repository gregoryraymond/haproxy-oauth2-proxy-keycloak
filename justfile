set windows-shell := ["pwsh.exe", "-NoLogo", "-NoProfile", "-Command"]
set shell := ["bash", "-cu"]

# Default: list available recipes.
default:
    @just --list

# Create / refresh .env, auto-detecting the host's primary LAN IPv4.
# Detect the primary LAN IPv4 and write it to .env.
# (Just the HOST_IP line is updated — user-edited values like passwords are preserved.)
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
    Write-Host "HOST_IP=$detected written to .env"

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
    echo "HOST_IP=$detected written to .env"

# Render the Keycloak realm export from its gomplate template, deriving
# PUBLIC_URL from the freshly-written .env. Keycloak 24+ doesn't allow
# host-level wildcards in redirectUris, so the URL is materialized here.
init: _detect-ip
    gomplate \
        --datasource 'env=.env?type=application/x-env' \
        --file keycloak/realm-export.template.json \
        --out  keycloak/realm-export.json
    @echo "Rendered keycloak/realm-export.json"

# Bring the stack up in the background and wait for healthchecks.
up: init
    docker compose up -d --wait

# Tear the stack down (keeps volumes by default).
down:
    docker compose down

# Tear down and remove volumes.
nuke:
    docker compose down -v

# Tail logs for all services (or one: `just logs keycloak`).
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

# Spin the stack up and run the *headed* Playwright suite. Watch the browser.
# Tweak pacing with: just test slow_mo=300 step_pause_ms=500
[windows]
test slow_mo="800" step_pause_ms="1500": up
    npm install --no-audit --no-fund
    npx playwright install chromium
    pwsh -NoProfile -Command "$env:SLOW_MO='{{slow_mo}}'; $env:STEP_PAUSE_MS='{{step_pause_ms}}'; npx playwright test"

[unix]
test slow_mo="800" step_pause_ms="1500": up
    npm install --no-audit --no-fund
    npx playwright install chromium
    SLOW_MO={{slow_mo}} STEP_PAUSE_MS={{step_pause_ms}} npx playwright test

# Same as `test` but headless (for CI / quick checks).
[windows]
test-ci: up
    npm install --no-audit --no-fund
    npx playwright install chromium
    pwsh -NoProfile -Command "$env:HEADLESS='true'; $env:SLOW_MO='0'; $env:STEP_PAUSE_MS='0'; npx playwright test"

[unix]
test-ci: up
    npm install --no-audit --no-fund
    npx playwright install --with-deps chromium
    HEADLESS=true SLOW_MO=0 STEP_PAUSE_MS=0 npx playwright test

# Generate a fresh 32-char cookie secret.
[windows]
cookie-secret:
    @pwsh -NoProfile -Command "-join ((48..57) + (97..102) | Get-Random -Count 32 | ForEach-Object { [char]$_ })"

[unix]
cookie-secret:
    @openssl rand -hex 16
