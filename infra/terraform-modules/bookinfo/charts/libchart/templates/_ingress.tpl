{{- define "bookinfo.ingress" -}}
{{- if .Values.ingress.enabled -}}
{{- $host := required "enabled Ingress requires a host" .Values.ingress.host -}}
{{- if or (gt (len $host) 253) (not (regexMatch "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$" $host)) -}}
{{- fail "Ingress host must be a DNS hostname without scheme, path or port" -}}
{{- end -}}
{{- range splitList "." $host -}}
{{- if gt (len .) 63 -}}{{- fail "Ingress DNS labels must not exceed 63 characters" -}}{{- end -}}
{{- end -}}
{{- range $key, $value := .Values.ingress.annotations -}}
{{- if not (kindIs "string" $value) -}}{{- fail "Ingress annotations must be strings" -}}{{- end -}}
{{- end -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bookinfo
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "bookinfo.labels" . | nindent 4 }}
  annotations:
    {{- toYaml .Values.ingress.annotations | nindent 4 }}
spec:
  ingressClassName: alb
  rules:
    - host: {{ $host | quote }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ .Chart.Name }}
                port:
                  number: {{ .Values.service.port }}
{{- end -}}
{{- end -}}
