import { useEffect, useState } from 'react';

import { CommandLogPanel } from '../components/logs/CommandLogPanel';
import { TestResultPanel } from '../components/evidence/TestResultPanel';
import { api, type TaskRecord, type TestRunSummary } from '../lib/api';
import {
  emitPortalTaskUpdate,
  setActiveTestRunId,
  subscribePortalRefresh,
  subscribePortalTaskUpdate,
} from '../lib/portal-events';

export function TestingPage() {
  const [run, setRun] = useState<TaskRecord | null>(null);
  const [latest, setLatest] = useState<TestRunSummary | null>(null);
  const [summary, setSummary] = useState<string | null>(null);
  const [rbac, setRbac] = useState<string | null>(null);
  const [resource, setResource] = useState<string | null>(null);
  const [network, setNetwork] = useState<string | null>(null);
  const [clusterState, setClusterState] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    const sectionFallback = (label: string, reason: unknown) => {
      const message = reason instanceof Error ? reason.message : 'Unavailable';
      return `${label} section unavailable: ${message}`;
    };

    const loadLatestRunData = async () => {
      if (cancelled) {
        return;
      }

      setError(null);
      const latestRun = await api.getLatestTestRun();
      if (cancelled) {
        return;
      }

      setLatest(latestRun);
      if (!latestRun) {
        setSummary(null);
        setRbac(null);
        setResource(null);
        setNetwork(null);
        setClusterState(null);
        return;
      }

      const results = await Promise.allSettled([
        api.getTestSection(latestRun.run_id, 'summary'),
        api.getTestSection(latestRun.run_id, 'rbac'),
        api.getTestSection(latestRun.run_id, 'resource'),
        api.getTestSection(latestRun.run_id, 'network'),
        api.getTestSection(latestRun.run_id, 'cluster-state'),
      ]);

      if (cancelled) {
        return;
      }

      setSummary(results[0].status === 'fulfilled' ? results[0].value.content : sectionFallback('Summary', results[0].reason));
      setRbac(results[1].status === 'fulfilled' ? results[1].value.content : sectionFallback('RBAC', results[1].reason));
      setResource(results[2].status === 'fulfilled' ? results[2].value.content : sectionFallback('Resource', results[2].reason));
      setNetwork(results[3].status === 'fulfilled' ? results[3].value.content : sectionFallback('Network', results[3].reason));
      setClusterState(
        results[4].status === 'fulfilled'
          ? results[4].value.content
          : sectionFallback('Cluster state', results[4].reason),
      );
    };

    loadLatestRunData().catch((reason: Error) => {
      if (!cancelled) {
        setError(reason.message);
      }
    });

    const unsubscribeRefresh = subscribePortalRefresh(() => {
      void loadLatestRunData().catch((reason: Error) => {
        if (!cancelled) {
          setError(reason.message);
        }
      });
    });

    const unsubscribeTask = subscribePortalTaskUpdate(({ run: nextRun }) => {
      if (!cancelled) {
        setRun((current) => (current?.run_id === nextRun.run_id || current === null ? nextRun : current));
      }
    });

    return () => {
      cancelled = true;
      unsubscribeRefresh();
      unsubscribeTask();
    };
  }, []);

  async function handleRunTests() {
    try {
      setError(null);
      const nextRun = await api.runTests();
      setRun(nextRun);
      setActiveTestRunId(nextRun.run_id);
      emitPortalTaskUpdate(nextRun);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unknown test failure');
    }
  }

  return (
    <section className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4 rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-soft">
        <div>
          <h2 className="font-display text-3xl text-ink">Testing</h2>
          <p className="mt-3 text-sm text-ink/75">Runs the existing run-tests.sh flow and renders the latest saved evidence.</p>
        </div>
        <button
          className="rounded-full bg-ink px-5 py-3 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
          disabled={run?.status === 'running'}
          onClick={handleRunTests}
          type="button"
        >
          {run?.status === 'running' ? 'Running Full Tests...' : 'Run Full Tests'}
        </button>
      </div>
      {error ? <div className="rounded-3xl bg-ember px-5 py-4 text-white">{error}</div> : null}
      <div className="grid gap-6 lg:grid-cols-[1.05fr,0.95fr]">
        <div className="space-y-6">
          <div className="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-soft">
            <h3 className="font-display text-2xl">Latest Saved Run</h3>
            <p className="mt-3 text-sm text-ink/75">
              {latest ? `${latest.run_id} | Passed ${latest.passed ?? '-'} | Failed ${latest.failed ?? '-'}` : 'No saved run yet.'}
            </p>
            {latest ? (
              <div className="mt-4 space-y-2 text-xs text-ink/65">
                <div>Evidence files present: {latest.present_file_count}/{latest.total_expected_files}</div>
                <div>Present: {latest.present_files.length > 0 ? latest.present_files.join(', ') : 'none'}</div>
                <div>Missing: {latest.missing_files.length > 0 ? latest.missing_files.join(', ') : 'none'}</div>
              </div>
            ) : null}
          </div>
          <CommandLogPanel run={run} />
        </div>
        <div className="grid gap-6">
          <TestResultPanel title="Summary" content={summary} />
          <TestResultPanel title="RBAC" content={rbac} />
          <TestResultPanel title="Resource" content={resource} />
          <TestResultPanel title="Network" content={network} />
          <TestResultPanel title="Cluster State" content={clusterState} />
        </div>
      </div>
    </section>
  );
}
