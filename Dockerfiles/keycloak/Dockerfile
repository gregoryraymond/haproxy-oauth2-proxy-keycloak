# syntax=docker/dockerfile:1.6

# Stage 1 — pre-build the optimized server and seed the embedded H2 db with
# the realm so the running container has zero import work to do at boot.
FROM quay.io/keycloak/keycloak:24.0 AS warm

# Build-time config baked into `kc.sh build` below. These are all build_time
# options per Keycloak's config schema, so they must be set BEFORE the build.
#
#  * KC_CACHE=local    — single-node Infinispan; skips JGroups/UDP discovery
#                        which otherwise burns ~2s waiting for cluster peers.
#  * KC_HEALTH_ENABLED — exposes /auth/health/{ready,live} for healthchecks.
#  * KC_HTTP_ENABLED   — production-mode `start` refuses HTTP otherwise.
#  * KC_HTTP_RELATIVE_PATH — mount everything under /auth.
#  * KC_FEATURES_DISABLED — drop features the demo doesn't use. This trims
#    classes loaded into Metaspace at boot. Kept-on by default: oidc, admin
#    console, basic auth flows. Dropped:
#      account-api, account2, account3 — self-service /account UI
#      ciba                            — Client-Initiated Backchannel Auth
#      kerberos                        — SPNEGO / GSSAPI
#      web-authn                       — passkeys / FIDO2
#      docker                          — Docker registry auth
#      impersonation                   — admin-as-user feature
#      par                             — Pushed Authorization Requests
#      step-up-authentication          — re-auth for higher AAL
#      device-flow                     — RFC 8628 device code flow
#      authorization                   — fine-grained authz services
ENV KC_CACHE=local \
    KC_HEALTH_ENABLED=true \
    KC_HTTP_ENABLED=true \
    KC_HTTP_RELATIVE_PATH=/auth \
    KC_FEATURES_DISABLED=account-api,account2,account3,ciba,kerberos,web-authn,docker,impersonation,par,step-up-authentication,device-flow,authorization

COPY realm-export.json /opt/keycloak/data/import/realm-export.json

RUN /opt/keycloak/bin/kc.sh build && \
    /opt/keycloak/bin/kc.sh import \
        --file /opt/keycloak/data/import/realm-export.json

# Stage 2 — final image carrying the warmed binaries plus the seeded db.
# Re-state KC_HTTP_ENABLED here: production-mode `start` re-checks it at
# boot and refuses HTTP otherwise. The other build-time options
# (HTTP_RELATIVE_PATH, HEALTH_ENABLED) are already baked in.
FROM quay.io/keycloak/keycloak:24.0

ENV KC_HTTP_ENABLED=true

COPY --from=warm /opt/keycloak/lib/quarkus /opt/keycloak/lib/quarkus
COPY --from=warm /opt/keycloak/data        /opt/keycloak/data

# `--optimized` skips per-boot augmentation since `kc.sh build` already ran.
CMD ["start", "--optimized"]
