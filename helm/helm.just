set windows-shell := ["pwsh.exe", "-NoLogo", "-NoProfile", "-Command"]
set shell := ["bash", "-cu"]
set working-directory := '.'

release   := "auth2-proxy"
namespace := "auth2-proxy"

# Default: list available recipes.
default:
    @just --list --justfile {{justfile()}}

# Ensure ingress-nginx is installed in the cluster (no-op if already present).
# Docker Desktop's Kubernetes routes LoadBalancer services to localhost:80,
# which is why the default port is "" (= standard 80 plain / 443 TLS).
_ensure-ingress:
    #!/usr/bin/env bash
    set -euo pipefail
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
    helm repo update ingress-nginx >/dev/null
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx --create-namespace \
        --set controller.service.type=LoadBalancer \
        --set controller.ingressClassResource.default=true \
        --wait --timeout 5m

# Install/upgrade the chart and wait for rollout.
up host="127.0.0.1" port="": _ensure-ingress
    #!/usr/bin/env bash
    set -euo pipefail
    helm upgrade --install {{release}} ./oauth2-keycloak \
        --namespace {{namespace}} --create-namespace \
        --set host={{host}} \
        --set port={{port}} \
        --wait --timeout 5m
    kubectl -n {{namespace}} rollout status deploy --timeout=5m

# Uninstall the chart (leaves ingress-nginx in place).
down:
    helm uninstall {{release}} --namespace {{namespace}} --ignore-not-found
    kubectl delete namespace {{namespace}} --ignore-not-found

# Tear down ingress-nginx as well (e.g. before switching to the docker-compose stack).
nuke: down
    helm uninstall ingress-nginx --namespace ingress-nginx --ignore-not-found
    kubectl delete namespace ingress-nginx --ignore-not-found

# Show pod / ingress status.
status:
    @kubectl -n {{namespace}} get pods,svc,ingress

# Tail logs for one component (keycloak | oauth2-proxy | nginx).
logs component="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{component}}" ]; then
        kubectl -n {{namespace}} logs -l app.kubernetes.io/name=auth2-proxy --tail=100 -f
    else
        kubectl -n {{namespace}} logs -l app.kubernetes.io/component={{component}} --tail=100 -f
    fi

# Show the URLs to open.
urls host="127.0.0.1" port="":
    #!/usr/bin/env bash
    set -e
    base="http://{{host}}"
    if [ -n "{{port}}" ]; then base="$base:{{port}}"; fi
    echo "Landing (auth required): $base/"
    echo "Protected page:          $base/page"
    echo "Keycloak admin:          $base/auth/admin/"
    echo "oauth2-proxy sign-out:   $base/oauth/sign_out"

# Lint + render templates (offline check; render output suppressed).
[windows]
lint:
    #!pwsh
    helm lint ./oauth2-keycloak
    helm template {{release}} ./oauth2-keycloak | Out-Null

[unix]
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    helm lint ./oauth2-keycloak
    helm template {{release}} ./oauth2-keycloak >/dev/null
