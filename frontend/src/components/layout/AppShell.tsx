import { useEffect } from 'react';
import { NavLink, Outlet } from 'react-router-dom';

import { api } from '../../lib/api';
import {
  emitPortalRefresh,
  emitPortalTaskUpdate,
  getActiveTestRunId,
  setActiveTestRunId,
} from '../../lib/portal-events';

const navItems = [
  { to: '/', label: 'Dashboard' },
  { to: '/tenants', label: 'Tenants' },
  { to: '/onboarding', label: 'Onboarding' },
  { to: '/rbac-users', label: 'RBAC & Users' },
  { to: '/testing', label: 'Testing' },
  { to: '/demo', label: 'Demo Mode' },
  { to: '/settings', label: 'Settings' },
];

export function AppShell() {
  useEffect(() => {
    let cancelled = false;

    const pollActiveRun = async () => {
      const runId = getActiveTestRunId();
      if (!runId) {
        return;
      }

      try {
        const run = await api.getTask(runId);
        if (cancelled) {
          return;
        }

        emitPortalTaskUpdate(run);
        if (run.status !== 'running') {
          setActiveTestRunId(null);
          emitPortalRefresh({
            reason: 'test-run-finished',
            runId: run.run_id,
            status: run.status,
          });
        }
      } catch {
        if (!cancelled) {
          setActiveTestRunId(null);
        }
      }
    };

    void pollActiveRun();
    const timer = window.setInterval(() => {
      void pollActiveRun();
    }, 1500);

    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, []);

  return (
    <div className="min-h-screen text-ink">
      <div className="mx-auto flex min-h-screen max-w-7xl flex-col px-4 py-6 sm:px-6 lg:px-8">
        <header className="rounded-[2rem] border border-white/70 bg-white/70 p-6 shadow-soft backdrop-blur">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.35em] text-ember">Local Demo Only</p>
              <h1 className="font-display text-4xl font-semibold">DSAA4040 Multi-Tenant Lab Platform</h1>
              <p className="mt-2 max-w-3xl text-sm text-ink/75">
                This frontend runs only on localhost and does not replace Kubernetes-native RBAC, quotas,
                limits, or network policies.
              </p>
            </div>
            <div className="rounded-2xl bg-ink px-4 py-3 text-sm text-paper">
              <div>Frontend: 127.0.0.1:5173</div>
              <div>Backend: 127.0.0.1:8000</div>
            </div>
          </div>
          <nav className="mt-6 flex flex-wrap gap-3">
            {navItems.map((item) => (
              <NavLink
                key={item.to}
                className={({ isActive }) =>
                  `rounded-full border px-4 py-2 text-sm transition ${
                    isActive
                      ? 'border-ember bg-ember text-white'
                      : 'border-ink/10 bg-paper/80 text-ink hover:border-ember/50 hover:text-ember'
                  }`
                }
                to={item.to}
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </header>
        <main className="mt-8 flex-1">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
