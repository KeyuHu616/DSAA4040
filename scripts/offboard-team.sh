#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TEAM="${1:?usage: offboard-team.sh <team-name>}"

default_bootstrap_kubeconfig() {
  if [[ -n "${BOOTSTRAP_KUBECONFIG:-}" ]]; then
    printf '%s\n' "${BOOTSTRAP_KUBECONFIG}"
  elif [[ -n "${KUBECONFIG:-}" && "${KUBECONFIG}" != *:* && -f "${KUBECONFIG}" ]]; then
    printf '%s\n' "${KUBECONFIG}"
  elif [[ -f "${HOME}/.kube/config" ]]; then
    printf '%s\n' "${HOME}/.kube/config"
  elif [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
    printf '%s\n' "/etc/rancher/k3s/k3s.yaml"
  else
    printf '%s\n' "${HOME}/.kube/config"
  fi
}

BOOTSTRAP_KUBECONFIG="$(default_bootstrap_kubeconfig)"

log() {
  printf '[offboard] %s\n' "$*"
}

die() {
  printf '[offboard] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

[[ "${TEAM}" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || die "team name must be a valid DNS-1123 label"
[[ -f "${BOOTSTRAP_KUBECONFIG}" ]] || die "bootstrap kubeconfig not found at ${BOOTSTRAP_KUBECONFIG}"

need_cmd kubectl

for role in developer viewer; do
  USERNAME="${TEAM}-${role}"
  log "Deleting CSR ${USERNAME} if it exists"
  kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" delete csr "${USERNAME}" --ignore-not-found >/dev/null 2>&1 || true
done

log "Deleting namespace ${TEAM}"
kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" delete namespace "${TEAM}" --ignore-not-found --wait=true --timeout=300s || true

log "Cleaning local kubeconfig artifacts for ${TEAM}"
rm -f "artifacts/kubeconfigs/${TEAM}-developer.kubeconfig" \
      "artifacts/kubeconfigs/${TEAM}-viewer.kubeconfig"
rm -rf "artifacts/kubeconfigs/.generated/${TEAM}-developer" \
       "artifacts/kubeconfigs/.generated/${TEAM}-viewer"

log "Offboarding complete for ${TEAM}"
