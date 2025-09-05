{{/*
Expand the name of the chart.
*/}}
{{- define "redis-stream-exporter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "redis-stream-exporter.fullname" -}}
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
{{- define "redis-stream-exporter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "redis-stream-exporter.labels" -}}
helm.sh/chart: {{ include "redis-stream-exporter.chart" . }}
{{ include "redis-stream-exporter.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "redis-stream-exporter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "redis-stream-exporter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "redis-stream-exporter.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "redis-stream-exporter.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the config map
*/}}
{{- define "redis-stream-exporter.configMapName" -}}
{{- printf "%s-config" (include "redis-stream-exporter.fullname" .) }}
{{- end }}

{{/*
Create the name of the secret
*/}}
{{- define "redis-stream-exporter.secretName" -}}
{{- printf "%s-secret" (include "redis-stream-exporter.fullname" .) }}
{{- end }}

{{/*
Create the name of the service
*/}}
{{- define "redis-stream-exporter.serviceName" -}}
{{- printf "%s-service" (include "redis-stream-exporter.fullname" .) }}
{{- end }}

{{/*
Create the name of the deployment
*/}}
{{- define "redis-stream-exporter.deploymentName" -}}
{{- printf "%s-deployment" (include "redis-stream-exporter.fullname" .) }}
{{- end }}

{{/*
Create the name of the service monitor
*/}}
{{- define "redis-stream-exporter.serviceMonitorName" -}}
{{- printf "%s-servicemonitor" (include "redis-stream-exporter.fullname" .) }}
{{- end }}

{{/*
Create the name of the horizontal pod autoscaler
*/}}
{{- define "redis-stream-exporter.hpaName" -}}
{{- printf "%s-hpa" (include "redis-stream-exporter.fullname" .) }}
{{- end }}
