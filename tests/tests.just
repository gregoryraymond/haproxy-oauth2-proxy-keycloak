set windows-shell := ["pwsh.exe", "-NoLogo", "-NoProfile", "-Command"]
set shell := ["bash", "-cu"]
set working-directory := '.'

# Default: list available recipes.
default:
    @just --list --justfile {{justfile()}}

# Install npm deps + a local chromium (idempotent).
_install:
    npm install --no-audit --no-fund
    npx playwright install chromium

# Headed Playwright run, slow_mo / step_pause_ms tunable for live watching.
[windows]
headed slow_mo="800" step_pause_ms="1500": _install
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $env:SLOW_MO       = '{{slow_mo}}'
    $env:STEP_PAUSE_MS = '{{step_pause_ms}}'
    npx playwright test

[unix]
headed slow_mo="800" step_pause_ms="1500": _install
    #!/usr/bin/env bash
    set -euo pipefail
    SLOW_MO={{slow_mo}} STEP_PAUSE_MS={{step_pause_ms}} npx playwright test

# Headless Playwright run (CI / quick check). Honours HOST_IP / HOST_PORT /
# SCHEME from the env, so this works for either compose or helm targets.
[windows]
ci: _install
    #!pwsh
    $ErrorActionPreference = 'Stop'
    $env:HEADLESS      = 'true'
    $env:SLOW_MO       = '0'
    $env:STEP_PAUSE_MS = '0'
    npx playwright test

[unix]
ci: _install
    #!/usr/bin/env bash
    set -euo pipefail
    npx playwright install --with-deps chromium
    HEADLESS=true SLOW_MO=0 STEP_PAUSE_MS=0 npx playwright test
