set windows-shell := ["pwsh.exe", "-NoLogo", "-NoProfile", "-Command"]
set shell := ["bash", "-cu"]

mod compose 'docker-compose/docker-compose.just'
mod helm    'helm/helm.just'
mod tests   'tests/tests.just'

# Default: list available recipes (including module recipes).
default:
    @just --list

# test-* recipes: bring stack up → run tests → tear stack down.
# Pass `--keep` as the first arg to leave the stack running for poking at.

[windows]
test-compose keep="" slow_mo="800" step_pause_ms="1500":
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    just compose up
    try {
        just tests headed {{slow_mo}} {{step_pause_ms}}
    } finally {
        if ('{{keep}}' -ne '--keep') { just compose down }
    }

[unix]
test-compose keep="" slow_mo="800" step_pause_ms="1500":
    #!/usr/bin/env bash
    set -euo pipefail
    just compose up
    trap '[ "{{keep}}" = "--keep" ] || just compose down' EXIT
    just tests headed {{slow_mo}} {{step_pause_ms}}

[windows]
test-compose-ci keep="":
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    just compose up
    try {
        just tests ci
    } finally {
        if ('{{keep}}' -ne '--keep') { just compose down }
    }

[unix]
test-compose-ci keep="":
    #!/usr/bin/env bash
    set -euo pipefail
    just compose up
    trap '[ "{{keep}}" = "--keep" ] || just compose down' EXIT
    just tests ci

[windows]
test-helm keep="" host="127.0.0.1" port="" slow_mo="800" step_pause_ms="1500":
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    just helm up '{{host}}' '{{port}}'
    $base = if ('{{port}}') { "http://{{host}}:{{port}}" } else { "http://{{host}}" }
    $env:BASE_URL = $base
    try {
        just tests headed {{slow_mo}} {{step_pause_ms}}
    } finally {
        if ('{{keep}}' -ne '--keep') { just helm down }
    }

[unix]
test-helm keep="" host="127.0.0.1" port="" slow_mo="800" step_pause_ms="1500":
    #!/usr/bin/env bash
    set -euo pipefail
    just helm up '{{host}}' '{{port}}'
    base="http://{{host}}"
    [ -n "{{port}}" ] && base="$base:{{port}}"
    trap '[ "{{keep}}" = "--keep" ] || just helm down' EXIT
    BASE_URL="$base" just tests headed {{slow_mo}} {{step_pause_ms}}

[windows]
test-helm-ci keep="" host="127.0.0.1" port="":
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    just helm up '{{host}}' '{{port}}'
    $base = if ('{{port}}') { "http://{{host}}:{{port}}" } else { "http://{{host}}" }
    $env:BASE_URL = $base
    try {
        just tests ci
    } finally {
        if ('{{keep}}' -ne '--keep') { just helm down }
    }

[unix]
test-helm-ci keep="" host="127.0.0.1" port="":
    #!/usr/bin/env bash
    set -euo pipefail
    just helm up '{{host}}' '{{port}}'
    base="http://{{host}}"
    [ -n "{{port}}" ] && base="$base:{{port}}"
    trap '[ "{{keep}}" = "--keep" ] || just helm down' EXIT
    BASE_URL="$base" just tests ci

# Build the custom Keycloak image (`auth2-proxy/keycloak:local`) with the
# realm pre-imported into the embedded H2 db. Same image is used by both
# the docker-compose stack and the helm chart; both flows call this recipe
# with their own host/port so the baked redirect URIs are correct.
[windows]
build-keycloak host="127.0.0.1" port="":
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    $ctx = Join-Path $env:TEMP 'auth2-proxy-keycloak-build'
    if (Test-Path $ctx) { Remove-Item $ctx -Recurse -Force }
    New-Item -ItemType Directory -Path $ctx | Out-Null
    Set-Content -Path (Join-Path $ctx '.env') -Value "HOST_IP={{host}}`nHOST_PORT={{port}}"
    gomplate `
        --datasource "env=$ctx/.env?type=application/x-env" `
        --file Dockerfiles/keycloak/realm-export.template.json `
        --out  "$ctx/realm-export.json"
    docker build -f Dockerfiles/keycloak/Dockerfile -t auth2-proxy/keycloak:local $ctx

[unix]
build-keycloak host="127.0.0.1" port="":
    #!/usr/bin/env bash
    set -euo pipefail
    ctx=$(mktemp -d)
    trap 'rm -rf "$ctx"' EXIT
    printf 'HOST_IP=%s\nHOST_PORT=%s\n' '{{host}}' '{{port}}' > "$ctx/.env"
    gomplate \
        --datasource "env=$ctx/.env?type=application/x-env" \
        --file Dockerfiles/keycloak/realm-export.template.json \
        --out  "$ctx/realm-export.json"
    docker build -f Dockerfiles/keycloak/Dockerfile -t auth2-proxy/keycloak:local "$ctx"

# Generate a fresh 32-char cookie secret.
[windows]
cookie-secret:
    @pwsh -NoProfile -Command "-join ((48..57) + (97..102) | Get-Random -Count 32 | ForEach-Object { [char]$_ })"

[unix]
cookie-secret:
    @openssl rand -hex 16
