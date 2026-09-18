{{- define "app-chart.name" -}}
sample-app
{{- end -}}

{{- define "app-chart.labels" -}}
app: {{ include "app-chart.name" . }}
chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
