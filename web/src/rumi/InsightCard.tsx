import { useState } from 'react';
import { ChartNoAxesCombined, ChevronDown } from 'lucide-react';
import { dateLabel, number, profiles, units, type Insight, type Series } from './model';
export default function InsightCard({ insight }: { insight: Insight }) {
  return <article className="rw-insight"><div className="rw-eyebrow"><ChartNoAxesCombined size={15} /> App-calculated sample facts</div><h3>{insight.query.operation === 'sideBySide' ? 'Side by side. Not a relationship.' : insight.query.operation === 'cohort' ? 'Comparison data unavailable' : 'Your sample numbers'}</h3><p className="rw-small">{profiles[insight.member].name} · {insight.query.days ? `Last ${insight.query.days} days` : 'All available sample dates'}</p>{insight.series.map(s => <SeriesChart key={s.metric} series={s} anchor={insight.anchor} />)}{insight.series.length === 2 && <p className="rw-small">Independent dates, units and axes. No correlation or causal relationship is calculated.</p>}</article>;
}
function SeriesChart({ series, anchor }: { series: Series; anchor: number }) {
  const [range, setRange] = useState(0); const [selected, setSelected] = useState<number | null>(null);
  const cutoff = new Date(anchor); cutoff.setDate(cutoff.getDate() - range);
  const points = series.points.filter(p => !range || p.date >= cutoff.getTime());
  const focused = points[selected ?? points.length - 1];
  const min = Math.min(...points.map(p => p.value)); const max = Math.max(...points.map(p => p.value)); const padding = Math.max((max - min) * .25, max * .02, .1);
  const minDate = points[0]?.date ?? 0; const maxDate = points[points.length - 1]?.date ?? 0;
  const x = (date: number) => points.length === 1 ? 250 : 42 + ((date - minDate) / (maxDate - minDate || 1)) * 418;
  const y = (value: number) => 160 - ((value - min + padding) / (max - min + 2 * padding)) * 132;
  return <section className="rw-series"><div className="rw-between"><h4>{series.metric}</h4>{series.points.length > 0 && <div className="rw-segment" aria-label={`${series.metric} chart range`}>{[30, 90, 0].map(r => <button key={r} aria-pressed={range === r} onClick={() => { setRange(r); setSelected(null); }}>{r ? `${r}d` : 'All'}</button>)}</div>}</div>
    {focused ? <><div className="rw-metric">{number(focused.value)} <span>{units[series.metric]}</span></div><p className="rw-small">Illustrative date · {dateLabel(focused.date)}</p><svg role="img" aria-label={`${series.metric} sample trend. Exact dates and values are in the disclosure below.`} viewBox="0 0 500 200" className="rw-chart" onPointerMove={e => { const rect = e.currentTarget.getBoundingClientRect(); const at = ((e.clientX - rect.left) / rect.width) * 500; const nearest = points.reduce((best, p, i) => Math.abs(x(p.date) - at) < Math.abs(x(points[best].date) - at) ? i : best, 0); setSelected(nearest); }}>
      {[0, 1, 2].map(i => { const value = min - padding + (max - min + 2 * padding) * i / 2; return <g key={i}><line x1="42" x2="460" y1={y(value)} y2={y(value)} stroke="#d9e6df" strokeDasharray="3 5" /><text x="2" y={y(value) + 4} fill="#57605d" fontSize="10">{number(value)}</text></g>; })}
      {points.length > 1 && <polyline points={points.map(p => `${x(p.date)},${y(p.value)}`).join(' ')} fill="none" stroke="#006b58" strokeWidth="2.5" strokeLinejoin="round" />}
      {points.map((p, i) => <circle key={p.date} cx={x(p.date)} cy={y(p.value)} r={i === (selected ?? points.length - 1) ? 6 : 4} fill="#006b58" stroke="white" strokeWidth="2" />)}
      <text x="42" y="192" fill="#57605d" fontSize="11">{new Date(minDate).toLocaleDateString(undefined, { month: 'short', year: '2-digit' })}</text><text x="460" y="192" fill="#57605d" fontSize="11" textAnchor="end">{new Date(maxDate).toLocaleDateString(undefined, { month: 'short', year: '2-digit' })}</text>
    </svg><p className="rw-small">Move over the chart to inspect · {points.length} observations</p></> : series.points.length > 0 ? <p className="rw-note">No observations in this window. Select All to recover the requested sample results.</p> : null}
    <div className="rw-facts">{series.facts.map(f => <p key={f}>{f}</p>)}</div><p className="rw-small">{series.limitation}</p>
    {points.length > 0 && <details><summary>Accessible values & sample dates <ChevronDown size={16} /></summary><div className="rw-values">{points.map((p, i) => <button key={p.date} className="rw-row" onFocus={() => setSelected(i)} onClick={() => setSelected(i)}><span>{dateLabel(p.date)}</span><strong>{number(p.value)} {units[series.metric]}</strong></button>)}</div></details>}
  </section>;
}
