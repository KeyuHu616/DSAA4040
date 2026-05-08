type TestResultPanelProps = {
  title: string;
  content: string | null;
};

export function TestResultPanel({ title, content }: TestResultPanelProps) {
  return (
    <div className="rounded-[1.75rem] border border-white/70 bg-white/80 p-5 shadow-soft backdrop-blur">
      <h3 className="font-display text-2xl text-ink">{title}</h3>
      <pre className="mt-4 max-h-80 overflow-auto rounded-2xl bg-paper p-4 text-xs leading-6 text-ink/80">
        {content ?? 'No evidence loaded.'}
      </pre>
    </div>
  );
}
