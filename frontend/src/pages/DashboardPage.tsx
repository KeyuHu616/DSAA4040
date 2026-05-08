import { useEffect, useState } from 'react';

import { api, type ClusterHealth, type TenantSummary, type TestRunSummary } from '../lib/api';
import { subscribePortalRefresh } from '../lib/portal-events';
import { StatusCard } from '../components/status/StatusCard';

export function DashboardPage() {
  const [health, setHealth] = useState<ClusterHealth | null>(null);
  const [tenants, setTenants] = useState<TenantSummary[]>([]);
  const [latest, setLatest] = useState<TestRunSummary | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    const recordError = (label: string, reason: Error) => {
      if (cancelled) {
        return;
      }
      setError((current) => current ?? `${label}: ${reason.message}`);
    };

    const loadDashboardData = () => {
      setError(null);

      api.getClusterHealth().then((response) => {
        if (!cancelled) {
          setHealth(response);
        }
      }).catch((reason: Error) => recordError('Cluster health', reason));

      api.getTenants().then((response) => {
        if (!cancelled) {
          setTenants(response);
        }
      }).catch((reason: Error) => recordError('Tenants', reason));

      api.getLatestTestRun().then((response) => {
        if (!cancelled) {
          setLatest(response);
        }
      }).catch((reason: Error) => recordError('Latest test run', reason));
    };

    loadDashboardData();
    const unsubscribe = subscribePortalRefresh(() => {
      loadDashboardData();
    });

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, []);

  return (
    <section className="space-y-6">
      {error ? <div className="rounded-3xl bg-ember px-5 py-4 text-white">{error}</div> : null}
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatusCard title="Cluster Health" value={health?.kubectl_available ? 'Reachable tooling' : 'Tooling missing'} />
        <StatusCard title="Tenant Count" value={String(tenants.length)} hint="team-a, team-b, and any additional tenant namespaces" />
        <StatusCard
          title="Latest Test Run"
          value={latest?.run_id ?? 'None'}
          hint={
            latest
              ? `Passed ${latest.passed ?? '-'} / Failed ${latest.failed ?? '-'} / Files ${latest.present_file_count}/${latest.total_expected_files}`
              : 'No saved evidence yet'
          }
        />
        <StatusCard title="API Server" value={health?.current_server ?? 'Unknown'} hint={health?.server_needs_loopback_fix ? 'Review 0.0.0.0 to 127.0.0.1 rewrite' : 'Loopback-safe when available'} />
      </div>
      <div className="grid gap-6 lg:grid-cols-[1.2fr,0.8fr]">
        <div className="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-soft">
          <h2 className="font-display text-3xl text-ink">Local Platform Boundaries</h2>
          <p className="mt-4 text-sm text-ink/75">
            This frontend is only a localhost presentation and management layer. Real security enforcement still comes
            from Kubernetes RBAC, ResourceQuota, LimitRange, NetworkPolicy, and the existing shell automation.
          </p>
        </div>
        <div className="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-soft">
          <h2 className="font-display text-3xl text-ink">Host Status</h2>
          <ul className="mt-4 space-y-2 text-sm text-ink/75">
            <li>Docker available: {health ? (health.docker_available ? 'yes' : 'no') : 'unknown'}</li>
            <li>k3d available: {health ? (health.k3d_available ? 'yes' : 'no') : 'unknown'}</li>
            <li>kubectl available: {health ? (health.kubectl_available ? 'yes' : 'no') : 'unknown'}</li>
            <li>Localhost only: {health ? (health.localhost_only ? 'yes' : 'no') : 'unknown'}</li>
          </ul>
        </div>
      </div>
    </section>
  );
}
