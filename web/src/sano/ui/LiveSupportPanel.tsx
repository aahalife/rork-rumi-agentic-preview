import { useSano } from '../store';
import { OrganicCard, Kicker } from './Glass';

/** AI-derived observations remain distinct from the static sample insight collection. */
export function LiveSupportPanel() {
  const s = useSano();
  if (!s.aiConsent) return null;
  const items = s.liveSupport.filter(item => Date.now() - item.at < 86400000).slice(0, 3);
  return <section className="mt-5 space-y-3">
    <Kicker>Live support · when useful</Kicker>
    <p role="status" className="font-rounded text-xs text-ink-muted">{s.supportStatus}</p>
    <div className="flex gap-2 flex-wrap">
      <button onClick={() => void s.refreshSupport('nudge')} className="min-h-11 rounded-full glass px-4 brand-ink font-rounded text-sm">One gentle next step</button>
      <button onClick={() => void s.refreshSupport('insight')} className="min-h-11 rounded-full glass px-4 brand-ink font-rounded text-sm">Reflect on my logs</button>
    </div>
    {items.map((item, i) => <details key={item.id} open={i === 0} className="organic rounded-3xl p-4">
      <summary className="min-h-11 cursor-pointer font-serif text-xl text-ink">{item.title}</summary>
      <OrganicCard className="p-3"><p className="font-rounded text-sm text-ink whitespace-pre-line">{item.body}</p><p className="font-rounded text-xs text-ink-muted mt-2">Rumi AI · {new Date(item.at).toLocaleString()} · AI observation, not medical advice</p>
        <details className="mt-2"><summary className="min-h-11 font-rounded text-sm cursor-pointer brand-ink">Why this?</summary>{item.evidence.map(e => <p key={e.id} className="font-rounded text-xs text-ink-muted whitespace-pre-wrap break-words mb-3">{e.text}</p>)}</details>
        <div className="flex gap-4"><button onClick={() => s.openConversation(`Live ${item.kind}: ${item.title}. ${item.body}. Evidence: ${item.evidence.map(e => e.text).join('; ')}`)} className="min-h-11 font-rounded text-sm brand-ink">Talk about this</button><button onClick={() => s.dismissSupport(item.id)} className="min-h-11 font-rounded text-sm text-ink-muted">Not now · rest for a day</button></div>
      </OrganicCard>
    </details>)}
  </section>;
}
