#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source "${ROOT_DIR}/scripts/lib-kubeconfig.sh"

BOOTSTRAP_KUBECONFIG="$(default_bootstrap_kubeconfig)"
LIVE_TOOLING_READY=true
LIVE_CLUSTER_AVAILABLE=false
DOCKER_ACCESS=false
K3D_CLUSTER_CONTEXT="${K3D_CLUSTER_CONTEXT:-k3d-dsaa4040-lab}"

report() {
  local level="$1"
  shift
  printf '[env][%s] %s\n' "${level}" "$*"
}

fix_k3d_kubeconfig_server() {
  local current_server normalized_server

  current_server="$(kubeconfig_current_server "${BOOTSTRAP_KUBECONFIG}")"
  normalized_server="$(normalize_loopback_server "${BOOTSTRAP_KUBECONFIG}" "${K3D_CLUSTER_CONTEXT}")"

  if [[ -n "${current_server}" && "${current_server}" != "${normalized_server}" ]]; then
    report PASS "rewrote ${K3D_CLUSTER_CONTEXT} server from ${current_server} to ${normalized_server}"
  fi
}

check_command() {
  local name="$1"

  if command -v "${name}" >/dev/null 2>&1; then
    report PASS "${name} found at $(command -v "${name}")"
    return 0
  fi

  report WARN "${name} is not available"
  LIVE_TOOLING_READY=false
  return 1
}

report INFO "Repository root: ${ROOT_DIR}"

if command -v conda >/dev/null 2>&1; then
  report PASS "conda found at $(command -v conda)"
else
  report WARN "conda is not available"
  LIVE_TOOLING_READY=false
fi

if [[ "${CONDA_DEFAULT_ENV:-}" == "cloud" ]]; then
  report PASS "conda environment 'cloud' is active"
else
  report WARN "conda environment 'cloud' is not active"
  LIVE_TOOLING_READY=false
fi

for cmd in bash python3 kubectl openssl curl wget; do
  check_command "${cmd}" || true
done

if command -v docker >/dev/null 2>&1; then
  if docker ps >/dev/null 2>&1; then
    DOCKER_ACCESS=true
    report PASS "docker daemon is reachable from this shell"
  else
    DOCKER_OUTPUT="$(docker ps 2>&1 || true)"
    report WARN "docker is installed but inaccessible: ${DOCKER_OUTPUT}"
    LIVE_TOOLING_READY=false
  fi
else
  report WARN "docker is not available"
  LIVE_TOOLING_READY=false
fi

if command -v k3d >/dev/null 2>&1; then
  report PASS "k3d found at $(command -v k3d)"
else
  report WARN "k3d is not available"
  LIVE_TOOLING_READY=false
fi

if command -v kubectl >/dev/null 2>&1; then
  if [[ -f "${BOOTSTRAP_KUBECONFIG}" ]]; then
    report PASS "bootstrap kubeconfig found at ${BOOTSTRAP_KUBECONFIG}"
    fix_k3d_kubeconfig_server
    report INFO "current context: $(kubeconfig_current_context "${BOOTSTRAP_KUBECONFIG}")"
    report INFO "current cluster: $(kubeconfig_current_cluster "${BOOTSTRAP_KUBECONFIG}")"
    report INFO "current server: $(kubeconfig_current_server "${BOOTSTRAP_KUBECONFIG}")"
    if cluster_reachable "${BOOTSTRAP_KUBECONFIG}"; then
      LIVE_CLUSTER_AVAILABLE=true
      report PASS "a live Kubernetes cluster is reachable from ${BOOTSTRAP_KUBECONFIG}"
    else
      report WARN "no reachable Kubernetes cluster was found via ${BOOTSTRAP_KUBECONFIG}"
    fi
  else
    report WARN "bootstrap kubeconfig not found at ${BOOTSTRAP_KUBECONFIG}"
  fi
fi

if [[ "${DOCKER_ACCESS}" != true ]]; then
  report WARN "Live Kubernetes validation cannot be run on this server because Docker access is unavailable or denied."
elif [[ "${LIVE_TOOLING_READY}" == true && "${LIVE_CLUSTER_AVAILABLE}" == true ]]; then
  report PASS "This machine is ready for live Kubernetes validation."
elif [[ "${LIVE_TOOLING_READY}" == true ]]; then
  report INFO "Tooling is present for live validation, but no running Kubernetes cluster is currently reachable."
else
  report INFO "Static validation can run here, but the full WSL2 live-validation workflow is not ready yet."
fi

printf '[env] LIVE_TOOLING_READY=%s\n' "${LIVE_TOOLING_READY}"
printf '[env] LIVE_CLUSTER_AVAILABLE=%s\n' "${LIVE_CLUSTER_AVAILABLE}"
