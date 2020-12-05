{{/*
Create full container image name by either hash or tag. It requires specific layout within the container scope
*/}}
{{- define "image.full" -}}
{{- if .pullByHash }}
{{- printf "%s/%s@sha256:%s" .imageRegistry .imageRepository .imageHash -}}
{{- else }}
{{- printf "%s/%s:%s" .imageRegistry .imageRepository .imageTag -}}
{{- end }}
{{- end -}}

{{/*
Create a pull policy based on whether we pull by hash or tag
*/}}
{{- define "image.pull" -}}
{{- if .pullByHash -}}IfNotPresent{{- else -}}Always{{- end -}}
{{- end -}}
