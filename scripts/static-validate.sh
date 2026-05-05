#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

LOG_FILE="artifacts/test-results/static-validation.log"
RENDER_ROOT="artifacts/rendered"

mkdir -p "$(dirname "${LOG_FILE}")" "${RENDER_ROOT}"
: > "${LOG_FILE}"

exec > >(tee "${LOG_FILE}") 2>&1

log() {
  printf '[static] %s\n' "$*"
}

die() {
  printf '[static] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

check_required_paths() {
  local missing=0
  local path
  local required_paths=(
    README.md
    AGENTS.md
    environment.yml
    docs/proposal.md
    docs/architecture.md
    docs/rbac-matrix.md
    docs/onboarding-guide.md
    docs/testing-guide.md
    docs/demo-script.md
    docs/ha-discussion.md
    manifests/rbac
    manifests/quota
    manifests/limitrange
    manifests/netpol
    manifests/podsecurity
    manifests/test-workloads
    scripts/bootstrap-cluster.sh
    scripts/check-environment.sh
    scripts/onboard-team.sh
    scripts/offboard-team.sh
    scripts/issue-user-kubeconfig.sh
    scripts/static-validate.sh
    scripts/run-tests.sh
    artifacts/kubeconfigs
    artifacts/rendered
    artifacts/test-results
  )

  for path in "${required_paths[@]}"; do
    if [[ -e "${path}" ]]; then
      log "Required path present: ${path}"
    else
      printf '[static] MISSING: %s\n' "${path}"
      missing=1
    fi
  done

  [[ "${missing}" -eq 0 ]] || die "required repository structure is incomplete"
}

render_templates() {
  local team="$1"
  local team_dir="${RENDER_ROOT}/${team}"
  local template rel out

  mkdir -p "${team_dir}"

  while IFS= read -r template; do
    rel="${template#manifests/}"
    out="${team_dir}/${rel%.tpl}"
    mkdir -p "$(dirname "${out}")"
    sed "s|__TEAM__|${team}|g" "${template}" > "${out}"
    log "Rendered ${template} -> ${out}"
  done < <(find manifests -type f -name '*.tpl' | sort)
}

validate_yaml_with_python() {
  need_cmd python3

  python3 - <<'PY'
from pathlib import Path
import sys
import yaml

root = Path("artifacts/rendered")
files = sorted(root.rglob("*.yaml"))
if not files:
    print("[static] ERROR: no rendered YAML files were found")
    sys.exit(1)

doc_count = 0
for path in files:
    with path.open("r", encoding="utf-8") as handle:
        docs = list(yaml.safe_load_all(handle))
    non_null_docs = [doc for doc in docs if doc is not None]
    if not non_null_docs:
        print(f"[static] ERROR: {path} did not contain any YAML documents")
        sys.exit(1)
    doc_count += len(non_null_docs)

print(f"[static] Parsed {len(files)} rendered YAML files containing {doc_count} YAML documents with PyYAML")
PY
}

optional_kubectl_dry_run() {
  local file

  if ! command -v kubectl >/dev/null 2>&1; then
    log "kubectl is not available; skipping client-side dry-run validation"
    return 0
  fi

  while IFS= read -r file; do
    kubectl apply --dry-run=client --validate=false -f "${file}" >/dev/null
    log "kubectl client dry-run passed for ${file}"
  done < <(find "${RENDER_ROOT}" -type f -name '*.yaml' | sort)
}

log "Starting static validation"

if [[ -x scripts/check-environment.sh ]]; then
  log "Environment summary"
  bash scripts/check-environment.sh
fi

need_cmd bash
need_cmd sed

log "Checking shell syntax"
bash -n scripts/*.sh

log "Checking required repository structure"
check_required_paths

log "Refreshing rendered manifests under ${RENDER_ROOT}"
rm -rf "${RENDER_ROOT}"
mkdir -p "${RENDER_ROOT}"
render_templates team-a
render_templates team-b

log "Validating rendered YAML with PyYAML"
validate_yaml_with_python

log "Running optional kubectl client-side dry-run validation"
optional_kubectl_dry_run

log "Static validation completed successfully"
log "Log file: ${LOG_FILE}"
