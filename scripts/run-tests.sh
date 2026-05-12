#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source "${ROOT_DIR}/scripts/lib-kubeconfig.sh"

BOOTSTRAP_KUBECONFIG="$(default_bootstrap_kubeconfig)"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RESULT_DIR=""
RENDER_DIR=""
SUMMARY_FILE=""
RBAC_LOG=""
RESOURCE_LOG=""
NETWORK_LOG=""
CLUSTER_LOG=""
FINAL_SUMMARY_WRITTEN=false

PASS_COUNT=0
FAIL_COUNT=0

log() {
  printf '[tests] %s\n' "$*"
}

die() {
  printf '[tests] ERROR: %s\n' "$*" >&2
  exit 1
}

init_result_dir() {
  if [[ -n "${RESULT_DIR}" ]]; then
    return 0
  fi

  RESULT_DIR="artifacts/test-results/${TIMESTAMP}"
  RENDER_DIR="${RESULT_DIR}/rendered"
  SUMMARY_FILE="${RESULT_DIR}/summary.txt"
  RBAC_LOG="${RESULT_DIR}/rbac-tests.txt"
  RESOURCE_LOG="${RESULT_DIR}/resource-tests.txt"
  NETWORK_LOG="${RESULT_DIR}/network-tests.txt"
  CLUSTER_LOG="${RESULT_DIR}/cluster-state.txt"

  mkdir -p "${RESULT_DIR}" "${RENDER_DIR}"
  {
    echo "Result directory: ${RESULT_DIR}"
    echo "Bootstrap kubeconfig: ${BOOTSTRAP_KUBECONFIG}"
    echo "Context: $(kubeconfig_current_context "${BOOTSTRAP_KUBECONFIG}")"
    echo "Cluster server: $(kubeconfig_current_server "${BOOTSTRAP_KUBECONFIG}")"
  } > "${SUMMARY_FILE}"
}

write_summary_footer() {
  local status="${1:-unknown}"

  if [[ -z "${RESULT_DIR}" || "${FINAL_SUMMARY_WRITTEN}" == true ]]; then
    return 0
  fi

  {
    echo "Status: ${status}"
    echo "Passed: ${PASS_COUNT}"
    echo "Failed: ${FAIL_COUNT}"
  } >> "${SUMMARY_FILE}"
  FINAL_SUMMARY_WRITTEN=true
}

on_exit() {
  local exit_code=$?

  if [[ -n "${RESULT_DIR}" ]]; then
    if [[ "${exit_code}" -eq 0 ]]; then
      write_summary_footer "passed"
    else
      write_summary_footer "failed"
    fi
  fi
}

trap on_exit EXIT

