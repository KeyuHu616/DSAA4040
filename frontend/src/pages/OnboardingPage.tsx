import { useEffect, useMemo, useState } from 'react';

import { CommandLogPanel } from '../components/logs/CommandLogPanel';
import { api, type TaskRecord } from '../lib/api';

const tenantPattern = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/;

export function OnboardingPage() {
  const [tenant, setTenant] = useState('team-c');
  const [run, setRun] = useState<TaskRecord | null>(null);
  const [error, setError] = useState<string | null>(null);

  const valid = useMemo(() => tenantPattern.test(tenant), [tenant]);

  useEffect(() => {
    if (!run || run.status !== 'running') {
      return;
    }

    const timer = window.setInterval(() => {
      api.getTask(run.run_id).then(setRun).catch((reason: Error) => setError(reason.message));
    }, 1200);

    return () => window.clearInterval(timer);
  }, [run]);

  async function handleSubmit() {
    try {
      setError(null);
      const nextRun = await api.onboardTenant(tenant);
      setRun(nextRun);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unknown onboarding failure');
    }
  }

  return (
    <section className="grid gap-6 lg:grid-cols-[0.95fr,1.05fr]">
      <div className="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-soft">
        <h2 className="font-display text-3xl text-ink">Onboard A Tenant</h2>
        <p className="mt-3 text-sm text-ink/75">This form calls scripts/onboard-team.sh after validating the tenant name with a safe DNS-1123 regex.</p>
        <label className="mt-6 block text-sm font-medium text-ink" htmlFor="tenant-name">Tenant name</label>
        <input
          id="tenant-name"
          className="mt-2 w-full rounded-2xl border border-ink/15 bg-paper px-4 py-3"
          onChange={(event) => setTenant(event.target.value.trim())}
          value={tenant}
        />
        <p className={`mt-2 text-sm ${valid ? 'text-moss' : 'text-ember'}`}>
          {valid ? 'Tenant name is valid.' : 'Tenant name must match the DNS-1123 label rule.'}
        </p>
        <button
          className="mt-6 rounded-full bg-ember px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:bg-ember/50"
          disabled={!valid}
          onClick={handleSubmit}
          type="button"
        >
          Run onboard-team.sh
        </button>
        {error ? <div className="mt-4 rounded-2xl bg-ember px-4 py-3 text-sm text-white">{error}</div> : null}
      </div>
      <CommandLogPanel run={run} />
    </section>
  );
}
