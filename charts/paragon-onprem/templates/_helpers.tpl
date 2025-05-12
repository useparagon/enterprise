{{/*
Define Parent Chart Global Variables for Paragon-Onprem
*/}}
{{/*
Account endpoint URL.
*/}}
{{- define "global.account.url" -}}
{{- printf "http://%s-account" .Release.Name -}}
{{- end -}}
{{/*
cache-replay endpoint URL.
*/}}
{{- define "global.cache-replay.url" -}}
{{- printf "http://%s-cache-replay" .Release.Name -}}
{{- end -}}
{{/*
Cerberus endpoint URL.
*/}}
{{- define "global.cerberus.url" -}}
{{- printf "http://%s-cerberus" .Release.Name -}}
{{- end -}}
{{/*
Chronos endpoint URL.
*/}}
{{- define "global.chronos.url" -}}
{{- printf "http://%s-chronos" .Release.Name -}}
{{- end -}}
{{/*
Connect endpoint URL.
*/}}
{{- define "global.connect.url" -}}
{{- printf "http://%s-connect" .Release.Name -}}
{{- end -}}
{{/*
Dashboard endpoint URL.
*/}}
{{- define "global.dashboard.url" -}}
{{- printf "http://%s-dashboard" .Release.Name -}}
{{- end -}}
{{/*
Hades endpoint URL.
*/}}
{{- define "global.hades.url" -}}
{{- printf "http://%s-hades" .Release.Name -}}
{{- end -}}
{{/*
Hercules endpoint URL.
*/}}
{{- define "global.hercules.url" -}}
{{- printf "http://%s-hercules" .Release.Name -}}
{{- end -}}
{{/*
Hermes API endpoint URL.
*/}}
{{- define "global.hermes.url" -}}
{{- printf "http://%s-hermes" .Release.Name -}}
{{- end -}}
{{/*
Minio API endpoint URL.
*/}}
{{- define "global.minio.url" -}}
{{- printf "http://%s-minio" .Release.Name -}}
{{- end -}}
{{/*
Passport API endpoint URL.
*/}}
{{- define "global.passport.url" -}}
{{- printf "http://%s-passport" .Release.Name -}}
{{- end -}}
{{/*
Plato API endpoint URL.
*/}}
{{- define "global.plato.url" -}}
{{- printf "http://%s-plato" .Release.Name -}}
{{- end -}}
{{/*
Pheme API endpoint URL.
*/}}
{{- define "global.pheme.url" -}}
{{- printf "http://%s-pheme" .Release.Name -}}
{{- end -}}
{{/*
Release API endpoint URL.
*/}}
{{- define "global.release.url" -}}
{{- printf "http://%s-release" .Release.Name -}}
{{- end -}}
{{/*
Zeus API endpoint URL.
*/}}
{{- define "global.zeus.url" -}}
{{- printf "http://%s-zeus" .Release.Name -}}
{{- end -}}
{{/*
worker-actionkit endpoint URL.
*/}}
{{- define "global.worker-actionkit.url" -}}
{{- printf "http://%s-worker-actionkit" .Release.Name -}}
{{- end -}}
{{/*
worker-actions endpoint URL.
*/}}
{{- define "global.worker-actions.url" -}}
{{- printf "http://%s-worker-actions" .Release.Name -}}
{{- end -}}
{{/*
worker-credentials endpoint URL.
*/}}
{{- define "global.worker-credentials.url" -}}
{{- printf "http://%s-worker-credentials" .Release.Name -}}
{{- end -}}
{{/*
worker-crons endpoint URL.
*/}}
{{- define "global.worker-crons.url" -}}
{{- printf "http://%s-worker-crons" .Release.Name -}}
{{- end -}}
{{/*
worker-deployments endpoint URL.
*/}}
{{- define "global.worker-deployments.url" -}}
{{- printf "http://%s-worker-deployments" .Release.Name -}}
{{- end -}}
{{/*
worker-proxy endpoint URL.
*/}}
{{- define "global.worker-proxy.url" -}}
{{- printf "http://%s-worker-proxy" .Release.Name -}}
{{- end -}}
{{/*
worker-triggers endpoint URL.
*/}}
{{- define "global.worker-triggers.url" -}}
{{- printf "http://%s-worker-triggers" .Release.Name -}}
{{- end -}}
{{/*
worker-workflows endpoint URL.
*/}}
{{- define "global.worker-workflows.url" -}}
{{- printf "http://%s-worker-workflows" .Release.Name -}}
{{- end -}}