live_cluster_available() {
  if ! command -v kubectl >/dev/null 2>&1; then
    return 1
  fi

  if [[ ! -f "${BOOTSTRAP_KUBECONFIG}" ]]; then
    return 1
  fi

  normalize_loopback_server "${BOOTSTRAP_KUBECONFIG}" >/dev/null || true
  cluster_reachable "${BOOTSTRAP_KUBECONFIG}"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

record_result() {
  local status="$1"
  local description="$2"
  local logfile="$3"

  printf '%s: %s\n' "${status}" "${description}" | tee -a "${SUMMARY_FILE}" >> "${logfile}"
  if [[ "${status}" == PASS ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

render_template() {
  local team="$1"
  local template="$2"
  local output="$3"

  sed "s|__TEAM__|${team}|g" "${template}" > "${output}"
}

kubectl_admin() {
  kubectl --kubeconfig "${BOOTSTRAP_KUBECONFIG}" "$@"
}

assert_allow() {
  local logfile="$1"
  local description="$2"
  local kubeconfig="$3"
  shift 3

  if kubectl --kubeconfig "${kubeconfig}" auth can-i -q "$@" >> "${logfile}" 2>&1; then
    record_result PASS "${description}" "${logfile}"
  else
    record_result FAIL "${description}" "${logfile}"
  fi
}

assert_deny() {
  local logfile="$1"
  local description="$2"
  local kubeconfig="$3"
  shift 3

  if kubectl --kubeconfig "${kubeconfig}" auth can-i -q "$@" >> "${logfile}" 2>&1; then
    record_result FAIL "${description}" "${logfile}"
  else
    record_result PASS "${description}" "${logfile}"
  fi
}

assert_command_success() {
  local logfile="$1"
  local description="$2"
  shift 2

  if "$@" >> "${logfile}" 2>&1; then
    record_result PASS "${description}" "${logfile}"
  else
    record_result FAIL "${description}" "${logfile}"
  fi
}

assert_command_failure() {
  local logfile="$1"
  local description="$2"
  shift 2

  if "$@" >> "${logfile}" 2>&1; then
    record_result FAIL "${description}" "${logfile}"
  else
    record_result PASS "${description}" "${logfile}"
  fi
}

assert_equals() {
  local logfile="$1"
  local description="$2"
  local expected="$3"
  local actual="$4"

  {
    echo "Expected: ${expected}"
    echo "Actual: ${actual}"
  } >> "${logfile}"

  if [[ "${actual}" == "${expected}" ]]; then
    record_result PASS "${description}" "${logfile}"
  else
    record_result FAIL "${description}" "${logfile}"
  fi
}

assert_command_success_retry() {
  local logfile="$1"
  local description="$2"
  local attempts="$3"
  local sleep_seconds="$4"
  shift 4

  local output=""
  local attempt

  for (( attempt=1; attempt<=attempts; attempt++ )); do
    if output="$("$@" 2>&1)"; then
      printf '%s\n' "${output}" >> "${logfile}"
      record_result PASS "${description}" "${logfile}"
      return 0
    fi

    printf '%s\n' "${output}" >> "${logfile}"
    if (( attempt < attempts )); then
      printf '[tests] retrying (%s/%s): %s\n' "${attempt}" "${attempts}" "${description}" >> "${logfile}"
      sleep "${sleep_seconds}"
    fi
  done

  record_result FAIL "${description}" "${logfile}"
  return 1
}

capture_cluster_state() {
  {
    echo "# Namespaces"
    kubectl_admin get namespaces --show-labels
    echo
    echo "# Team A quota"
    kubectl_admin get resourcequota -n team-a -o wide
    echo
    echo "# Team B quota"
    kubectl_admin get resourcequota -n team-b -o wide
    echo
    echo "# Team A limitrange"
    kubectl_admin get limitrange -n team-a -o wide
    echo
    echo "# Team B limitrange"
    kubectl_admin get limitrange -n team-b -o wide
    echo
    echo "# Team A network policies"
    kubectl_admin get networkpolicy -n team-a -o wide
    echo
    echo "# Team B network policies"
    kubectl_admin get networkpolicy -n team-b -o wide
    echo
    echo "# Team A rolebindings"
    kubectl_admin get rolebinding -n team-a -o wide
    echo
    echo "# Team B rolebindings"
    kubectl_admin get rolebinding -n team-b -o wide
  } > "${CLUSTER_LOG}"
}

cleanup_test_resources() {
  for team in team-a team-b; do
    kubectl_admin delete deployment normal-workload http-echo --ignore-not-found -n "${team}" >/dev/null 2>&1 || true
    kubectl_admin delete pod defaulted-workload oversized-workload quota-exceeded-workload network-client --ignore-not-found -n "${team}" >/dev/null 2>&1 || true
    kubectl_admin delete service http-echo --ignore-not-found -n "${team}" >/dev/null 2>&1 || true
  done
}

run_rbac_tests() {
  local dev_a="artifacts/kubeconfigs/team-a-developer.kubeconfig"
  local viewer_a="artifacts/kubeconfigs/team-a-viewer.kubeconfig"
  local dev_ns viewer_ns dev_user viewer_user

  : > "${RBAC_LOG}"
  echo "# RBAC tests" >> "${RBAC_LOG}"

  dev_ns="$(kubeconfig_current_namespace "${dev_a}")"
  viewer_ns="$(kubeconfig_current_namespace "${viewer_a}")"
  dev_user="$(kubeconfig_current_user "${dev_a}")"
  viewer_user="$(kubeconfig_current_user "${viewer_a}")"

  assert_equals "${RBAC_LOG}" "Developer A kubeconfig defaults to namespace team-a" "team-a" "${dev_ns}"
  assert_equals "${RBAC_LOG}" "Viewer A kubeconfig defaults to namespace team-a" "team-a" "${viewer_ns}"
  assert_equals "${RBAC_LOG}" "Developer A kubeconfig uses subject team-a-developer" "team-a-developer" "${dev_user}"
  assert_equals "${RBAC_LOG}" "Viewer A kubeconfig uses subject team-a-viewer" "team-a-viewer" "${viewer_user}"

  assert_allow "${RBAC_LOG}" "Developer A can create deployments in team-a" "${dev_a}" create deployments -n team-a
  assert_allow "${RBAC_LOG}" "Developer A can get pods in team-a" "${dev_a}" get pods -n team-a
  assert_allow "${RBAC_LOG}" "Developer A can get pod logs in team-a" "${dev_a}" get pods/log -n team-a

  assert_deny "${RBAC_LOG}" "Developer A cannot get pods in team-b" "${dev_a}" get pods -n team-b
  assert_deny "${RBAC_LOG}" "Developer A cannot create deployments in team-b" "${dev_a}" create deployments -n team-b
  assert_deny "${RBAC_LOG}" "Developer A cannot update resourcequotas in team-a" "${dev_a}" update resourcequotas -n team-a
  assert_deny "${RBAC_LOG}" "Developer A cannot update networkpolicies in team-a" "${dev_a}" update networkpolicies -n team-a
  assert_deny "${RBAC_LOG}" "Developer A cannot create rolebindings in team-a" "${dev_a}" create rolebindings -n team-a
  assert_deny "${RBAC_LOG}" "Developer A cannot patch namespace team-a" "${dev_a}" patch namespaces team-a
  assert_deny "${RBAC_LOG}" "Developer A cannot get secrets in team-a" "${dev_a}" get secrets -n team-a

  assert_allow "${RBAC_LOG}" "Viewer A can get pods in team-a" "${viewer_a}" get pods -n team-a
  assert_allow "${RBAC_LOG}" "Viewer A can list services in team-a" "${viewer_a}" list services -n team-a

  assert_deny "${RBAC_LOG}" "Viewer A cannot create deployments in team-a" "${viewer_a}" create deployments -n team-a
  assert_deny "${RBAC_LOG}" "Viewer A cannot delete pods in team-a" "${viewer_a}" delete pods -n team-a
  assert_deny "${RBAC_LOG}" "Viewer A cannot get pods in team-b" "${viewer_a}" get pods -n team-b
  assert_deny "${RBAC_LOG}" "Viewer A cannot get secrets in team-a" "${viewer_a}" get secrets -n team-a
}

run_resource_tests() {
  local dev_a="artifacts/kubeconfigs/team-a-developer.kubeconfig"
  local normal_render="${RENDER_DIR}/team-a-normal-deployment.yaml"
  local defaulted_render="${RENDER_DIR}/team-a-defaulted-pod.yaml"
  local oversized_render="${RENDER_DIR}/team-a-oversized-pod.yaml"
  local quota_render="${RENDER_DIR}/team-a-quota-exceeded-pod.yaml"
  local requests_cpu requests_mem limits_cpu limits_mem
  local output

  : > "${RESOURCE_LOG}"
  echo "# ResourceQuota and LimitRange tests" >> "${RESOURCE_LOG}"

  render_template team-a manifests/test-workloads/normal-deployment.yaml.tpl "${normal_render}"
  render_template team-a manifests/test-workloads/defaulted-pod.yaml.tpl "${defaulted_render}"
  render_template team-a manifests/test-workloads/oversized-pod.yaml.tpl "${oversized_render}"
  render_template team-a manifests/test-workloads/quota-exceeded-pod.yaml.tpl "${quota_render}"

  kubectl_admin delete deployment normal-workload --ignore-not-found -n team-a >/dev/null 2>&1 || true
  kubectl_admin delete pod defaulted-workload oversized-workload quota-exceeded-workload --ignore-not-found -n team-a >/dev/null 2>&1 || true

  assert_command_success "${RESOURCE_LOG}" "Normal workload succeeds inside quota and limits" \
    kubectl --kubeconfig "${dev_a}" apply -f "${normal_render}"
  assert_command_success "${RESOURCE_LOG}" "Normal deployment becomes Available" \
    kubectl --kubeconfig "${dev_a}" rollout status deployment/normal-workload -n team-a --timeout=180s

  assert_command_success "${RESOURCE_LOG}" "Defaulted workload without resources is admitted" \
    kubectl --kubeconfig "${dev_a}" apply -f "${defaulted_render}"
  assert_command_success "${RESOURCE_LOG}" "Defaulted workload becomes Ready" \
    kubectl --kubeconfig "${dev_a}" wait --for=condition=Ready pod/defaulted-workload -n team-a --timeout=180s

  requests_cpu="$(kubectl --kubeconfig "${dev_a}" get pod defaulted-workload -n team-a -o jsonpath='{.spec.containers[0].resources.requests.cpu}')"
  requests_mem="$(kubectl --kubeconfig "${dev_a}" get pod defaulted-workload -n team-a -o jsonpath='{.spec.containers[0].resources.requests.memory}')"
  limits_cpu="$(kubectl --kubeconfig "${dev_a}" get pod defaulted-workload -n team-a -o jsonpath='{.spec.containers[0].resources.limits.cpu}')"
  limits_mem="$(kubectl --kubeconfig "${dev_a}" get pod defaulted-workload -n team-a -o jsonpath='{.spec.containers[0].resources.limits.memory}')"

  {
    echo "Injected requests.cpu=${requests_cpu}"
    echo "Injected requests.memory=${requests_mem}"
    echo "Injected limits.cpu=${limits_cpu}"
    echo "Injected limits.memory=${limits_mem}"
  } >> "${RESOURCE_LOG}"

  if [[ "${requests_cpu}" == "250m" && "${requests_mem}" == "256Mi" && "${limits_cpu}" == "500m" && "${limits_mem}" == "512Mi" ]]; then
    record_result PASS "LimitRange default requests and limits were injected" "${RESOURCE_LOG}"
  else
    record_result FAIL "LimitRange default requests and limits were injected" "${RESOURCE_LOG}"
  fi

  if output="$(kubectl --kubeconfig "${dev_a}" apply -f "${oversized_render}" 2>&1)"; then
    printf '%s\n' "${output}" >> "${RESOURCE_LOG}"
    record_result FAIL "Oversized workload is rejected by LimitRange" "${RESOURCE_LOG}"
  else
    printf '%s\n' "${output}" >> "${RESOURCE_LOG}"
    record_result PASS "Oversized workload is rejected by LimitRange" "${RESOURCE_LOG}"
  fi

  if output="$(kubectl --kubeconfig "${dev_a}" apply -f "${quota_render}" 2>&1)"; then
    printf '%s\n' "${output}" >> "${RESOURCE_LOG}"
    record_result FAIL "Quota-exceeding workload is rejected by ResourceQuota" "${RESOURCE_LOG}"
  else
    printf '%s\n' "${output}" >> "${RESOURCE_LOG}"
    if grep -qi "exceeded quota" <<< "${output}"; then
      record_result PASS "Quota-exceeding workload is rejected by ResourceQuota" "${RESOURCE_LOG}"
    else
      record_result FAIL "Quota-exceeding workload is rejected by ResourceQuota" "${RESOURCE_LOG}"
    fi
  fi

  kubectl_admin delete deployment normal-workload --ignore-not-found -n team-a >/dev/null 2>&1 || true
  kubectl_admin delete pod defaulted-workload oversized-workload quota-exceeded-workload --ignore-not-found -n team-a >/dev/null 2>&1 || true
}

run_network_tests() {
  local dev_a="artifacts/kubeconfigs/team-a-developer.kubeconfig"
  local dev_b="artifacts/kubeconfigs/team-b-developer.kubeconfig"
  local server_a="${RENDER_DIR}/team-a-http-server.yaml"
  local server_b="${RENDER_DIR}/team-b-http-server.yaml"
  local client_a="${RENDER_DIR}/team-a-network-client.yaml"
  local client_b="${RENDER_DIR}/team-b-network-client.yaml"

  : > "${NETWORK_LOG}"
  echo "# NetworkPolicy tests" >> "${NETWORK_LOG}"

  render_template team-a manifests/test-workloads/http-server.yaml.tpl "${server_a}"
  render_template team-b manifests/test-workloads/http-server.yaml.tpl "${server_b}"
  render_template team-a manifests/test-workloads/network-client.yaml.tpl "${client_a}"
  render_template team-b manifests/test-workloads/network-client.yaml.tpl "${client_b}"

  kubectl_admin delete deployment http-echo --ignore-not-found -n team-a >/dev/null 2>&1 || true
  kubectl_admin delete deployment http-echo --ignore-not-found -n team-b >/dev/null 2>&1 || true
  kubectl_admin delete pod network-client --ignore-not-found -n team-a >/dev/null 2>&1 || true
  kubectl_admin delete pod network-client --ignore-not-found -n team-b >/dev/null 2>&1 || true
  kubectl_admin delete service http-echo --ignore-not-found -n team-a >/dev/null 2>&1 || true
  kubectl_admin delete service http-echo --ignore-not-found -n team-b >/dev/null 2>&1 || true

  assert_command_success "${NETWORK_LOG}" "Developer A deploys HTTP server in team-a" \
    kubectl --kubeconfig "${dev_a}" apply -f "${server_a}"
  assert_command_success "${NETWORK_LOG}" "Developer B deploys HTTP server in team-b" \
    kubectl --kubeconfig "${dev_b}" apply -f "${server_b}"
  assert_command_success "${NETWORK_LOG}" "Developer A deploys client pod in team-a" \
    kubectl --kubeconfig "${dev_a}" apply -f "${client_a}"
  assert_command_success "${NETWORK_LOG}" "Developer B deploys client pod in team-b" \
    kubectl --kubeconfig "${dev_b}" apply -f "${client_b}"

  assert_command_success "${NETWORK_LOG}" "HTTP server in team-a becomes Available" \
    kubectl --kubeconfig "${dev_a}" rollout status deployment/http-echo -n team-a --timeout=180s
  assert_command_success "${NETWORK_LOG}" "HTTP server in team-b becomes Available" \
    kubectl --kubeconfig "${dev_b}" rollout status deployment/http-echo -n team-b --timeout=180s
  assert_command_success "${NETWORK_LOG}" "Client pod in team-a becomes Ready" \
    kubectl --kubeconfig "${dev_a}" wait --for=condition=Ready pod/network-client -n team-a --timeout=180s
  assert_command_success "${NETWORK_LOG}" "Client pod in team-b becomes Ready" \
    kubectl --kubeconfig "${dev_b}" wait --for=condition=Ready pod/network-client -n team-b --timeout=180s

  assert_command_success_retry "${NETWORK_LOG}" "Pod in team-a can reach service in team-a over TCP" 5 3 \
    kubectl_admin exec -n team-a network-client -- wget -q -T 5 -O - http://http-echo.team-a.svc.cluster.local
  assert_command_success_retry "${NETWORK_LOG}" "Pod in team-b can reach service in team-b over TCP" 5 3 \
    kubectl_admin exec -n team-b network-client -- wget -q -T 5 -O - http://http-echo.team-b.svc.cluster.local
  assert_command_failure "${NETWORK_LOG}" "Pod in team-a cannot reach service in team-b over TCP" \
    kubectl_admin exec -n team-a network-client -- wget -q -T 5 -O - http://http-echo.team-b.svc.cluster.local
  assert_command_failure "${NETWORK_LOG}" "Pod in team-b cannot reach service in team-a over TCP" \
    kubectl_admin exec -n team-b network-client -- wget -q -T 5 -O - http://http-echo.team-a.svc.cluster.local
}

if ! bash scripts/static-validate.sh; then
  die "static validation failed"
fi

if ! live_cluster_available; then
  log "No reachable Kubernetes cluster detected. Skipping live deployment tests."
  printf '%s\n' "Static validation completed; live Kubernetes validation is pending on WSL2 or another Docker/Kubernetes-enabled machine."
  exit 0
fi

need_cmd kubectl
need_cmd openssl
need_cmd base64

log "Checking cluster connectivity"
kubectl_admin cluster-info >/dev/null

init_result_dir

log "Ensuring tenant namespaces and kubeconfigs exist"
scripts/onboard-team.sh team-a
scripts/onboard-team.sh team-b

log "Capturing pre-test cluster state"
capture_cluster_state

cleanup_test_resources

log "Running RBAC tests"
run_rbac_tests

log "Running ResourceQuota and LimitRange tests"
run_resource_tests

log "Running NetworkPolicy tests"
run_network_tests

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  write_summary_footer "failed"
  die "one or more tests failed; see ${SUMMARY_FILE}"
fi

write_summary_footer "passed"
log "Live Kubernetes validation passed. Results saved to ${RESULT_DIR}"
