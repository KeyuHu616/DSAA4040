#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source "${ROOT_DIR}/scripts/lib-kubeconfig.sh"

CLUSTER_RUNTIME="${1:-k3d}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"
K3S_INSTALL_URL="${K3S_INSTALL_URL:-https://get.k3s.io}"
CALICO_MANIFEST_URL="${CALICO_MANIFEST_URL:-https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/calico.yaml}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-dsaa4040}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
K3D_CLUSTER_NAME="${K3D_CLUSTER_NAME:-dsaa4040-lab}"
K3D_CLUSTER_CONTEXT="k3d-${K3D_CLUSTER_NAME}"
K3D_API_PORT="${K3D_API_PORT:-6550}"

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
  kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" wait --for=condition=Ready node --all --timeout=300s
}

normalize_requested_k3d_api_port() {
  local requested="$1"

  if [[ -z "${requested}" || "${requested}" == "auto" ]]; then
    return 0
  fi

  if [[ "${requested}" =~ ^[0-9]+$ ]]; then
    printf '127.0.0.1:%s\n' "${requested}"
    return 0
  fi

  printf '%s\n' "${requested}"
}

create_k3d_cluster() {
  local requested_api_port create_output

  requested_api_port="$(normalize_requested_k3d_api_port "${K3D_API_PORT}" || true)"
  if [[ -n "${requested_api_port}" ]]; then
    log "Creating k3d cluster ${K3D_CLUSTER_NAME} with requested API port ${requested_api_port}"
    if create_output="$(k3d cluster create "${K3D_CLUSTER_NAME}" --servers 1 --agents 1 --api-port "${requested_api_port}" --wait 2>&1)"; then
      printf '%s\n' "${create_output}"
      return 0
    fi

    printf '%s\n' "${create_output}" >&2
    if grep -Eqi 'ports are not available|/forwards/expose returned unexpected status: 500' <<< "${create_output}"; then
      log "Requested API port ${requested_api_port} is unavailable in this WSL2/Docker Desktop setup; retrying with an automatically assigned localhost port"
    else
      die "k3d cluster creation failed"
    fi
  else
    log "Creating k3d cluster ${K3D_CLUSTER_NAME} with an automatically assigned API port"
  fi

  k3d cluster create "${K3D_CLUSTER_NAME}" --servers 1 --agents 1 --wait
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
    create_k3d_cluster
  fi

  export KUBECONFIG="${HOME}/.kube/config"
  k3d kubeconfig merge "${K3D_CLUSTER_NAME}" --kubeconfig-merge-default --kubeconfig-switch-context >/dev/null
  export BOOTSTRAP_KUBECONFIG="${HOME}/.kube/config"
  normalize_loopback_server "${BOOTSTRAP_KUBECONFIG}" "${K3D_CLUSTER_CONTEXT}" >/dev/null

  log "Waiting for k3d cluster nodes to become Ready"
  wait_for_node_ready

  log "k3d bootstrap complete. Using K3s' embedded network policy controller for NetworkPolicy enforcement."
  log "For the rest of this workflow, use BOOTSTRAP_KUBECONFIG=${HOME}/.kube/config"
  log "Current cluster server: $(kubeconfig_current_server "${BOOTSTRAP_KUBECONFIG}")"
  kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" cluster-info
  kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" get nodes -o wide
}

bootstrap_k3s() {
  need_cmd curl

  if [[ "${EUID}" -ne 0 ]]; then
    die "k3s bootstrap requires root privileges and is not available in this no-sudo workflow. Use the default k3d runtime instead."
  fi

  log "Installing or refreshing K3s with Calico-compatible settings"
  curl -sfL "${K3S_INSTALL_URL}" | env \
    K3S_KUBECONFIG_MODE="644" \
    INSTALL_K3S_EXEC="server --flannel-backend=none --cluster-cidr=${POD_CIDR} --disable-network-policy --disable=traefik" \
    sh -

  if ! command -v kubectl >/dev/null 2>&1; then
    die "kubectl is not on PATH after K3s installation. Re-open the shell or export the directory containing kubectl before continuing."
  fi

  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  export BOOTSTRAP_KUBECONFIG="${KUBECONFIG}"

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
  export BOOTSTRAP_KUBECONFIG="${HOME}/.kube/config"

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
