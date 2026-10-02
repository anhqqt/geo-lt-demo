{{- define "bookinfo.selectorLabels" -}}
app: {{ .Chart.Name }}
app.kubernetes.io/part-of: bookinfo
{{- end -}}

{{- define "bookinfo.labels" -}}
{{ include "bookinfo.selectorLabels" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}
