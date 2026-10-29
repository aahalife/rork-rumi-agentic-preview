import React, { useEffect, useRef } from 'react';
import { LockKeyhole, ChevronLeft, RotateCw, Menu, Car, CalendarDays, Bell, CheckCircle, UserRound, MapPin } from 'lucide-react';
import { useSano } from '../store';
import { type BrowserDemoState } from '../browserDemo';
import { SocialRecipePreview } from './SocialRecipePreview';
import { cn } from '@/lib/utils';

/** Inert branded layouts; sample login is fixed and advances automatically. */
export function SitePreview({ demo, login }: { demo: BrowserDemoState; login: () => void }) {
  const s = useSano();
  const health = demo.scenario === 'labs' || demo.scenario === 'visit';
  const social = demo.scenario === 'recipe' || demo.scenario === 'activity';
  const brand = health ? 'MyChart' : social ? 'Instagram' : 'Uber';
  const working = demo.phase === 'browsing';
  const page = useRef<HTMLDivElement>(null);
  const appointment = s.appointments.find(a => a.id === demo.appointmentId) ?? s.appointments[0];
  useEffect(() => {
    if (!working) return;
    const target = page.current?.querySelector(`[data-step="${demo.step}"]`);
    target?.scrollIntoView?.({ block: 'nearest', behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth' });
  }, [working, demo.step]);
  const field = (label: string, value: string) => <div><p className="text-xs text-gray-600 mb-1">{label}</p><div aria-label={`${label}: fixed sample value`} className="rounded border border-gray-300 bg-gray-50 px-3 py-3 text-sm">{value}</div></div>;
  const mark = (step: number) => cn('relative rounded-xl border p-3 transition-colors', working && demo.step === step ? 'browser-action-target border-emerald-400 bg-emerald-50 ring-2 ring-emerald-200' : 'border-gray-200 bg-white');
  return <div ref={page} className={cn('relative bg-white text-gray-950 font-sans rounded-b-3xl overflow-hidden', working && 'browser-working')}>
    <div className="flex items-center gap-2 px-3 py-3 bg-gray-50 border-y border-gray-200 text-[10px]"><ChevronLeft size={15} /><LockKeyhole size={12} /><span className="flex-1 truncate">{health ? 'mychart.sample' : social ? 'instagram.sample' : 'm.uber.sample'}/{demo.phase === 'login' ? 'login' : health ? demo.scenario === 'labs' ? 'test-results' : 'messages' : social ? 'saved' : 'reserve'}</span><span className="text-gray-500">Mockup</span><RotateCw size={14} /></div>
    <div className={cn('flex items-center justify-between px-5 py-4 border-b', health ? 'bg-[#1663AA] text-white border-[#1663AA]' : 'bg-white border-gray-200')}><div className="flex items-center gap-2"><Menu size={17} /><span className={cn('text-[26px] tracking-tight', health && 'font-bold', social && 'font-serif italic font-bold', !health && !social && 'font-medium')}>{brand}</span></div>{demo.phase !== 'login' && <span className="text-xs flex gap-2 items-center">{demo.patient}<UserRound size={16} /></span>}</div>
    {demo.phase === 'login' ? <div className="p-5 space-y-4 min-h-[300px]">
      <h3 className="text-xl font-semibold">{health ? 'Sign in to MyChart' : social ? 'Welcome back' : 'What’s your phone number or email?'}</h3>
      {field(health ? 'MyChart username' : social ? 'Phone number, username, or email' : 'Email', `${demo.patient.toLowerCase()}.sample`)}
      {(health || social) && field('Password', '••••••••••••')}
      <button onClick={login} className={cn('w-full min-h-12 text-white text-sm font-semibold rounded', health ? 'bg-[#1663AA]' : social ? 'bg-[#0095F6]' : 'bg-black')}>Sign in as {demo.patient}</button>
      <p className="text-xs text-gray-500">Rumi is opening this fixed sample account automatically. No real credentials are accepted.</p>
    </div> : social ? <SocialRecipePreview demo={demo} /> : health ? <div className="p-4 space-y-4 min-h-[360px]">
      <div className="flex gap-4 text-xs text-[#1663AA] border-b pb-3"><span>Home</span><span>Visits</span><span>Messages</span><span>Test results</span><Bell size={14} /></div>
      <p className="text-[10px] text-gray-500">Home / Health / {demo.scenario === 'labs' ? 'Test results' : 'Message center'}</p>
      <h3 className="text-xl font-bold">{demo.scenario === 'labs' ? 'Test results' : demo.step === 0 ? 'Upcoming visit' : 'New message'}</h3>
      {demo.scenario === 'labs' ? <><p className="text-xs text-gray-600">Results from your sample record · your care team can help interpret them.</p>{s.labSeries.slice(0, 3).map((series, index) => { const points = series.points.slice().sort((a, b) => b.date - a.date); const latest = points[0]; return <div key={series.id} data-step={index} className={mark(index)}><p className="text-[10px] text-gray-500">{latest ? new Date(latest.date).toLocaleDateString() : ''} · Final result</p><div className="flex justify-between gap-2 text-sm font-semibold mt-1"><span>{series.name}</span><span>{latest?.value ?? '—'} {series.unit}</span></div><p className="text-[11px] text-gray-500 mt-2">{series.bandLabel ?? 'Reference range'} {series.band?.join('–')}</p><div className="h-2 rounded bg-blue-100 my-2" /><p className="text-xs text-gray-700">{series.explainReading}</p><p className="text-[11px] text-gray-500 mt-2">Previous: {points[1]?.value ?? '—'} {series.unit} · {series.provenance}</p><p className="text-xs text-[#1663AA] mt-2">View result history →</p></div>; })}<div className="rounded-xl bg-blue-50 p-3 text-xs text-[#1663AA]">Rumi adds your question to your local discussion guide. No clinical decision is made.</div></> : <>
        <div data-step="0" className={mark(0)}><p className="text-sm font-bold flex gap-2"><CalendarDays size={17} />{appointment?.with ?? s.persona.officeName}</p><p className="text-xs text-gray-500 mt-2">{new Date(appointment?.date ?? Date.now()).toLocaleString()}</p><p className="text-xs mt-1">{appointment?.location ?? 'Clinic'} · Arrival 15 minutes early</p><p className="text-[10px] mt-2 text-green-700">Confirmed · Sample portal appointment</p></div>
        <div data-step="1" className={mark(1)}><p className="text-xs text-gray-500 mb-2">To: {appointment?.with ?? 'Care team'} · Subject: Upcoming visit questions</p><p className="text-sm whitespace-pre-line">{demo.detail}</p></div>
        <div data-step="2" className={mark(2)}><p className="text-sm font-semibold text-[#1663AA]">{demo.phase === 'done' ? 'Message sent in sample portal' : 'Send message →'}</p><p className="text-[11px] text-gray-500 mt-1">{demo.phase === 'done' ? 'No external delivery' : 'Not sent · waiting for your permission'}</p></div>
      </>}
    </div> : <div className="space-y-4 p-4">
      <div className="flex gap-4 text-xs border-b pb-3"><span className="font-bold border-b-2 border-black">Ride</span><span>Reserve</span><span>Activity</span></div>
      <div aria-label="Illustrative route map" className="relative rounded-xl overflow-hidden bg-[#eef0e9] h-40"><svg viewBox="0 0 340 160" className="w-full h-full" role="img" aria-label="Sample route from home to clinic"><path d="M0 25H340M0 60H340M0 115H340M40 0V160M100 0V160M175 0V160M250 0V160M310 0V160" stroke="white" strokeWidth="8" /><path d="M0 140Q100 80 120 0" stroke="#d1e1d3" strokeWidth="25" fill="none" /><path d="M40 115H175V60H250V25" stroke="#171717" strokeWidth="4" fill="none" /><circle cx="40" cy="115" r="6" fill="black" /><rect x="244" y="19" width="12" height="12" fill="black" /><text x="15" y="140" fontSize="10">Home</text><text x="260" y="25" fontSize="10">Clinic</text><text x="183" y="103" fontSize="10" fill="#7a8277">25 min</text></svg><span className="absolute bottom-2 right-2 bg-white px-2 py-1 rounded text-[9px]">Illustrative map · not GPS</span></div>
      <h3 className="text-xl font-semibold">{demo.phase === 'done' ? 'Your reserved ride' : 'Reserve a ride for your visit'}</h3>
      <div data-step="0" className={mark(0)}><p className="text-xs text-gray-500">Pickup · {new Date(demo.appointmentDate - demo.pickupOffset * 60000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</p><p className="text-sm font-semibold">Home</p><p className="text-xs mt-1">{demo.pickupOffset}-minute appointment buffer</p></div>
      <div data-step="1" className={mark(1)}><p className="text-xs text-gray-500 flex gap-1"><MapPin size={12} />Destination</p><p className="text-sm font-semibold">{demo.destination || 'Clinic'}</p><p className="text-xs mt-1 text-gray-500">{appointment?.with} · {new Date(demo.appointmentDate).toLocaleString()}</p></div>
      <div data-step="2" className={mark(2)}><div className="flex items-center gap-3"><Car size={32} /><div className="flex-1"><p className="text-sm font-bold">UberX</p><p className="text-xs text-gray-500">4 seats · 25 min · sample fare</p></div><strong>${demo.fare}</strong></div><div className="border-t mt-3 pt-3 flex justify-between text-xs"><span>Comfort · 4 seats</span><span>${demo.fare + 12}</span></div><div className="border-t mt-3 pt-3 flex justify-between text-xs"><span>UberXL · 6 seats</span><span>${demo.fare + 18}</span></div></div>
      <div className="flex justify-between text-xs text-gray-500"><span>Sample Visa •••• 4242</span><span>Personal</span></div><div className="rounded-lg bg-black text-white min-h-11 flex items-center justify-center font-semibold text-sm">{demo.phase === 'done' ? <><CheckCircle size={16} className="mr-2" />Sample ride {demo.rideAction === 'cancel' ? 'cancelled' : 'reserved'}</> : 'Reserve UberX · waiting for approval'}</div>
    </div>}
  </div>;
}
