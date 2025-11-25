{{/*
Helpers to load service metadata from files/service-inputs.json so charts can derive
env/secret key lists without hardcoding them in values files.
*/}}

{{- define "paragon.serviceInputs.serviceName" -}}
{{- if and .service (ne .service "") -}}
{{- .service -}}
{{- else -}}
{{- .root.Chart.Name -}}
{{- end -}}
{{- end -}}

{{- define "paragon.serviceInputs.data" -}}
{{- $root := .root | default . -}}
{{- $serviceName := include "paragon.serviceInputs.serviceName" . -}}
{{- $raw := $root.Files.Get "files/service-inputs.json" -}}
{{- $inputs := fromJson $raw -}}
{{- $match := dict "service" nil -}}
{{- range $svc := $inputs.services }}
  {{- if and (not $match.service) (eq $svc.name $serviceName) }}
    {{- $_ := set $match "service" $svc -}}
  {{- end -}}
{{- end -}}
{{- $service := $match.service | default (dict "name" $serviceName "secretKeys" (list) "envKeys" (list)) -}}
{{- toJson $service -}}
{{- end -}}
