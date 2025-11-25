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

{{- define "paragon.serviceInputs.service" -}}
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

{{- define "paragon.serviceInputs.secretKeys" -}}
{{- $service := fromJson (include "paragon.serviceInputs.service" .) -}}
{{- $keys := $service.secretKeys | default (list) -}}
{{- toYaml $keys -}}
{{- end -}}

{{- define "paragon.serviceInputs.envKeys" -}}
{{- $service := fromJson (include "paragon.serviceInputs.service" .) -}}
{{- $keys := $service.envKeys | default (list) -}}
{{- toYaml $keys -}}
{{- end -}}
