{{- define "bookinfo.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "bookinfo.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    {{- include "bookinfo.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.containerPort }}
      protocol: TCP
{{- end -}}
