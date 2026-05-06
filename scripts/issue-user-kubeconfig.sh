#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TEAM="${1:?usage: issue-user-kubeconfig.sh <team> <developer|viewer>}"
ROLE="${2:?usage: issue-user-kubeconfig.sh <team> <developer|viewer>}"

default_bootstrap_kubeconfig() {
  if [[ -n "${BOOTSTRAP_KUBECONFIG:-}" ]]; then
    printf '%s\n' "${BOOTSTRAP_KUBECONFIG}"
  elif [[ -n "${KUBECONFIG:-}" && "${KUBECONFIG}" != *:* && -f "${KUBECONFIG}" ]]; then
    printf '%s\n' "${KUBECONFIG}"
  else
    printf '%s\n' "${HOME}/.kube/config"
  fi
}

BOOTSTRAP_KUBECONFIG="$(default_bootstrap_kubeconfig)"
USERNAME="${TEAM}-${ROLE}"
NAMESPACE="${TEAM}"
SUBJECT_GROUP="${TEAM}"
OUTPUT_KUBECONFIG="artifacts/kubeconfigs/${USERNAME}.kubeconfig"
USER_DIR="artifacts/kubeconfigs/.generated/${USERNAME}"
CSR_NAME="${USERNAME}"

log() {
  printf '[kubeconfig] %s\n' "$*"
}

die() {
  printf '[kubeconfig] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

case "${ROLE}" in
  developer|viewer)
    ;;
  *)
    die "role must be developer or viewer"
    ;;
esac

[[ -f "${BOOTSTRAP_KUBECONFIG}" ]] || die "bootstrap kubeconfig not found at ${BOOTSTRAP_KUBECONFIG}"

need_cmd kubectl
need_cmd openssl
need_cmd base64

mkdir -p "${USER_DIR}"

log "Generating private key and CSR for ${USERNAME}"
openssl genrsa -out "${USER_DIR}/${USERNAME}.key" 3072 >/dev/null 2>&1
openssl req -new \
  -key "${USER_DIR}/${USERNAME}.key" \
  -out "${USER_DIR}/${USERNAME}.csr" \
  -subj "/CN=${USERNAME}/O=${SUBJECT_GROUP}" >/dev/null 2>&1

CSR_B64="$(base64 < "${USER_DIR}/${USERNAME}.csr" | tr -d '\n')"
CSR_MANIFEST="${USER_DIR}/${USERNAME}-csr.yaml"

cat > "${CSR_MANIFEST}" <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  request: ${CSR_B64}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000
  usages:
    - client auth
EOF

log "Submitting CSR ${CSR_NAME}"
kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" delete csr "${CSR_NAME}" --ignore-not-found >/dev/null 2>&1 || true
kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" apply -f "${CSR_MANIFEST}" >/dev/null
kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" certificate approve "${CSR_NAME}" >/dev/null

for _ in $(seq 1 30); do
  CERT_B64="$(kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" get csr "${CSR_NAME}" -o jsonpath='{.status.certificate}')"
  if [[ -n "${CERT_B64}" ]]; then
    break
  fi
  sleep 1
done

[[ -n "${CERT_B64:-}" ]] || die "timed out waiting for signed certificate for ${CSR_NAME}"

printf '%s' "${CERT_B64}" | base64 -d > "${USER_DIR}/${USERNAME}.crt"

CLUSTER_NAME="$(kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" config view --raw --minify -o jsonpath='{.clusters[0].name}')"
SERVER="$(kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" config view --raw --minify -o jsonpath='{.clusters[0].cluster.server}')"
CA_DATA="$(kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"

[[ -n "${CLUSTER_NAME}" ]] || die "failed to determine cluster name from ${BOOTSTRAP_KUBECONFIG}"
[[ -n "${SERVER}" ]] || die "failed to determine cluster server from ${BOOTSTRAP_KUBECONFIG}"
[[ -n "${CA_DATA}" ]] || die "failed to determine cluster CA data from ${BOOTSTRAP_KUBECONFIG}"

printf '%s' "${CA_DATA}" | base64 -d > "${USER_DIR}/ca.crt"

log "Writing kubeconfig ${OUTPUT_KUBECONFIG}"
kubectl config --kubeconfig "${OUTPUT_KUBECONFIG}" set-cluster "${CLUSTER_NAME}" \
  --server="${SERVER}" \
  --certificate-authority="${USER_DIR}/ca.crt" \
  --embed-certs=true >/dev/null

kubectl config --kubeconfig "${OUTPUT_KUBECONFIG}" set-credentials "${USERNAME}" \
  --client-certificate="${USER_DIR}/${USERNAME}.crt" \
  --client-key="${USER_DIR}/${USERNAME}.key" \
  --embed-certs=true >/dev/null

kubectl config --kubeconfig "${OUTPUT_KUBECONFIG}" set-context "${USERNAME}@${CLUSTER_NAME}" \
  --cluster="${CLUSTER_NAME}" \
  --user="${USERNAME}" \
  --namespace="${NAMESPACE}" >/dev/null

kubectl config --kubeconfig "${OUTPUT_KUBECONFIG}" use-context "${USERNAME}@${CLUSTER_NAME}" >/dev/null
kubectl --kubeconfig "${OUTPUT_KUBECONFIG}" auth whoami >/dev/null

log "Generated ${OUTPUT_KUBECONFIG}"
