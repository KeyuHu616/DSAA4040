import { useEffect, useState } from 'react';

import { TenantSummaryCard } from '../components/tenants/TenantSummaryCard';
import { api, type TenantSummary } from '../lib/api';

export function TenantsPage() {
  const [tenants, setTenants] = useState<TenantSummary[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.getTenants().then(setTenants).catch((reason: Error) => setError(reason.message));
  }, []);

  return (
    <section className="space-y-6">
      <div className="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-soft">
        <h2 className="font-display text-3xl text-ink">Tenants</h2>
        <p className="mt-3 text-sm text-ink/75">Lists team-a, team-b, and any namespace currently marked as a tenant.</p>
      </div>
      {error ? <div className="rounded-3xl bg-ember px-5 py-4 text-white">{error}</div> : null}
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {tenants.map((tenant) => (
          <TenantSummaryCard key={tenant.name} tenant={tenant} />
        ))}
      </div>
    </section>
  );
}
