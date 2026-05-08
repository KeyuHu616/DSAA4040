import { useEffect, useState } from 'react';

import { api, type KubeconfigInfo } from '../lib/api';

export function RbacUsersPage() {
  const [kubeconfigs, setKubeconfigs] = useState<KubeconfigInfo[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.getKubeconfigs().then(setKubeconfigs).catch((reason: Error) => setError(reason.message));
  }, []);

  return (
    <section className="space-y-6">
      <div className="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-soft">
        <h2 className="font-display text-3xl text-ink">RBAC & Users</h2>
        <p className="mt-3 text-sm text-ink/75">
          Generated kubeconfigs are shown as safe top-level files only. Private keys and .generated internals are never exposed.
        </p>
      </div>
      {error ? <div className="rounded-3xl bg-ember px-5 py-4 text-white">{error}</div> : null}
      <div className="overflow-hidden rounded-[2rem] border border-white/70 bg-white/80 shadow-soft">
        <table className="min-w-full divide-y divide-ink/10 text-sm">
          <thead className="bg-paper/70 text-left text-ink/70">
            <tr>
              <th className="px-4 py-3">Filename</th>
              <th className="px-4 py-3">Username</th>
              <th className="px-4 py-3">Namespace</th>
              <th className="px-4 py-3">Size</th>
            </tr>
          </thead>
          <tbody>
            {kubeconfigs.map((item) => (
              <tr key={item.filename} className="border-t border-ink/5">
                <td className="px-4 py-3">{item.filename}</td>
                <td className="px-4 py-3">{item.username}</td>
                <td className="px-4 py-3">{item.namespace ?? 'n/a'}</td>
                <td className="px-4 py-3">{item.size_bytes} bytes</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
