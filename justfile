set windows-shell := ["pwsh.exe", "-NoLogo", "-NoProfile", "-Command"]
set shell := ["bash", "-cu"]

mod compose 'docker-compose/docker-compose.just'
mod helm    'helm/helm.just'
mod tests   'tests/tests.just'

# Default: list available recipes (including module recipes).
default:
    @just --list

# Bring the compose stack up and run the headed Playwright suite against it.
test-compose slow_mo="800" step_pause_ms="1500":
    just compose up
    just tests headed {{slow_mo}} {{step_pause_ms}}

# Same as test-compose but headless (for CI / quick checks).
test-compose-ci:
    just compose up
    just tests ci

# Bring the helm stack up and run the headed Playwright suite against it.
[windows]
test-helm host="127.0.0.1" port="" slow_mo="800" step_pause_ms="1500":
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    just helm up '{{host}}' '{{port}}'
    $base = if ('{{port}}') { "http://{{host}}:{{port}}" } else { "http://{{host}}" }
    $env:BASE_URL = $base
    just tests headed {{slow_mo}} {{step_pause_ms}}

[unix]
test-helm host="127.0.0.1" port="" slow_mo="800" step_pause_ms="1500":
    #!/usr/bin/env bash
    set -euo pipefail
    just helm up '{{host}}' '{{port}}'
    base="http://{{host}}"
    [ -n "{{port}}" ] && base="$base:{{port}}"
    BASE_URL="$base" just tests headed {{slow_mo}} {{step_pause_ms}}

# Same as test-helm but headless.
[windows]
test-helm-ci host="127.0.0.1" port="":
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $true
    just helm up '{{host}}' '{{port}}'
    $base = if ('{{port}}') { "http://{{host}}:{{port}}" } else { "http://{{host}}" }
    $env:BASE_URL = $base
    just tests ci

[unix]
test-helm-ci host="127.0.0.1" port="":
    #!/usr/bin/env bash
    set -euo pipefail
    just helm up '{{host}}' '{{port}}'
    base="http://{{host}}"
    [ -n "{{port}}" ] && base="$base:{{port}}"
    BASE_URL="$base" just tests ci

# Generate a fresh 32-char cookie secret.
[windows]
cookie-secret:
    @pwsh -NoProfile -Command "-join ((48..57) + (97..102) | Get-Random -Count 32 | ForEach-Object { [char]$_ })"

[unix]
cookie-secret:
    @openssl rand -hex 16
