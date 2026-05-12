#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source "${ROOT_DIR}/scripts/lib-kubeconfig.sh"

TEAM="${1:?usage: onboard-team.sh <team-name>}"

BOOTSTRAP_KUBECONFIG="$(default_bootstrap_kubeconfig)"

log() {
  printf '[onboard] %s\n' "$*"
}

die() {
  printf '[onboard] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

render_template() {
  local template="$1"
  sed "s|__TEAM__|${TEAM}|g" "${template}"
}

apply_template() {
  local template="$1"
  render_template "${template}" | kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" apply -f -
}

[[ "${TEAM}" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || die "team name must be a valid DNS-1123 label"
[[ -f "${BOOTSTRAP_KUBECONFIG}" ]] || die "bootstrap kubeconfig not found at ${BOOTSTRAP_KUBECONFIG}"

need_cmd kubectl
need_cmd sed
need_cmd openssl
need_cmd base64

log "Applying namespace and Pod Security labels for ${TEAM}"
apply_template manifests/podsecurity/namespace.yaml.tpl

log "Applying tenant RBAC for ${TEAM}"
apply_template manifests/rbac/developer-role.yaml.tpl
apply_template manifests/rbac/developer-rolebinding.yaml.tpl
apply_template manifests/rbac/viewer-rolebinding.yaml.tpl

log "Applying resource isolation for ${TEAM}"
apply_template manifests/quota/resourcequota.yaml.tpl
apply_template manifests/limitrange/limitrange.yaml.tpl

log "Applying network isolation for ${TEAM}"
apply_template manifests/netpol/default-deny-ingress.yaml.tpl
apply_template manifests/netpol/allow-same-namespace-ingress.yaml.tpl

log "Generating kubeconfigs for ${TEAM}-developer and ${TEAM}-viewer"
scripts/issue-user-kubeconfig.sh "${TEAM}" developer
scripts/issue-user-kubeconfig.sh "${TEAM}" viewer

log "Onboarding complete for ${TEAM}"
log "Developer kubeconfig: artifacts/kubeconfigs/${TEAM}-developer.kubeconfig"
log "Viewer kubeconfig: artifacts/kubeconfigs/${TEAM}-viewer.kubeconfig"
