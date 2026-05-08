import { useEffect, useState } from 'react';

import { CommandLogPanel } from '../components/logs/CommandLogPanel';
import { api, type ClusterHealth, type TaskRecord } from '../lib/api';

export function SettingsPage() {
  const [health, setHealth] = useState<ClusterHealth | null>(null);
  const [run, setRun] = useState<TaskRecord | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.getClusterHealth().then(setHealth).catch((reason: Error) => setError(reason.message));
  }, []);

  useEffect(() => {
    if (!run || run.status !== 'running') {
      return;
    }
    const timer = window.setInterval(() => {
      api.getTask(run.run_id).then(setRun).catch((reason: Error) => setError(reason.message));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [run]);

  async function handleCheckEnvironment() {
    try {
      const nextRun = await api.runCheckEnvironment();
      setRun(nextRun);
      setError(null);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unknown environment error');
    }
  }

  return (
    <section className="grid gap-6 lg:grid-cols-[0.95fr,1.05fr]">
      <div className="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-soft">
        <h2 className="font-display text-3xl text-ink">Settings & Environment</h2>
        <ul className="mt-5 space-y-2 text-sm text-ink/75">
          <li>kubectl available: {health?.kubectl_available ? 'yes' : 'no'}</li>
          <li>docker available: {health?.docker_available ? 'yes' : 'no'}</li>
          <li>k3d available: {health?.k3d_available ? 'yes' : 'no'}</li>
          <li>bootstrap kubeconfig exists: {health?.bootstrap_kubeconfig_exists ? 'yes' : 'no'}</li>
          <li>current server: {health?.current_server ?? 'unknown'}</li>
          <li>loopback rewrite suggested: {health?.server_needs_loopback_fix ? 'yes' : 'no'}</li>
        </ul>
        <button className="mt-6 rounded-full bg-ember px-5 py-3 text-sm font-semibold text-white" onClick={handleCheckEnvironment} type="button">
          Run Environment Check
        </button>
        {error ? <div className="mt-4 rounded-2xl bg-ember px-4 py-3 text-sm text-white">{error}</div> : null}
      </div>
      <CommandLogPanel run={run} />
    </section>
  );
}
