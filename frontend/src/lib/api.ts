export type ClusterHealth = {
  backend_host: string;
  backend_port: number;
  localhost_only: boolean;
  kubectl_available: boolean;
  docker_available: boolean;
  k3d_available: boolean;
  bootstrap_kubeconfig: string;
  bootstrap_kubeconfig_exists: boolean;
  current_server: string | null;
  server_needs_loopback_fix: boolean;
};

export type TaskRecord = {
  run_id: string;
  action: string;
  argv: string[];
  status: string;
  started_at: string;
  finished_at: string | null;
  duration_seconds: number | null;
  exit_code: number | null;
  timed_out: boolean;
  log_path: string | null;
  error: string | null;
  log?: {
    stdout?: string;
    stderr?: string;
  } | null;
};

export type TenantSummary = {
  name: string;
  tenant: string;
  status: string;
  labels: Record<string, string>;
};

export type KubeconfigInfo = {
  filename: string;
  username: string;
  namespace: string | null;
  size_bytes: number;
  modified_time: number;
};

export type TestRunSummary = {
  run_id: string;
  summary_text: string | null;
  passed: number | null;
  failed: number | null;
  present_files: string[];
  missing_files: string[];
  present_file_count: number;
  total_expected_files: number;
  is_mostly_complete: boolean;
};

const API_BASE = 'http://127.0.0.1:8000';

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
    ...init,
  });

  const text = await response.text();
  const isJson = response.headers.get('content-type')?.includes('application/json');
  const payload = text && isJson ? (JSON.parse(text) as unknown) : text;

  if (!response.ok) {
    const detail =
      typeof payload === 'object' && payload !== null && 'detail' in payload
        ? String(payload.detail)
        : text || `Request failed with ${response.status}`;
    throw new Error(detail);
  }

  return payload as T;
}

export const api = {
  getClusterHealth: () => request<ClusterHealth>('/api/cluster/health'),
  getNodes: () => request<{ items?: Array<Record<string, unknown>> }>('/api/cluster/nodes'),
  getNamespaces: () => request<{ items?: Array<Record<string, unknown>> }>('/api/cluster/namespaces'),
  getTenants: () => request<TenantSummary[]>('/api/tenants'),
  getTenant: (tenant: string) => request<Record<string, unknown>>(`/api/tenants/${tenant}`),
  onboardTenant: (tenant: string) => request<TaskRecord>(`/api/tenants/${tenant}/onboard`, { method: 'POST' }),
  offboardTenant: (tenant: string) =>
    request<TaskRecord>(`/api/tenants/${tenant}/offboard`, {
      method: 'POST',
      body: JSON.stringify({ confirm_tenant: tenant }),
    }),
  getKubeconfigs: () => request<KubeconfigInfo[]>('/api/kubeconfigs'),
  runCheckEnvironment: () => request<TaskRecord>('/api/actions/check-environment', { method: 'POST' }),
  runBootstrap: (runtime: string) =>
    request<TaskRecord>('/api/actions/bootstrap', {
      method: 'POST',
      body: JSON.stringify({ runtime }),
    }),
  runTests: () => request<TaskRecord>('/api/actions/run-tests', { method: 'POST' }),
  getTask: (runId: string) => request<TaskRecord>(`/api/actions/runs/${runId}`),
  getLatestTestRun: () => request<TestRunSummary | null>('/api/test-results/latest'),
  getTestRuns: () => request<TestRunSummary[]>('/api/test-results'),
  getTestSection: (runId: string, section: string) =>
    request<{ content: string }>(`/api/test-results/${runId}/${section}`),
};
