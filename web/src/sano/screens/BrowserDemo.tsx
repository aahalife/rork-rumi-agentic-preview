import React, { useEffect, useRef, useState } from 'react';
import { SitePreview } from '../ui/SitePreview';
import { EverydayPlan } from '../ui/EverydayPlan';
import { SampleRideCard } from '../ui/SampleRideCard';
import { cn } from '@/lib/utils';
import { Dialog, DialogContent, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { useSano } from '../store';
import { canStopDemo, demoActivity, demoScenarios, type DemoScenario } from '../browserDemo';
import { Icon } from '../ui/Icon';
import { BrandGlyph } from '../ui/BrandGlyph';
const glyphs: Record<DemoScenario, string> = { labs: 'file', visit: 'book', recipe: 'forkKnife', ride: 'car', activity: 'leaf' };

/** Root-owned tasks keep running while this optional browser sheet is closed. */
export const BrowserDemo: React.FC = () => {
  const s = useSano();
  const [request, setRequest] = useState<string>('');
  const [expanded, setExpanded] = useState<boolean>(false);
  const [approvalOpen, setApprovalOpen] = useState<boolean>(false);
  const chatEnd = useRef<HTMLDivElement>(null);
  const streamRef = useRef<HTMLDivElement>(null);
  const followRef = useRef<boolean>(true);
  const [newActivity, setNewActivity] = useState<boolean>(false);
  const demo = s.browserDemo;
  const dispatch = s.dispatchBrowserDemo;
  const scenario = demo.scenario ? demoScenarios[demo.scenario] : null;
  useEffect(() => { setApprovalOpen(demo.phase === 'review'); }, [demo.phase, demo.run, demo.detail]);
  useEffect(() => {
    const stream = streamRef.current;
    if (followRef.current && stream) stream.scrollTop = stream.scrollHeight;
    else setNewActivity(true);
  }, [demo.messages.length, demo.phase, demo.step]);
  const control = (label: string, action: () => void) => <button onClick={action} className="press min-h-11 flex-1 rounded-full glass brand-ink px-4 py-3 font-rounded text-sm font-semibold">{label}</button>;
  const start = (kind: DemoScenario) => {
    const appointment = s.appointments.find(a => a.kind === 'inPerson' && a.status !== 'cancelled') ?? s.appointments[0];
    let detail: string;
    if (kind === 'labs') {
      const series = s.labSeries.find(item => item.id === s.resultToAck?.series) ?? s.labSeries[0];
      const latest = series?.points.slice().sort((a, b) => b.date - a.date)[0];
      detail = `Review ${s.persona.firstName}’s result. ${series?.name ?? 'Result'}: ${latest?.value ?? '—'} ${series?.unit ?? ''}. Suggested question: ${series?.explainAsk ?? 'What should I ask at my next visit?'} No diagnosis or medication change is proposed.`;
    } else if (kind === 'visit') detail = `Discussion guide for ${appointment?.with ?? s.persona.officeName}.\n• ${s.guideItems.filter(g => !g.resolved).map(g => g.text).join('\n• ') || 'What should we focus on at this visit?'}\nSend this exact message through the sample portal; no external delivery.`;
    else if (kind === 'recipe') detail = 'Curate my saved recipes for today’s dinner.';
    else if (kind === 'activity') detail = '15-minute gentle mobility & a short walk from @move.kindly. Low impact; adapt to your comfort and existing care-team restrictions. Planned, not logged as completed. This post is not a clinical exercise prescription.';
    else detail = `$24 sample UberX from Home to ${appointment?.location ?? 'Clinic'} for ${appointment?.with ?? s.persona.officeName}. Appointment ${new Date(appointment?.date ?? Date.now()).toLocaleString()}. Pickup 45 minutes before, 25-minute sample route, 20-minute arrival buffer. $0 sample cancellation fee. No real booking or charge.`;
    dispatch({ type: 'start', scenario: kind, patient: s.persona.firstName, detail, preferences: s.mealPreferences, appointmentId: appointment?.id, appointmentDate: appointment?.date, destination: appointment?.location });
  };
  const status = demo.phase === 'review' ? 'Needs your okay' : demo.phase === 'login' || demo.phase === 'browsing' ? 'Working autonomously' : demo.phase === 'done' ? 'Finished' : demo.phase;
  return <div className={cn('brand-atmosphere', scenario ? 'h-full flex flex-col p-3 gap-2 overflow-hidden' : 'p-5 pb-12 min-h-full')}>
    <header className="flex justify-between gap-3 items-center shrink-0"><div className="flex gap-3 items-center"><BrandGlyph name="sparkles" /><h1 className="font-serif text-ink text-[26px]">Rumi’s work</h1></div><button onClick={() => s.setShowAgentNetwork(false)} className="min-h-11 px-2 brand-ink font-rounded text-sm">Minimize</button></header>
    <aside className="organic rounded-2xl p-2 shrink-0 text-ink-muted"><p className="font-rounded text-xs"><strong>{s.persona.firstName}’s sample workspace</strong> · Autonomous site mockups, no live accounts or payments.</p></aside>
    {!scenario ? <div className="mt-5 space-y-3">
      {(Object.keys(demoScenarios) as DemoScenario[]).map(kind => <button key={kind} onClick={() => start(kind)} className="press organic rounded-[26px] p-5 min-h-20 w-full flex gap-4 items-center text-left text-ink font-serif text-xl"><BrandGlyph name={glyphs[kind]} /><span className="flex-1">{demoScenarios[kind].title}</span><Icon name="arrowUpRight" size={20} /></button>)}
      <EverydayPlan />
    </div> : <div className="flex-1 min-h-0 flex flex-col gap-2">
      <h2 className="font-serif text-lg text-ink shrink-0">{scenario.title}</h2>
      <section className={cn('rounded-3xl organic overflow-y-auto shrink-0', expanded && demo.phase !== 'review' ? 'max-h-[55dvh]' : 'max-h-[33dvh]', demo.phase === 'browsing' && !demo.collapsed && 'browser-working-frame')} aria-label="Browser preview">
        <div className="sticky top-0 z-20 bg-surface flex items-center">
          <button aria-label={demo.collapsed ? 'Expand browser preview' : 'Collapse browser preview'} aria-expanded={!demo.collapsed} onClick={() => dispatch({ type: 'collapse' })} className="min-h-11 flex-1 p-3 flex justify-between items-center text-ink font-rounded text-sm font-semibold"><span className="flex gap-2 items-center"><Icon name="globe" size={16} />Browser preview</span>{demo.collapsed ? 'Expand' : 'Collapse'}</button>
          {!demo.collapsed && <button onClick={() => setExpanded(v => !v)} className="min-h-11 px-3 text-xs brand-ink">{expanded ? 'Split view' : 'Larger view'}</button>}
        </div>
        {!demo.collapsed && <SitePreview demo={demo} login={() => dispatch({ type: 'login' })} />}
      </section>
      {demo.phase === 'review' && <button onClick={() => setApprovalOpen(true)} className="shrink-0 min-h-12 rounded-2xl bg-[#F3E5BA] text-[#003B30] px-4 flex items-center justify-between font-rounded text-sm font-semibold"><span aria-live="polite">Your approval is needed</span><span>Review proposal ↗</span></button>}
      <Dialog open={approvalOpen && demo.phase === 'review'} onOpenChange={setApprovalOpen}>
        <DialogContent className="w-[calc(100%-2rem)] max-w-[400px] max-h-[85dvh] rounded-[28px] bg-base text-ink p-5 gap-3">
          <DialogTitle className="font-serif text-2xl pr-8">Before I continue</DialogTitle>
          <DialogDescription className="font-rounded text-sm text-ink-muted">Review this exact proposal. Nothing happens until you approve.</DialogDescription>
          <section aria-label="Action approval" className="min-h-0 overflow-y-auto max-h-[45dvh] rounded-2xl bg-surface p-4"><p className="font-rounded text-sm whitespace-pre-line break-words">{demo.detail}</p><p className="font-rounded text-xs text-ink-muted mt-3">Sample task · no real booking, payment or delivery.</p></section>
          <div className="flex gap-2">{control('Approve', () => { dispatch({ type: 'approve' }); setApprovalOpen(false); })}{control('Decline', () => { dispatch({ type: 'stop' }); setApprovalOpen(false); })}</div>
          {demo.scenario === 'ride' && control('Preview a changed fare', () => dispatch({ type: 'changeFare' }))}
          <button onClick={() => setApprovalOpen(false)} className="min-h-11 font-rounded text-sm text-ink-muted">Review later · keep paused</button>
        </DialogContent>
      </Dialog>
      {newActivity && <button onClick={() => { followRef.current = true; setNewActivity(false); const el = streamRef.current; if (el) el.scrollTop = el.scrollHeight; }} className="shrink-0 min-h-11 glass rounded-full brand-ink font-rounded text-sm">New activity ↓</button>}
      <div ref={streamRef} onScroll={() => { const el = streamRef.current; if (el) { followRef.current = el.scrollHeight - el.scrollTop - el.clientHeight < 80; if (followRef.current) setNewActivity(false); } }} className="min-h-0 flex-1 overflow-y-auto space-y-4 pb-3">
        <p className="font-rounded text-xs font-semibold brand-ink flex items-center gap-2" role="status"><span className="size-2 rounded-full bg-life" />{status}</p>
        <section aria-label="Browser conversation" className="organic rounded-3xl p-4 space-y-3">
          <h3 className="font-rounded text-sm font-semibold brand-ink">Rumi · working with you</h3>
          <div className="space-y-4" aria-label="Task conversation"><p className="font-rounded text-xs text-ink-muted border-l-2 border-[#4BC5AB] pl-3">{demoActivity(demo)}</p>{demo.messages.map((message, index) => <p key={index} className={cn('font-rounded text-sm rounded-2xl px-4 py-3 whitespace-pre-line', message.role === 'you' ? 'bg-[#003B30] text-white ml-8' : 'text-ink bg-surface mr-3')}>{message.text}</p>)}<div ref={chatEnd} /></div>
          <div className="flex gap-2">{control('Explain this', () => dispatch({ type: 'followup', text: 'Explain this' }))}{demo.scenario === 'recipe' && control('Plan this week', () => dispatch({ type: 'followup', text: 'Plan this week' }))}</div>
        </section>
        {demo.phase === 'browsing' && <div className="flex gap-2">{control('Pause', () => dispatch({ type: 'pause' }))}{control('Stop', () => dispatch({ type: 'stop' }))}</div>}
        {demo.phase === 'paused' && control('Resume', () => dispatch({ type: 'resume' }))}
        {demo.phase === 'failed' && control('Try again', () => dispatch({ type: 'retry' }))}
        {demo.phase === 'done' && (demo.scenario === 'recipe' || demo.scenario === 'activity') && <details className="organic rounded-3xl p-4"><summary className="min-h-11 font-rounded text-sm brand-ink cursor-pointer">Saved plan · view details</summary><EverydayPlan /></details>}
        {demo.phase === 'done' && demo.scenario === 'ride' && <SampleRideCard appointmentId={demo.appointmentId} />}
        {demo.phase === 'done' && (demo.scenario === 'labs' || demo.scenario === 'visit') && control('Open my discussion guide', () => { s.setPendingCareDest({ t: 'visitPrep' }); s.setTab('care'); s.setShowAgentNetwork(false); })}
        {(demo.phase === 'done' || demo.phase === 'stopped') && control('Choose another task', () => dispatch({ type: 'reset' }))}
        {canStopDemo(demo.phase) && demo.phase !== 'browsing' && control('Cancel task', () => dispatch({ type: 'stop' }))}
      </div>
      <form onSubmit={event => { event.preventDefault(); dispatch({ type: 'followup', text: request }); setRequest(''); }} className="flex gap-2 shrink-0 organic rounded-full p-1"><input aria-label="Ask about this page" maxLength={2000} value={request} onChange={event => setRequest(event.target.value)} placeholder="Ask a question or add a goal…" className="min-w-0 flex-1 min-h-12 bg-transparent text-ink rounded-full px-4 font-rounded text-sm outline-none focus-visible:ring-2 focus-visible:ring-[#4BC5AB]" /><button disabled={!request.trim()} className="min-h-12 px-4 rounded-full bg-[#003B30] text-white disabled:opacity-40" aria-label="Send follow-up"><Icon name="arrowUp" size={18} /></button></form>
    </div>}
  </div>;
};
