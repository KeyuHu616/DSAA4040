#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CLUSTER_RUNTIME="${1:-k3d}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"
K3S_INSTALL_URL="${K3S_INSTALL_URL:-https://get.k3s.io}"
CALICO_MANIFEST_URL="${CALICO_MANIFEST_URL:-https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/calico.yaml}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-dsaa4040}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
K3D_CLUSTER_NAME="${K3D_CLUSTER_NAME:-dsaa4040-lab}"
K3D_CLUSTER_CONTEXT="k3d-${K3D_CLUSTER_NAME}"
K3D_API_PORT="${K3D_API_PORT:-127.0.0.1:6550}"

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

log() {
  printf '[bootstrap] %s\n' "$*"
}

die() {
  printf '[bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

wait_for_node_ready() {
  kubectl wait --for=condition=Ready node --all --timeout=300s
}

bootstrap_k3d() {
  need_cmd docker
  need_cmd k3d
  need_cmd kubectl

  if ! docker ps >/dev/null 2>&1; then
    die "docker is installed but not usable from this shell. In WSL2, start Docker Desktop and enable WSL integration for this Ubuntu distribution before running live Kubernetes validation."
  fi

  if k3d kubeconfig get "${K3D_CLUSTER_NAME}" >/dev/null 2>&1; then
    log "Using existing k3d cluster ${K3D_CLUSTER_NAME}"
  else
    log "Creating k3d cluster ${K3D_CLUSTER_NAME}"
    k3d cluster create "${K3D_CLUSTER_NAME}" \
      --servers 1 \
      --agents 1 \
      --api-port "${K3D_API_PORT}" \
      --wait
  fi

  export KUBECONFIG="${HOME}/.kube/config"
  k3d kubeconfig merge "${K3D_CLUSTER_NAME}" --kubeconfig-merge-default --kubeconfig-switch-context >/dev/null
  kubectl config --kubeconfig "${HOME}/.kube/config" set-cluster "${K3D_CLUSTER_CONTEXT}" --server="https://${K3D_API_PORT}" >/dev/null
  export BOOTSTRAP_KUBECONFIG="${HOME}/.kube/config"

  log "Waiting for k3d cluster nodes to become Ready"
  wait_for_node_ready

  log "k3d bootstrap complete. Using K3s' embedded network policy controller for NetworkPolicy enforcement."
  log "For the rest of this workflow, use BOOTSTRAP_KUBECONFIG=${HOME}/.kube/config"
  kubectl cluster-info
  kubectl get nodes -o wide
}

bootstrap_k3s() {
  need_cmd curl
  need_cmd "${SUDO[0]:-true}"

  log "Installing or refreshing K3s with Calico-compatible settings"
  curl -sfL "${K3S_INSTALL_URL}" | "${SUDO[@]}" env \
    K3S_KUBECONFIG_MODE="644" \
    INSTALL_K3S_EXEC="server --flannel-backend=none --cluster-cidr=${POD_CIDR} --disable-network-policy --disable=traefik" \
    sh -

  if ! command -v kubectl >/dev/null 2>&1; then
    die "kubectl is not on PATH after K3s installation. Re-open the shell or export the directory containing kubectl before continuing."
  fi

  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  log "Waiting for the control-plane node to become Ready"
  wait_for_node_ready

  log "Installing Calico from ${CALICO_MANIFEST_URL}"
  kubectl apply -f "${CALICO_MANIFEST_URL}"

  log "Waiting for Calico components"
  kubectl rollout status daemonset/calico-node -n kube-system --timeout=300s
  kubectl rollout status deployment/calico-kube-controllers -n kube-system --timeout=300s
  kubectl get nodes -o wide

  log "K3s bootstrap complete. Admin kubeconfig: /etc/rancher/k3s/k3s.yaml"
}

bootstrap_minikube() {
  need_cmd minikube
  need_cmd kubectl

  log "Starting single-node Minikube with Calico enforcement"
  minikube start \
    --profile "${MINIKUBE_PROFILE}" \
    --nodes 1 \
    --driver "${MINIKUBE_DRIVER}" \
    --cni calico

  minikube update-context -p "${MINIKUBE_PROFILE}"

  log "Waiting for the node to become Ready"
  wait_for_node_ready

  log "Waiting for Calico components"
  kubectl rollout status daemonset/calico-node -n kube-system --timeout=300s
  kubectl get nodes -o wide

  log "Minikube bootstrap complete. Use BOOTSTRAP_KUBECONFIG=\$HOME/.kube/config"
}

case "${CLUSTER_RUNTIME}" in
  k3d)
    bootstrap_k3d
    ;;
  k3s)
    bootstrap_k3s
    ;;
  minikube)
    bootstrap_minikube
    ;;
  *)
    die "unsupported runtime '${CLUSTER_RUNTIME}'. Use 'k3d', 'k3s', or 'minikube'."
    ;;
esac
