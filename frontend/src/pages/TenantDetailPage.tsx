import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';

import { TestResultPanel } from '../components/evidence/TestResultPanel';
import { api } from '../lib/api';

export function TenantDetailPage() {
  const { tenant = '' } = useParams();
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.getTenant(tenant).then(setData).catch((reason: Error) => setError(reason.message));
  }, [tenant]);

  return (
    <section className="space-y-6">
      <div className="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-soft">
        <h2 className="font-display text-3xl text-ink">Tenant Detail: {tenant}</h2>
      </div>
      {error ? <div className="rounded-3xl bg-ember px-5 py-4 text-white">{error}</div> : null}
      <div className="grid gap-6 xl:grid-cols-2">
        <TestResultPanel title="Quota" content={JSON.stringify(data?.resourcequota ?? null, null, 2)} />
        <TestResultPanel title="LimitRange" content={JSON.stringify(data?.limitrange ?? null, null, 2)} />
        <TestResultPanel title="NetworkPolicies" content={JSON.stringify(data?.networkpolicies ?? null, null, 2)} />
        <TestResultPanel title="RoleBindings" content={JSON.stringify(data?.rolebindings ?? null, null, 2)} />
        <TestResultPanel title="Pods" content={JSON.stringify(data?.pods ?? null, null, 2)} />
        <TestResultPanel title="Services" content={JSON.stringify(data?.services ?? null, null, 2)} />
      </div>
    </section>
  );
}
