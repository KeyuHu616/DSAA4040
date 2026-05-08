import { Link } from 'react-router-dom';

import type { TenantSummary } from '../../lib/api';

type TenantSummaryCardProps = {
  tenant: TenantSummary;
};

export function TenantSummaryCard({ tenant }: TenantSummaryCardProps) {
  return (
    <Link
      className="block rounded-[1.75rem] border border-white/70 bg-white/80 p-5 shadow-soft transition hover:-translate-y-1"
      to={`/tenants/${tenant.name}`}
    >
      <p className="text-xs font-semibold uppercase tracking-[0.3em] text-steel">Tenant Namespace</p>
      <h3 className="mt-3 font-display text-3xl text-ink">{tenant.name}</h3>
      <p className="mt-2 text-sm text-ink/70">tenant={tenant.tenant}</p>
      <p className="mt-4 inline-flex rounded-full bg-moss/15 px-3 py-1 text-sm text-moss">{tenant.status}</p>
    </Link>
  );
}
