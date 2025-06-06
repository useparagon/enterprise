{{/*
Expand the name of the chart.
*/}}
{{- define "worker-crons.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "worker-crons.fullname" -}}
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
{{- define "worker-crons.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "worker-crons.labels" -}}
helm.sh/chart: {{ include "worker-crons.chart" . }}
{{ include "worker-crons.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "worker-crons.selectorLabels" -}}
app.kubernetes.io/name: {{ include "worker-crons.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "worker-crons.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "worker-crons.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate the ingress host
*/}}
{{- define "worker-crons.ingressHost" -}}
{{- if .Values.ingress.host }}
{{- if .Values.global.env.PARAGON_DOMAIN }}
{{- printf "%s.%s" .Values.ingress.host .Values.global.env.PARAGON_DOMAIN }}
{{- else }}
{{- .Values.ingress.host }}
{{- end }}
{{- else }}
{{- if .Values.global.env.PARAGON_DOMAIN }}
{{- printf "%s.%s" .Chart.Name .Values.global.env.PARAGON_DOMAIN }}
{{- else }}
{{- .Chart.Name }}
{{- end }}
{{- end }}
{{- end }}
