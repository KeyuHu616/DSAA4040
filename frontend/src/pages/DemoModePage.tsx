import { useEffect, useState } from 'react';

import { api, type TenantSummary, type TestRunSummary } from '../lib/api';
import { subscribePortalRefresh } from '../lib/portal-events';

export function DemoModePage() {
  const [tenants, setTenants] = useState<TenantSummary[]>([]);
  const [latest, setLatest] = useState<TestRunSummary | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    const loadDemoData = () => {
      setError(null);

      api.getTenants().then((response) => {
        if (!cancelled) {
          setTenants(response);
        }
      }).catch((reason: Error) => {
        if (!cancelled) {
          setError(reason.message);
        }
      });

      api.getLatestTestRun().then((response) => {
        if (!cancelled) {
          setLatest(response);
        }
      }).catch((reason: Error) => {
        if (!cancelled) {
          setError((current) => current ?? reason.message);
        }
      });
    };

    loadDemoData();
    const unsubscribe = subscribePortalRefresh(() => {
      loadDemoData();
    });

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, []);

  return (
    <section className="space-y-6">
      {error ? <div className="rounded-3xl bg-ember px-5 py-4 text-white">{error}</div> : null}
      <div className="rounded-[2.5rem] border border-ember/20 bg-white/80 p-8 shadow-soft">
        <p className="text-sm font-semibold uppercase tracking-[0.35em] text-ember">Presentation Friendly</p>
        <h2 className="mt-3 font-display text-5xl text-ink">Demo Mode</h2>
        <p className="mt-4 max-w-3xl text-base text-ink/75">
          This view stays read-only and focuses on cluster overview, tenant isolation, kubeconfig inventory, and the latest timestamped evidence.
        </p>
      </div>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-[1.75rem] bg-ink p-5 text-paper shadow-soft">
          <div className="text-xs uppercase tracking-[0.3em] text-sun">Tenants</div>
          <div className="mt-3 font-display text-4xl">{tenants.length}</div>
        </div>
        <div className="rounded-[1.75rem] bg-white/80 p-5 shadow-soft">
          <div className="text-xs uppercase tracking-[0.3em] text-steel">Latest Run</div>
          <div className="mt-3 font-display text-2xl">{latest?.run_id ?? 'None'}</div>
          <div className="mt-2 text-xs text-ink/60">
            {latest ? `${latest.present_file_count}/${latest.total_expected_files} evidence files present` : 'No saved evidence yet'}
          </div>
        </div>
        <div className="rounded-[1.75rem] bg-white/80 p-5 shadow-soft">
          <div className="text-xs uppercase tracking-[0.3em] text-steel">Passed</div>
          <div className="mt-3 font-display text-2xl">{latest?.passed ?? '-'}</div>
        </div>
        <div className="rounded-[1.75rem] bg-white/80 p-5 shadow-soft">
          <div className="text-xs uppercase tracking-[0.3em] text-steel">Failed</div>
          <div className="mt-3 font-display text-2xl">{latest?.failed ?? '-'}</div>
        </div>
      </div>
    </section>
  );
}
