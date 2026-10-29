import { SampleRideCard } from '../ui/SampleRideCard';
import React, { useEffect, useRef, useState } from "react";
import { useSano, type CareDest } from "../store";
import { OrganicCard, Glass, Press, Kicker, ProvenanceChip, accentText } from "../ui/Glass";
import { Icon } from "../ui/Icon";
import { BrandGlyph } from "../ui/BrandGlyph";
import { Sheet } from "../ui/Sheet";
import { useStack, SubScreen, HubHeader } from "./nav";
import { MedicationsScreen, MedDetailScreen, RecordsScreen, RecordCategoryScreen, LabDetailScreen, CarePlanScreen, GuideScreen } from "./shared";
import { fmtMonthDay, fmtTime } from "../lifeLibrary";
import { type DoctorReport, type ReportKind } from "../agentNetwork";

const destToRoute = (d: CareDest): { name: string; params?: Record<string, unknown> } => {
  switch (d.t) {
    case "appointmentDetail": return { name: "appointmentDetail", params: { id: d.id } };
    case "medications": return { name: "medications" };
    case "records": return { name: "records" };
    default: return { name: d.t };
  }
};

export const CareHub: React.FC = () => {
  const s = useSano();
  const nav = useStack({ name: "hub" });

  useEffect(() => {
    if (s.pendingCareDest) { nav.push(destToRoute(s.pendingCareDest)); s.setPendingCareDest(null); }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [s.pendingCareDest]);

  const push = (name: string, params?: Record<string, unknown>) => nav.push({ name, params });
  const p = (nav.top.params ?? {}) as Record<string, string>;

  if (nav.top.name === "hub") return <Hub push={push} />;
  return (
    <SubScreen onBack={nav.pop} back={nav.stack.length > 2 ? "Back" : "Care"}>
      {nav.top.name === "appointments" && <Appointments push={push} />}
      {nav.top.name === "appointmentDetail" && <AppointmentDetail id={p.id} push={push} />}
      {nav.top.name === "carePlan" && <CarePlanScreen />}
      {nav.top.name === "visitPrep" && <GuideScreen />}
      {nav.top.name === "reports" && <Reports />}
      {nav.top.name === "connections" && <Connections />}
      {nav.top.name === "medications" && <MedicationsScreen push={push} />}
      {nav.top.name === "medDetail" && <MedDetailScreen id={p.id} push={push} />}
      {nav.top.name === "records" && <RecordsScreen push={push} />}
      {nav.top.name === "recordCategory" && <RecordCategoryScreen category={p.category as never} push={push} />}
      {nav.top.name === "labDetail" && <LabDetailScreen id={p.id} />}
    </SubScreen>
  );
};

const tiles: { name: string; label: string; glyph: string; accent: string; status: (s: ReturnType<typeof useSano>) => string; badge?: (s: ReturnType<typeof useSano>) => number }[] = [
  { name: "appointments", label: "Appointments", glyph: "calendar", accent: "gold", status: (s) => s.appointments[0] ? `Next ${fmtMonthDay(s.appointments[0].date)}` : "Nothing scheduled" },
  { name: "carePlan", label: "Care plan", glyph: "leaf", accent: "life", status: (s) => `${s.persona.carePlan.goals.length} goals from your team` },
  { name: "medications", label: "Medications", glyph: "pills", accent: "warm", status: (s) => `${s.medications.length} in your plan` },
  { name: "records", label: "Records", glyph: "droplet", accent: "rose", status: (s) => `${s.recordItems.length} items, reconciled`, badge: (s) => (!s.resultAcknowledged && s.resultToAck ? 1 : 0) },
  { name: "visitPrep", label: "Visit prep", glyph: "book", accent: "warm", status: (s) => `${s.guideItems.filter((g) => !g.resolved).length} on your guide` },
  { name: "reports", label: "Visit reports", glyph: "file", accent: "sky", status: (s) => { const n = s.careTeam.filter((m) => !m.role.toLowerCase().includes("pharmacy")).length; return n ? `${n} ready to review` : "For your visits"; } },
  { name: "connections", label: "Connections", glyph: "link", accent: "rose", status: (s) => { const c = s.connections.filter((x) => x.connected).length; return c ? `${c} connected` : "Bring your world in"; } },
];

const Hub: React.FC<{ push: (n: string, p?: Record<string, unknown>) => void }> = ({ push }) => {
  const s = useSano();
  const [section, setSection] = useState<"daily" | "visits" | "records">("daily");
  const groups: Record<typeof section, string[]> = { daily: ["appointments", "carePlan", "medications"], visits: ["appointments", "visitPrep", "reports"], records: ["records", "connections"] };
  const subtitle = s.pathway === "metabolic" ? "Your team, your plan, and the day-to-day — handled." : s.pathway === "oncology" ? "Everything around treatment, in one calm place." : "Surgery logistics, your team, and the road to recovery.";
  return (
    <div className="absolute inset-0 overflow-y-auto px-5 pb-32">
      <HubHeader title="Care" subtitle={subtitle} rightPad />
      <div className="mt-6 space-y-3">{[
        { title: 'Prepare for my visit', detail: 'Gather your questions in a discussion guide.', glyph: 'book', action: () => push('visitPrep'), color: 'bg-[#FFE580]/30' },
        { title: 'Ask Rumi to handle something', detail: 'Messages, refills and bills in your own portal, plus recipes and rides.', glyph: 'sparkles', action: () => s.setShowAgentNetwork(true), color: 'brand-soft' },
        { title: 'Review work needing permission', detail: 'You decide what happens next.', glyph: 'hand', action: () => s.setShowAgentNetwork(true), color: 'brand-soft' },
      ].map((row) => <button key={row.title} onClick={row.action} className={`press w-full rounded-3xl p-5 flex items-center gap-4 text-left text-ink organic`}><BrandGlyph name={row.glyph} /><span className="flex-1"><span className="block font-serif text-[20px]">{row.title}</span><span className="block font-rounded text-[14px] text-ink-muted mt-1">{row.detail}</span></span><Icon name="chevronRight" size={16} /></button>)}</div>
      {s.needsYou.length > 0 && (
        <div className="mt-5">
          <Kicker className="text-warm mb-2">Needs you</Kicker>
          <div className="space-y-2">
            {s.needsYou.map((n) => (
              <Press key={n.id + n.kind} onClick={() => push(destToRoute(n.destination).name, destToRoute(n.destination).params)} className="w-full text-left">
                <OrganicCard className="p-3.5 flex items-center gap-3">
                  <div className="size-9 rounded-full grid place-items-center shrink-0" style={{ background: "rgb(var(--warm) / 0.18)" }}><Icon name={needGlyph(n.kind)} size={16} className="text-warm" /></div>
                  <div className="flex-1 min-w-0"><p className="font-rounded text-[14px] text-ink font-medium leading-tight">{n.title}</p><p className="font-rounded text-[12px] text-ink-muted truncate">{n.detail}</p></div>
                  <Icon name="chevronRight" size={16} className="text-ink-muted" />
                </OrganicCard>
              </Press>
            ))}
          </div>
        </div>
      )}
      <details className="mt-6"><summary className="min-h-12 cursor-pointer font-rounded text-[16px] brand-ink">Records & care tools</summary>
      <div role="tablist" aria-label="Care section" className="mt-5 flex rounded-full glass p-1">
        {([['daily', 'Daily care'], ['visits', 'Visits'], ['records', 'Records']] as const).map(([id, label]) => <button key={id} role="tab" aria-selected={section === id} onClick={() => setSection(id)} className={`flex-1 min-h-11 rounded-full font-rounded text-[13px] ${section === id ? 'brand-soft brand-ink' : 'text-ink-muted'}`}>{label}</button>)}
      </div>
      <div className="grid grid-cols-2 gap-3 mt-5">
        {tiles.filter((t) => groups[section].includes(t.name)).map((t) => {
          const badge = t.badge?.(s) ?? 0;
          return (
            <Press key={t.name} onClick={() => push(t.name)} className="text-left">
              <OrganicCard className="p-4 h-full min-h-[96px] relative">
                {badge > 0 && <span className="absolute top-3 right-3 min-w-5 h-5 px-1.5 rounded-full grid place-items-center text-[11px] font-rounded font-bold text-base" style={{ background: "rgb(var(--warm))" }}>{badge}</span>}
                <div className="size-9 rounded-full grid place-items-center" style={{ background: `rgb(var(--${t.accent}) / 0.18)` }}><Icon name={t.glyph} size={17} className={accentText[t.accent]} /></div>
                <p className="font-serif text-[16px] text-ink mt-2.5">{t.label}</p>
                <p className="font-rounded text-[11.5px] text-ink-muted mt-0.5">{t.status(s)}</p>
              </OrganicCard>
            </Press>
          );
        })}
      </div>
      </details>
      {s.showsLookingAhead && s.lookingAhead && <LookingAhead push={push} />}
      <PortalNote />
      <ProvenanceChip text="Sample records · no live provider connection" className="mt-5 px-1" />
    </div>
  );
};
function needGlyph(k: string): string { return k === "result" ? "droplet" : "calendar"; }

/** Rumi complements the patient portal rather than duplicating it. */
const PortalNote: React.FC = () => {
  const s = useSano();
  return (
    <button onClick={() => s.setShowAgentNetwork(true)} className="press mt-5 w-full rounded-3xl glass p-4 flex items-start gap-3 text-left">
      <Icon name="globe" size={18} className="brand-ink mt-0.5 shrink-0" />
      <span className="flex-1">
        <span className="block font-rounded text-[14px] font-semibold text-ink">Messages, refills and bills stay in your portal</span>
        <span className="block font-rounded text-[12.5px] text-ink-muted mt-0.5 leading-snug">Rumi doesn't duplicate {s.persona.officeName}'s portal. Ask Rumi Works and it will sign in and do it there, with your okay before anything is sent or paid.</span>
      </span>
      <Icon name="chevronRight" size={14} className="text-ink-muted mt-1" />
    </button>
  );
};

const LookingAhead: React.FC<{ push: (n: string, p?: Record<string, unknown>) => void }> = ({ push }) => {
  const s = useSano();
  const la = s.lookingAhead!;
  const [why, setWhy] = useState(false);
  const [added, setAdded] = useState(false);
  return (
    <OrganicCard className="p-4 mt-5">
      <Kicker className="text-sky">A gentle look ahead</Kicker>
      <h3 className="font-serif text-[18px] text-ink mt-1">{la.headline}</h3>
      <p className="font-rounded text-[13px] text-ink-muted mt-1 leading-snug">{la.body}</p>
      <Press onClick={() => setWhy((v) => !v)} className="text-[12px] font-rounded text-sky font-medium mt-2">Why am I seeing this?</Press>
      {why && <p className="font-rounded text-[12px] text-ink-muted mt-1.5 leading-snug">{la.basis}</p>}
      <Press onClick={() => { if (!added) { s.addGuideItem("Question", la.guideQuestion, "A gentle look ahead"); setAdded(true); push("visitPrep"); } }} className="mt-3 rounded-full px-4 py-2 text-[13px] font-rounded font-semibold" style={{ background: "rgb(var(--ink))", color: "rgb(var(--base))" }}>{added ? "Added to your guide" : "Add to my guide"}</Press>
    </OrganicCard>
  );
};

// ---------- Appointments ----------
const Appointments: React.FC<{ push: (n: string, p?: Record<string, unknown>) => void }> = ({ push }) => {
  const s = useSano();
  return (
    <div className="space-y-3">
      <div><h1 className="font-serif text-[28px] text-ink">Appointments</h1><p className="font-rounded text-[13px] text-ink-muted mt-1">Everything coming up, and how to get there easily.</p></div>
      {[...s.appointments].sort((a, b) => a.date - b.date).map((a) => (
        <Press key={a.id} onClick={() => push("appointmentDetail", { id: a.id })} className="w-full text-left">
          <OrganicCard className="p-4 flex items-center gap-3.5">
            <div className="size-14 rounded-2xl grid place-items-center shrink-0" style={{ background: "rgb(var(--base))" }}>
              <span className="kicker text-warm leading-none">{new Date(a.date).toLocaleDateString([], { month: "short" })}</span>
              <span className="font-serif text-[22px] text-ink leading-none mt-0.5">{new Date(a.date).getDate()}</span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-serif text-[16px] text-ink leading-tight">{a.with}</p>
              <p className="font-rounded text-[12px] text-ink-muted truncate">{a.location}</p>
              <div className="flex items-center gap-1.5 mt-1.5">
                <span className="rounded-full px-2 py-0.5 text-[10px] font-rounded font-semibold glass text-sky">{a.kind === "telehealth" ? "Video" : "In person"}</span>
                {a.status === "pending" && <span className="rounded-full px-2 py-0.5 text-[10px] font-rounded font-semibold text-attention">To confirm</span>}
                {a.prepReady && <span className="text-[10px] font-rounded text-warm flex items-center gap-0.5"><Icon name="sparkles" size={10} />Prep ready</span>}
              </div>
            </div>
            <Icon name="chevronRight" size={16} className="text-ink-muted" />
          </OrganicCard>
        </Press>
      ))}
    </div>
  );
};

const AppointmentDetail: React.FC<{ id: string; push: (n: string, p?: Record<string, unknown>) => void }> = ({ id, push }) => {
  const s = useSano();
  const a = s.appointments.find((x) => x.id === id);
  const [check, setCheck] = useState<Set<number>>(new Set());
  if (!a) return null;
  return (
    <div className="space-y-4">
      <OrganicCard className="p-5">
        <div className="flex gap-2"><span className="rounded-full px-2.5 py-1 text-[11px] font-rounded font-semibold glass text-sky">{a.kind === "telehealth" ? "Video visit" : "In person"}</span><span className={`rounded-full px-2.5 py-1 text-[11px] font-rounded font-semibold ${a.status === "confirmed" ? "text-life" : "text-attention"}`}>{a.status}</span></div>
        <h1 className="font-serif text-[24px] text-ink mt-3">{a.with}</h1>
        <p className="font-rounded text-[13px] text-ink-muted mt-1 flex items-center gap-1.5"><Icon name="calendar" size={13} />{new Date(a.date).toLocaleDateString([], { weekday: "long", month: "long", day: "numeric" })} · {fmtTime(a.date)}</p>
        <p className="font-rounded text-[13px] text-ink-muted mt-1 flex items-center gap-1.5"><Icon name="mapPin" size={13} />{a.location}</p>
        <ProvenanceChip text={`From ${s.persona.officeName}'s portal · changes happen there`} className="mt-3" />
      </OrganicCard>
      {a.kind === 'inPerson' && <SampleRideCard appointmentId={a.id} />}
      {a.planGoalHint && <OrganicCard className="p-4"><Kicker className="text-life">What this visit moves</Kicker><p className="font-rounded text-[14px] text-ink mt-1">{a.planGoalHint}</p></OrganicCard>}
      <div className="space-y-2">
        {a.kind === "telehealth" && <Press onClick={() => a.joinLink && window.open(a.joinLink, "_blank")} className="w-full rounded-full py-3 font-rounded font-semibold text-[14px]" style={{ background: s.canJoin(a) ? "rgb(var(--ink))" : "rgb(var(--ink-muted) / 0.25)", color: s.canJoin(a) ? "rgb(var(--base))" : "rgb(var(--ink) / 0.6)" }}>{s.canJoin(a) ? "Join the video visit" : "Join opens 15 min before"}</Press>}
        {a.status === "pending" && <Press onClick={() => s.setShowAgentNetwork(true)} className="w-full rounded-full py-3 font-rounded font-semibold text-[14px]" style={{ background: "rgb(var(--ink))", color: "rgb(var(--base))" }}>Confirm in my portal with Rumi Works</Press>}
        {a.prepReady && <Press onClick={() => push("visitPrep")} className="w-full rounded-full py-3 font-rounded font-semibold text-[14px] glass text-ink">See your visit prep</Press>}
      </div>
      {a.trip && (
        <OrganicCard className="p-4">
          <Kicker className="text-gold">{a.trip.isVirtual ? "Get ready to connect" : "Plan your trip"}</Kicker>
          {!a.trip.isVirtual && <div className="mt-2"><p className="font-rounded text-[12px] text-ink-muted">Leave by</p><p className="font-serif text-[26px] text-ink">{fmtTime(a.trip.departBy)}</p><p className="font-rounded text-[12px] text-ink-muted">{a.trip.routeHint}</p></div>}
          {a.trip.calendarConflict && <p className="mt-2 rounded-xl p-2.5 text-[12px] font-rounded text-attention" style={{ background: "rgb(var(--attention) / 0.12)" }}>{a.trip.calendarConflict}</p>}
          <div className="mt-3 space-y-1.5">
            {a.trip.checklist.map((c, i) => (
              <button key={i} onClick={() => setCheck((s) => { const n = new Set(s); n.has(i) ? n.delete(i) : n.add(i); return n; })} className="press flex items-center gap-2.5 w-full text-left">
                <span className={`size-5 rounded-full grid place-items-center shrink-0 ${check.has(i) ? "bg-life" : "glass"}`}>{check.has(i) && <Icon name="check" size={11} className="text-base" />}</span>
                <span className={`font-rounded text-[13px] ${check.has(i) ? "line-through text-ink-muted" : "text-ink"}`}>{c}</span>
              </button>
            ))}
          </div>
          {a.trip.rideHint && <p className="font-rounded text-[12px] text-ink-muted mt-3">{a.trip.rideHint}</p>}
        </OrganicCard>
      )}
    </div>
  );
};

// ---------- Visit reports (per doctor) ----------
const Reports: React.FC = () => {
  const s = useSano();
  const [range, setRange] = useState(30);
  const [open, setOpen] = useState<DoctorReport | null>(null);
  const reports = s.reports(range);
  return (
    <div className="space-y-4">
      <div><h1 className="font-serif text-[28px] text-ink">Visit reports</h1><p className="font-rounded text-[13px] text-ink-muted mt-1">A clear summary for each doctor — tailored to them, shared across the team.</p></div>
      <div className="flex items-center gap-2">
        <span className="font-rounded text-[12.5px] text-ink-muted">Window</span>
        {[30, 60, 90].map((d) => <Press key={d} onClick={() => setRange(d)} className={`rounded-full px-3 py-1.5 text-[12.5px] font-rounded font-medium ${range === d ? "text-base" : "text-ink glass"}`} style={range === d ? { background: "rgb(var(--ink))" } : undefined}>{d} days</Press>)}
      </div>
      {reports.map((r) => (
        <Press key={r.id} onClick={() => setOpen(r)} className="w-full text-left">
          <OrganicCard className="p-4">
            <div className="flex items-center gap-3">
              <div className="size-10 rounded-full grid place-items-center shrink-0" style={{ background: "rgb(var(--sky) / 0.16)" }}><Icon name="stethoscope" size={17} className="text-sky" /></div>
              <div className="flex-1 min-w-0"><p className="font-serif text-[16px] text-ink leading-tight">{r.doctorName}</p><p className="font-rounded text-[12px] text-ink-muted">{r.doctorRole}</p></div>
            </div>
            <p className="font-rounded text-[13px] text-ink/85 mt-2">Leads with {r.focusLine}.</p>
            <div className="flex items-center justify-between mt-2"><p className="font-rounded text-[11px] text-ink-muted">{r.preparedLine}</p><span className="font-rounded text-[12.5px] text-warm font-semibold flex items-center gap-1">Review<Icon name="chevronRight" size={12} /></span></div>
          </OrganicCard>
        </Press>
      ))}
      <Sheet open={open != null} onClose={() => setOpen(null)}>{open && <ReportDoc report={open} />}</Sheet>
      <ProvenanceChip text="Drafted from your history · shared only through your portal, with your okay" className="px-1" />
    </div>
  );
};

const reportAccent: Record<ReportKind, string> = { headline: "ink", numbers: "sky", meds: "warm", logging: "life", crossRef: "gold", questions: "rose" };
const ReportDoc: React.FC<{ report: DoctorReport }> = ({ report }) => {
  const s = useSano();
  const summary = `${report.title} for ${report.doctorName} (${report.preparedLine}).\n${report.sections.map((sec) => `${sec.title}: ${sec.lines.map((l) => l.primary).join('; ')}`).join('\n')}`;
  return (
    <div className="px-4 pt-1 pb-8">
      <div className="organic rounded-3xl p-5">
        <p className="kicker text-warm">{report.title}</p>
        <h2 className="font-display text-[24px] text-ink mt-1">For {report.doctorName}</h2>
        <p className="font-rounded text-[12.5px] text-ink-muted">{report.doctorRole} · {report.org}</p>
        <p className="font-rounded text-[11.5px] text-ink-muted">{report.preparedLine}</p>
        <div className="h-px my-4" style={{ background: "rgb(var(--edge))" }} />
        <div className="space-y-5">
          {report.sections.map((sec) => (
            <div key={sec.id}>
              <h3 className="font-serif text-[16px] text-ink mb-2">{sec.title}</h3>
              <div className="space-y-2">
                {sec.lines.map((ln, i) => sec.kind === "headline" ? (
                  <div key={i}><p className="font-rounded text-[14px] text-ink font-semibold">{ln.primary}</p>{ln.secondary && <p className="font-rounded text-[12.5px] text-ink-muted mt-0.5">{ln.secondary}</p>}</div>
                ) : (
                  <div key={i} className="flex gap-2.5 items-start"><span className="size-1.5 rounded-full mt-1.5 shrink-0" style={{ background: `rgb(var(--${reportAccent[sec.kind]}))` }} /><div><p className="font-rounded text-[13px] text-ink font-medium">{ln.primary}</p>{ln.secondary && <p className="font-rounded text-[11.5px] text-ink-muted">{ln.secondary}</p>}</div></div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
      <div className="mt-4">
        <Press onClick={() => s.shareThroughPortal(summary)} className="w-full rounded-full py-3.5 font-rounded font-semibold text-[14px] flex items-center justify-center gap-2" style={{ background: "rgb(var(--ink))", color: "rgb(var(--base))" }}><Icon name="sparkles" size={15} />Send through my portal with Rumi Works</Press>
        <p className="text-center font-rounded text-[11px] text-ink-muted mt-2">Rumi Works drafts the portal message. You review the exact text before it sends.</p>
      </div>
    </div>
  );
};

// ---------- Connections + agent family ----------
const Connections: React.FC = () => {
  const s = useSano();
  const [showsRecords, setShowsRecords] = useState<boolean>(false);
  const google = s.connections.filter((c) => c.group === "google");
  const channels = s.connections.filter((c) => c.group === "channel");
  return (
    <div className="space-y-5">
      <div><h1 className="font-serif text-[28px] text-ink">Connections</h1><p className="font-rounded text-[13px] text-ink-muted mt-1">Bring your world in — Rumi gets smarter and meets you where you already are.</p></div>
      <button onClick={() => setShowsRecords((v) => !v)} className="w-full text-left rounded-3xl bg-[rgb(var(--surface))] p-4"><p className="font-rounded text-[15px] font-semibold text-ink">Healthcare records</p><p className="font-rounded text-[12px] text-ink-muted mt-1">Not connected · sample records in this preview</p></button>
      {showsRecords && <p role="status" className="font-rounded text-[13px] text-ink-muted">Secure provider authorization hasn’t been configured yet. No records have been imported. You can continue exploring sample records.</p>}
      <ConnGroup title="Google" subtitle="Context and sending, with your permission" items={google} />
      <ConnGroup title="Your channels" subtitle="Where Rumi can reach you, and you can reply" items={channels} />
      <div>
        <div className="flex items-start justify-between gap-2">
          <div>
            <h2 className="font-serif text-[18px] text-ink">Your Rumi network</h2>
            <p className="font-rounded text-[12.5px] text-ink-muted">A family of specialized agents. Tap any one to see what it's doing.</p>
          </div>
          <Press onClick={() => s.openAgentNetwork()} className="shrink-0 flex items-center gap-1 text-[12px] font-rounded font-semibold text-sky">See all<Icon name="arrowUpRight" size={11} /></Press>
        </div>
        <div className="grid grid-cols-2 gap-2.5 mt-3">{s.agentServices.map((a) => {
          const waiting = s.waitingCount(a.id);
          const active = s.activeTaskCount(a.id);
          const status = !a.active ? "Paused" : waiting > 0 ? `${waiting} waiting · ${active} in motion` : active > 0 ? `${active} in motion` : a.role;
          return (
          <Press key={a.id} onClick={() => s.openAgentNetwork(a.id)} className="text-left"><OrganicCard className={`p-3 h-full min-h-[112px] ${a.active ? "" : "opacity-60"}`}>
            <div className="flex items-center justify-between"><div className="size-9 rounded-full grid place-items-center" style={{ background: `rgb(var(--${a.accent}) / 0.16)` }}><Icon name={a.glyph} size={15} className={accentText[a.accent]} /></div>{waiting > 0 ? <span className="min-w-4 h-4 px-1 rounded-full grid place-items-center text-[10px] font-rounded font-bold text-base" style={{ background: "rgb(var(--warm))" }}>{waiting}</span> : <span className="size-2 rounded-full" style={{ background: a.active ? "rgb(var(--life))" : "rgb(var(--ink-muted) / 0.4)" }} />}</div>
            <p className="font-serif text-[14px] text-ink mt-2">{a.name}</p><p className={`font-rounded text-[11px] mt-0.5 leading-snug ${waiting > 0 ? "text-warm" : "text-ink-muted"}`}>{status}</p>
          </OrganicCard></Press>
          );
        })}</div>
      </div>
      <ProvenanceChip text="Connect or disconnect any time — Rumi only uses what you allow" className="px-1" />
    </div>
  );
};
const ConnGroup: React.FC<{ title: string; subtitle: string; items: ReturnType<typeof useSano>["connections"] }> = ({ title, subtitle, items }) => {
  const s = useSano();
  return (
    <div>
      <h2 className="font-serif text-[18px] text-ink">{title}</h2>
      <p className="font-rounded text-[12.5px] text-ink-muted">{subtitle}</p>
      <div className="space-y-2.5 mt-3">
        {items.map((c) => (
          <OrganicCard key={c.id} className="p-3.5">
            <div className="flex items-center gap-3">
              <div className="size-10 rounded-full grid place-items-center shrink-0" style={{ background: `rgb(var(--${c.accent}) / 0.16)` }}><Icon name={c.glyph} size={16} className={accentText[c.accent]} /></div>
              <div className="flex-1 min-w-0"><p className="font-serif text-[15px] text-ink leading-tight">{c.name}</p><p className={`font-rounded text-[12px] truncate ${c.connected ? "text-life" : "text-ink-muted"}`}>{c.connected ? (c.accountLine ?? "Connected") : c.detail}</p></div>
              <Press onClick={() => s.toggleConnection(c.id)} className={`rounded-full px-3.5 py-2 text-[12.5px] font-rounded font-semibold ${c.connected ? "text-life glass" : "text-base"}`} style={c.connected ? undefined : { background: "rgb(var(--ink))" }}>{c.connected ? "Connected" : "Connect"}</Press>
            </div>
            {c.connected && <p className="font-rounded text-[12px] text-ink-muted mt-2.5">{c.enables}</p>}
          </OrganicCard>
        ))}
      </div>
    </div>
  );
};

