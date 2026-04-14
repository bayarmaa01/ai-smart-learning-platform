#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="eduai"
MONITORING_NS="monitoring"
ARGO_NS="eduai-argocd"
MODEL_NAME="${MODEL_NAME:-gemma4:31b}"

log() { printf "[INFO] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[WARN] %s\n" "$1"; }
fail() { printf "[ERROR] %s\n" "$1"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

retry() {
  local tries="$1"
  shift
  local i=1
  until "$@"; do
    if [ "$i" -ge "$tries" ]; then
      return 1
    fi
    sleep "$i"
    i=$((i + 1))
  done
}

ensure_minikube() {
  log "Ensuring Minikube is running"
  if ! minikube status >/dev/null 2>&1; then
    retry 3 minikube start --driver=docker --cpus=4 --memory=6144 --disk-size=25g
  fi
  kubectl config use-context minikube >/dev/null 2>&1 || true
  eval "$(minikube docker-env)"
  minikube addons enable ingress >/dev/null 2>&1 || true
  minikube addons enable metrics-server >/dev/null 2>&1 || true
  ok "Minikube ready"
}

build_images() {
  log "Building images into Minikube Docker"
  docker build -t eduai-backend:latest ./backend
  docker build \
    --build-arg VITE_API_URL="http://localhost:4200/api/v1" \
    --build-arg VITE_AI_URL="http://localhost:5200" \
    --build-arg VITE_BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --build-arg VITE_APP_VERSION="1.0.0" \
    -t eduai-frontend:latest ./frontend
  ok "Images built"
}

apply_manifests() {
  log "Applying Kubernetes manifests"
  kubectl apply -f k8s/namespace-fixed.yaml
  kubectl apply -f k8s/postgres-deployment-fixed.yaml
  kubectl apply -f k8s/redis-deployment-fixed.yaml
  kubectl apply -f k8s/backend-deployment-fixed.yaml
  kubectl apply -f k8s/frontend-deployment-fixed.yaml
  ok "Core manifests applied"
}

auto_debug_pods() {
  local ns="$1"
  local bad
  bad="$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | awk '$3 ~ /CrashLoopBackOff|Error|ImagePullBackOff|CreateContainerConfigError/ {print $1}')"
  if [ -n "$bad" ]; then
    warn "Detected failing pods in $ns. Capturing diagnostics."
    for pod in $bad; do
      kubectl describe pod "$pod" -n "$ns" >/tmp/"$pod"-describe.log 2>&1 || true
      kubectl logs "$pod" -n "$ns" --all-containers --tail=120 >/tmp/"$pod"-logs.log 2>&1 || true
      kubectl delete pod "$pod" -n "$ns" --wait=false >/dev/null 2>&1 || true
    done
  fi
}

wait_ready() {
  local ns="$1"
  local selector="$2"
  log "Waiting for $selector in $ns"
  if ! kubectl wait --for=condition=ready pod -n "$ns" -l "$selector" --timeout=240s; then
    auto_debug_pods "$ns"
    kubectl wait --for=condition=ready pod -n "$ns" -l "$selector" --timeout=240s
  fi
}

wait_rollout() {
  local ns="$1"
  local deployment="$2"
  local timeout="${3:-300s}"
  log "Waiting rollout for deployment/$deployment in $ns"
  if ! kubectl rollout status "deployment/$deployment" -n "$ns" --timeout="$timeout"; then
    warn "Rollout timeout for deployment/$deployment, collecting diagnostics"
    kubectl get pods -n "$ns" -l "app=$deployment" -o wide || true
    kubectl describe deployment "$deployment" -n "$ns" || true
    kubectl get pods -n "$ns" -l "app=$deployment" --no-headers 2>/dev/null | awk '$2 != "1/1" {print $1}' | while read -r pod; do
      [ -n "$pod" ] || continue
      kubectl describe pod "$pod" -n "$ns" >/tmp/"$pod"-describe.log 2>&1 || true
      kubectl logs "$pod" -n "$ns" --all-containers --tail=120 >/tmp/"$pod"-logs.log 2>&1 || true
      kubectl delete pod "$pod" -n "$ns" --wait=false >/dev/null 2>&1 || true
    done
    kubectl rollout status "deployment/$deployment" -n "$ns" --timeout="$timeout"
  fi
}

deploy_monitoring() {
  log "Deploying monitoring stack"
  kubectl create namespace "$MONITORING_NS" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f k8s/monitoring-stack.yaml || warn "monitoring-stack apply had warnings"
  ok "Monitoring applied"
}

deploy_argocd() {
  log "Deploying ArgoCD"
  kubectl apply -f k8s/argocd-complete.yaml || warn "argocd apply had warnings"
  ok "ArgoCD applied"
}

check_ollama() {
  if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    if curl -s http://localhost:11434/api/tags | grep -q "$MODEL_NAME"; then
      ok "Ollama model available: $MODEL_NAME"
    else
      warn "Model $MODEL_NAME not found locally. Pull with: ollama pull $MODEL_NAME"
    fi
  else
    warn "Ollama is not reachable on localhost:11434"
  fi
}

start_pf() {
  local ns="$1"
  local svc="$2"
  local map="$3"
  local tag="$4"
  nohup kubectl port-forward -n "$ns" "svc/$svc" "$map" >/tmp/"$tag"-port-forward.log 2>&1 &
  echo "$!" >/tmp/"$tag"-port-forward.pid
}

setup_port_forwards() {
  log "Starting port-forwards"
  pkill -f "kubectl port-forward" >/dev/null 2>&1 || true
  sleep 2
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
  ok "Port-forwards started"
}

validate_access() {
  log "Validating local endpoints"
  curl -fsS http://localhost:3200 >/dev/null
  curl -fsS http://localhost:4200/health >/dev/null
  curl -fsS http://localhost:4200/api/v1/health >/dev/null
  curl -fsS -X POST http://localhost:5200/api/chat -H "Content-Type: application/json" -d '{"message":"hello"}' >/dev/null || warn "AI endpoint returned warning"
  ok "Core local endpoints are reachable"
}

print_summary() {
  printf "\n"
  printf "Frontend:   http://localhost:3200\n"
  printf "Backend:    http://localhost:4200\n"
  printf "AI Chat:    http://localhost:5200/api/chat\n"
  printf "Grafana:    http://localhost:3004\n"
  printf "Prometheus: http://localhost:9093\n"
  printf "ArgoCD:     http://localhost:18080\n"
  printf "\n"
  printf "Health API: http://localhost:4200/api/v1/health\n"
  printf "Auth API:   http://localhost:4200/api/v1/auth/login\n"
  printf "Courses:    http://localhost:4200/api/v1/courses\n"
  printf "\n"
  printf "Platform deployment complete.\n"
}

main() {
  require_cmd minikube
  require_cmd kubectl
  require_cmd docker
  require_cmd curl

  check_ollama
  ensure_minikube
  build_images
  apply_manifests

  wait_ready "$NAMESPACE" "app=postgres"
  wait_ready "$NAMESPACE" "app=redis"
  wait_rollout "$NAMESPACE" "backend" "360s"
  wait_rollout "$NAMESPACE" "frontend" "360s"

  deploy_monitoring
  deploy_argocd
  auto_debug_pods "$MONITORING_NS"
  auto_debug_pods "$ARGO_NS"

  setup_port_forwards
  validate_access
  print_summary
}

main "$@"
