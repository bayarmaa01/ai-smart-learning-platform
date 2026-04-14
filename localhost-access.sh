#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="eduai"
MONITORING_NS="monitoring"
ARGO_NS="eduai-argocd"

log() { printf "[INFO] %s\n" "$1"; }

start_pf() {
  local ns="$1"
  local svc="$2"
  local mapping="$3"
  local tag="$4"
  nohup kubectl port-forward -n "$ns" "svc/$svc" "$mapping" >/tmp/"$tag"-port-forward.log 2>&1 &
  echo "$!" >/tmp/"$tag"-port-forward.pid
}

cleanup() {
  log "Stopping port-forwards"
  pkill -f "kubectl port-forward" >/dev/null 2>&1 || true
  rm -f /tmp/*-port-forward.pid
}

trap cleanup INT TERM

pkill -f "kubectl port-forward" >/dev/null 2>&1 || true
sleep 2

log "Starting localhost access forwards"
start_pf "$NAMESPACE" "frontend" "3200:3000" "eduai-frontend"
start_pf "$NAMESPACE" "backend" "4200:5000" "eduai-backend"
start_pf "$NAMESPACE" "backend" "5200:5000" "eduai-ai"
start_pf "$MONITORING_NS" "kube-prometheus-grafana" "3004:3000" "eduai-grafana" || true
start_pf "$MONITORING_NS" "grafana" "3004:3000" "eduai-grafana" || true
start_pf "$MONITORING_NS" "kube-prometheus-prometheus" "9093:9090" "eduai-prometheus" || true
start_pf "$MONITORING_NS" "prometheus" "9093:9090" "eduai-prometheus" || true
start_pf "$ARGO_NS" "argocd-server" "18080:8080" "eduai-argocd" || true
start_pf "argocd" "argocd-server" "18080:8080" "eduai-argocd" || true

sleep 4

printf "\nFrontend:   http://localhost:3200\n"
printf "Backend:    http://localhost:4200\n"
printf "AI Chat:    http://localhost:5200/api/chat\n"
printf "Grafana:    http://localhost:3004\n"
printf "Prometheus: http://localhost:9093\n"
printf "ArgoCD:     http://localhost:18080\n\n"
printf "Press Ctrl+C to stop.\n"

wait
