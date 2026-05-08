type StatusCardProps = {
  title: string;
  value: string;
  hint?: string;
};

export function StatusCard({ title, value, hint }: StatusCardProps) {
  return (
    <div className="rounded-[1.75rem] border border-white/70 bg-white/80 p-5 shadow-soft backdrop-blur">
      <p className="text-xs font-semibold uppercase tracking-[0.3em] text-steel">{title}</p>
      <p className="mt-3 font-display text-3xl text-ink">{value}</p>
      {hint ? <p className="mt-2 text-sm text-ink/70">{hint}</p> : null}
    </div>
  );
}
