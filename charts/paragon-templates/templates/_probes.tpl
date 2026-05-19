{{/*
Render a Kubernetes container probe (httpGet) for liveness, readiness, or startup.

Usage:
  livenessProbe:
    {{- include "probes.httpGet" (dict "root" $ "type" "liveness") | nindent 12 }}
  readinessProbe:
    {{- include "probes.httpGet" (dict "root" $ "type" "readiness") | nindent 12 }}
  startupProbe:
    {{- include "probes.httpGet" (dict "root" $ "type" "startup") | nindent 12 }}

Path resolution (in order):
  liveness  -> .Values.ingress.livecheck_path    | .Values.ingress.healthcheck_path | "/healthz"
  readiness -> .Values.ingress.readycheck_path   | .Values.ingress.healthcheck_path | "/healthz"
  startup   -> .Values.ingress.startupcheck_path | .Values.ingress.healthcheck_path | "/healthz"

Per-probe overrides (any subset) via .Values.probes.<type>.<field>:
  initialDelaySeconds, periodSeconds, timeoutSeconds, failureThreshold, successThreshold

Defaults preserve historical chart behavior:
  liveness, readiness -> initialDelaySeconds: 10, periodSeconds: 10, timeoutSeconds: 5, failureThreshold: 3
  startup             ->                          periodSeconds: 10, timeoutSeconds: 5, failureThreshold: 30
*/}}
{{- define "probes.httpGet" -}}
{{- $root := .root -}}
{{- $type := .type -}}
{{- $ingress := $root.Values.ingress | default dict -}}
{{- $defaultPath := $ingress.healthcheck_path | default "/healthz" -}}
{{- $path := $defaultPath -}}
{{- if eq $type "liveness" -}}
{{- $path = $ingress.livecheck_path | default $defaultPath -}}
{{- else if eq $type "readiness" -}}
{{- $path = $ingress.readycheck_path | default $defaultPath -}}
{{- else if eq $type "startup" -}}
{{- $path = $ingress.startupcheck_path | default $defaultPath -}}
{{- end -}}
{{- $cfg := dict -}}
{{- if and $root.Values.probes (kindIs "map" $root.Values.probes) (hasKey $root.Values.probes $type) -}}
{{- $cfg = index $root.Values.probes $type | default dict -}}
{{- end -}}
{{- $isStartup := eq $type "startup" -}}
httpGet:
  path: {{ $path }}
  port: http
{{- if hasKey $cfg "initialDelaySeconds" }}
initialDelaySeconds: {{ int (index $cfg "initialDelaySeconds") }}
{{- else if not $isStartup }}
initialDelaySeconds: 10
{{- end }}
periodSeconds: {{ if hasKey $cfg "periodSeconds" }}{{ int (index $cfg "periodSeconds") }}{{ else }}10{{ end }}
timeoutSeconds: {{ if hasKey $cfg "timeoutSeconds" }}{{ int (index $cfg "timeoutSeconds") }}{{ else }}5{{ end }}
{{- if hasKey $cfg "successThreshold" }}
successThreshold: {{ int (index $cfg "successThreshold") }}
{{- end }}
failureThreshold: {{ if hasKey $cfg "failureThreshold" }}{{ int (index $cfg "failureThreshold") }}{{ else if $isStartup }}30{{ else }}3{{ end }}
{{- end -}}
