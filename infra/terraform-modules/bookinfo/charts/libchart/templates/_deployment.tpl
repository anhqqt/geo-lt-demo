{{- define "bookinfo.deployment" -}}
{{- include "bookinfo.validate" . -}}
{{- $resources := deepCopy .Values.resources -}}
{{- $limits := $resources.limits | default dict -}}
{{- range $name, $quantity := $limits -}}
{{- if eq $quantity nil -}}
{{- $_ := unset $limits $name -}}
{{- end -}}
{{- end -}}
{{- if empty $limits -}}
{{- $_ := unset $resources "limits" -}}
{{- end -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "bookinfo.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  revisionHistoryLimit: {{ .Values.revisionHistoryLimit }}
  progressDeadlineSeconds: {{ .Values.progressDeadlineSeconds }}
  strategy:
    {{- toYaml .Values.deploymentStrategy | nindent 4 }}
  selector:
    matchLabels:
      {{- include "bookinfo.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "bookinfo.selectorLabels" . | nindent 8 }}
    spec:
      automountServiceAccountToken: false
      enableServiceLinks: false
      nodeSelector:
        {{- toYaml .Values.nodeSelector | nindent 8 }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: {{ .Values.image | quote }}
          imagePullPolicy: {{ .Values.imagePullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort }}
              protocol: TCP
          env:
            {{- range $name, $value := .Values.environment }}
            - name: {{ $name }}
              value: {{ $value | quote }}
            {{- end }}
          resources:
            {{- toYaml $resources | nindent 12 }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          startupProbe:
            {{- toYaml .Values.startupProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
{{- end -}}
