{{- define "oauth2-keycloak.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "oauth2-keycloak.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "oauth2-keycloak.labels" -}}
app.kubernetes.io/name: {{ include "oauth2-keycloak.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Per-component selector labels.
Usage: {{ include "oauth2-keycloak.componentSelectorLabels" (dict "ctx" . "component" "keycloak") }}
*/}}
{{- define "oauth2-keycloak.componentSelectorLabels" -}}
app.kubernetes.io/name: {{ include "oauth2-keycloak.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* http or https. */}}
{{- define "oauth2-keycloak.scheme" -}}
{{- if .Values.tls.enabled -}}https{{- else -}}http{{- end -}}
{{- end -}}

{{/* host[:port] — port appended only when explicitly set. */}}
{{- define "oauth2-keycloak.hostPort" -}}
{{- if .Values.port -}}
{{ .Values.host }}:{{ .Values.port }}
{{- else -}}
{{ .Values.host }}
{{- end -}}
{{- end -}}

{{/* scheme://host[:port] — public base URL the browser hits. */}}
{{- define "oauth2-keycloak.publicUrl" -}}
{{ include "oauth2-keycloak.scheme" . }}://{{ include "oauth2-keycloak.hostPort" . }}
{{- end -}}

{{/*
Hostname for the Ingress rule. Returns empty string when only an IP is
available — k8s Ingress validation rejects raw IPs in `host:`, so the rule
must omit it (matches any host). Set `ingress.hostOverride` to force a
specific name (e.g. when using nip.io or a hosts-file entry).
*/}}
{{- define "oauth2-keycloak.ingressHost" -}}
{{- if .Values.ingress.hostOverride -}}
{{- .Values.ingress.hostOverride -}}
{{- else if not (regexMatch "^[0-9.]+$" .Values.host) -}}
{{- .Values.host -}}
{{- end -}}
{{- end -}}
