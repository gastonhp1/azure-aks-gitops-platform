{{- define "pharmatrace.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 50 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 50 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Selector labels of one component: include "pharmatrace.selectorLabels" (list . "api") */}}
{{- define "pharmatrace.selectorLabels" -}}
{{- $root := index . 0 -}}
app.kubernetes.io/name: {{ $root.Chart.Name }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/component: {{ index . 1 }}
{{- end -}}

{{- define "pharmatrace.labels" -}}
{{- $root := index . 0 -}}
helm.sh/chart: {{ printf "%s-%s" $root.Chart.Name $root.Chart.Version }}
{{ include "pharmatrace.selectorLabels" . }}
app.kubernetes.io/version: {{ $root.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/part-of: pharmatrace
environment: {{ $root.Values.env }}
{{- end -}}

{{/* image@digest when a digest is set, image:tag otherwise */}}
{{- define "pharmatrace.image" -}}
{{- if .digest -}}
{{- printf "%s@%s" .repository .digest -}}
{{- else -}}
{{- printf "%s:%s" .repository (required (printf "set a tag or digest for %s" .repository) .tag) -}}
{{- end -}}
{{- end -}}

{{- define "pharmatrace.actorsSecret" -}}
{{- .Values.actors.existingSecret | default (printf "%s-actors" (include "pharmatrace.fullname" .)) -}}
{{- end -}}
