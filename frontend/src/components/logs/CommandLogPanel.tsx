import type { TaskRecord } from '../../lib/api';

type CommandLogPanelProps = {
  run: TaskRecord | null;
};

export function CommandLogPanel({ run }: CommandLogPanelProps) {
  if (!run) {
    return (
      <div className="rounded-[1.75rem] border border-dashed border-ink/20 bg-white/50 p-5 text-sm text-ink/70">
        No command has been triggered from this page yet.
      </div>
    );
  }

  const outputSections = [
    { label: 'Standard Output', content: run.log?.stdout?.trim() ?? '' },
    { label: 'Standard Error', content: run.log?.stderr?.trim() ?? '' },
  ].filter((section) => section.content.length > 0);

  return (
    <div className="rounded-[1.75rem] border border-white/70 bg-ink p-5 text-paper shadow-soft">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-xs uppercase tracking-[0.3em] text-sun">{run.action}</p>
          <p className="mt-2 text-sm">Status: {run.status}</p>
          <p className="mt-2 text-xs text-paper/75">Command: {run.argv.join(' ')}</p>
        </div>
        <div className="text-sm">
          <div>Exit code: {run.exit_code ?? 'pending'}</div>
          <div>Timed out: {run.timed_out ? 'yes' : 'no'}</div>
          <div>Duration: {run.duration_seconds != null ? `${run.duration_seconds.toFixed(2)}s` : 'pending'}</div>
        </div>
      </div>
      <div className="mt-4 space-y-4">
        {outputSections.map((section) => (
          <div key={section.label}>
            <p className="mb-2 text-xs uppercase tracking-[0.28em] text-paper/65">{section.label}</p>
            <pre className="max-h-48 overflow-auto rounded-2xl bg-paper/10 p-4 text-xs leading-6">{section.content}</pre>
          </div>
        ))}
        {run.error ? (
          <div>
            <p className="mb-2 text-xs uppercase tracking-[0.28em] text-paper/65">Backend Error</p>
            <pre className="max-h-48 overflow-auto rounded-2xl bg-paper/10 p-4 text-xs leading-6">{run.error}</pre>
          </div>
        ) : null}
        {!run.error && outputSections.length === 0 ? (
          <pre className="max-h-48 overflow-auto rounded-2xl bg-paper/10 p-4 text-xs leading-6">No output captured yet.</pre>
        ) : null}
      </div>
    </div>
  );
}
