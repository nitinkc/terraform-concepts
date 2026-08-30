{{/*
Expand the name of the chart.
*/}}
{{- define "acme-sampleapp-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "acme-sampleapp-backend.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "acme-sampleapp-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "acme-sampleapp-backend.labels" -}}
helm.sh/chart: {{ include "acme-sampleapp-backend.chart" . }}
{{ include "acme-sampleapp-backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
Selector labels
*/}}
{{- define "acme-sampleapp-backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "acme-sampleapp-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
Build the Cloud SQL DATABASE_URL for the backend container.
The IAM DB user is a GSA email without the .gserviceaccount.com suffix, and the
"@" in that email is percent-encoded so libpq does not truncate the userinfo part.
*/}}
{{- define "acme-sampleapp-backend.databaseUrl" -}}
{{- $user := .Values.cloudSql.user | replace "@" "%40" -}}
postgresql://{{ $user }}@127.0.0.1:5432/{{ .Values.cloudSql.database }}
{{- end }}
