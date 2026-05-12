#!/usr/bin/env bash

default_bootstrap_kubeconfig() {
  if [[ -n "${BOOTSTRAP_KUBECONFIG:-}" ]]; then
    printf '%s\n' "${BOOTSTRAP_KUBECONFIG}"
  elif [[ -n "${KUBECONFIG:-}" && "${KUBECONFIG}" != *:* && -f "${KUBECONFIG}" ]]; then
    printf '%s\n' "${KUBECONFIG}"
  else
    printf '%s\n' "${HOME}/.kube/config"
  fi
}

kubeconfig_current_context() {
  kubectl --kubeconfig "$1" config current-context 2>/dev/null || true
}

kubeconfig_current_cluster() {
  kubectl --kubeconfig "$1" config view --raw --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || true
}

kubeconfig_current_user() {
  kubectl --kubeconfig "$1" config view --raw --minify -o jsonpath='{.contexts[0].context.user}' 2>/dev/null || true
}

kubeconfig_current_namespace() {
  kubectl --kubeconfig "$1" config view --raw --minify -o jsonpath='{.contexts[0].context.namespace}' 2>/dev/null || true
}

kubeconfig_current_server() {
  kubectl --kubeconfig "$1" config view --raw --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true
}

normalize_loopback_server() {
  local kubeconfig="$1"
  local expected_context="${2:-}"
  local current_context current_cluster current_server port target_cluster normalized_server

  current_context="$(kubeconfig_current_context "${kubeconfig}")"
  current_cluster="$(kubeconfig_current_cluster "${kubeconfig}")"
  current_server="$(kubeconfig_current_server "${kubeconfig}")"

  if [[ ! "${current_server}" =~ ^https://0\.0\.0\.0:([0-9]+)$ ]]; then
    printf '%s\n' "${current_server}"
    return 0
  fi

  if [[ -n "${expected_context}" && "${current_context}" != "${expected_context}" && "${current_cluster}" != "${expected_context}" ]]; then
    printf '%s\n' "${current_server}"
    return 0
  fi

  port="${BASH_REMATCH[1]}"
  target_cluster="${current_cluster:-${expected_context}}"
  normalized_server="https://127.0.0.1:${port}"

  if [[ -n "${target_cluster}" && "${current_server}" != "${normalized_server}" ]]; then
    kubectl config --kubeconfig "${kubeconfig}" set-cluster "${target_cluster}" --server="${normalized_server}" >/dev/null
  fi

  printf '%s\n' "${normalized_server}"
}

cluster_reachable() {
  local kubeconfig="$1"
  [[ -f "${kubeconfig}" ]] && kubectl --kubeconfig "${kubeconfig}" cluster-info >/dev/null 2>&1
}
