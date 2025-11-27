{{/*
Helpers to load service metadata from files/service-inputs.json so charts can derive
env/secret key lists without hardcoding them in values files.

Each subchart has its own files/service-inputs.json containing only that service's data.
*/}}

{{- define "global.serviceInputs" -}}
{{- $root := .root | default . -}}
{{- /* Load the service-inputs.json - it contains this service's data */}}
{{- $raw := $root.Files.Get "files/service-inputs.json" -}}
{{- $service := fromJson $raw -}}
{{- toJson $service -}}
{{- end -}}
