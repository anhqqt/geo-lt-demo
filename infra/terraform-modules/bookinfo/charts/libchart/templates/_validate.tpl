{{- define "bookinfo.validate" -}}
{{- if or (not (regexMatch "^[a-zA-Z0-9][a-zA-Z0-9._:/-]*@sha256:[a-f0-9]{64}$" .Values.image)) (contains ":latest@" .Values.image) -}}
{{- fail "image must contain an immutable sha256 digest and must not use latest" -}}
{{- end -}}
{{- range $budget := list .Values.resources.requests -}}
{{- if not (regexMatch "^[1-9][0-9]*m$" (toString $budget.cpu)) -}}
{{- fail "resource CPU must use positive integer millicores, for example 50m" -}}
{{- end -}}
{{- if not (regexMatch "^[1-9][0-9]*Mi$" (toString $budget.memory)) -}}
{{- fail "resource memory must use positive integer MiB, for example 64Mi" -}}
{{- end -}}
{{- end -}}
{{- end -}}
