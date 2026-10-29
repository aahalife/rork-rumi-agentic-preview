import React, { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useRef, useState } from "react";
import type {
  Pathway, Persona, Moment, Insight, Medication, Journey, Program, SymptomLog, CurrentsPiece,
  LabSeries, StoryEvent, CareTeamMember, Appointment, GuideItem, RecordItem, RecordSource,
  ConsentEntry, MemoryItem, CareEntry, AgentAction, MemoryGlimpse, UserProfile, ConversationTurn, EntryKind,
  CarePlanGoal, SupportPlan, LookingAheadNudge, RichElement, InsightStatus,
} from "./types";
import { personaFor, programs as seedPrograms, seedEntries, seedActions, seedMemories } from "./fixtures";
import { careBundleFor, supportPlan } from "./careBundles";
import { connectionsSeed, agentServicesSeed, agentTasksFor, buildReports, sampleAccount, type Connection, type AgentService, type DoctorReport, type AgentTask } from "./agentNetwork";
import { LifeLibrary, uid, capFirst } from "./lifeLibrary";
import { SoundEngine, Haptics } from "./sound";
import { streamChat, parseTags, makeHoldbackFilter, newTurn, type ChatMessage } from "./ai";
import type { Scheme } from "./theme";
import { browserDemoReducer, initialBrowserDemo, canStopDemo, type BrowserDemoState, type BrowserDemoEvent } from './browserDemo';
import { savedRecipes, defaultMealPreferences, recipeInsight, type ImportedRecipe, type MealPlanItem, type MealPreferences, type SampleRide, type ActivityPlanItem } from './recipeCollection';
import { demoPatientRecords, demoPatientSources, demoPatientMemory } from './demoPatient';
import { validatedClaims, usableMemory } from './aiMemory';
import { loadProfileMemory, saveProfileMemory, clearProfileMemory, restorableTurns } from './device';
import { isQuietHour, shouldSuppressCoaching, validateObservation, type SupportObservation } from './aiSupport';
export interface LiveSupport extends SupportObservation { id: string; kind: 'nudge' | 'insight'; at: number; evidence: { id: string; text: string }[] }

export type Tab = "today" | "care" | "you" | "journeys" | "currents";
export interface NeedsYou { id: string; kind: "result" | "appointment"; title: string; detail: string; destination: CareDest }
export type CareDest =
  | { t: "appointments" } | { t: "appointmentDetail"; id: string } | { t: "carePlan" } | { t: "medications" }
  | { t: "records" } | { t: "visitPrep" } | { t: "reports" } | { t: "connections" };

const PERSIST_KEY = "sano.web.v1";

interface SanoStore {
  aiConsent: boolean; setAIConsent: (enabled: boolean) => void;
  memoryConsent: boolean; setMemoryConsent: (enabled: boolean) => void;
  stopAI: () => void;
  confirmMemory: (id: string) => void; editMemory: (id: string, text: string) => void;
  liveSupport: LiveSupport[]; supportStatus: string; refreshSupport: (kind: 'nudge' | 'insight') => Promise<void>; dismissSupport: (id: string) => void;
  importedRecipes: ImportedRecipe[]; mealPlan: MealPlanItem[]; activityPlan: ActivityPlanItem[]; sampleRides: SampleRide[];
  mealPreferences: MealPreferences; setMealPreferences: (p: MealPreferences) => void;
  watchedRideId: string | null; setWatchedRideId: (id: string | null) => void;
  simulateRideUpdate: (id: string, update: 'late' | 'moved' | 'cancel') => void;
  browserDemo: BrowserDemoState;
  dispatchBrowserDemo: React.Dispatch<BrowserDemoEvent>;
  // shell
  tab: Tab; setTab: (t: Tab) => void;
  hasOnboarded: boolean;
  showConversation: boolean; openConversation: (seed?: string) => void; closeConversation: () => void;
  showQuickLog: boolean; setShowQuickLog: (b: boolean) => void; quickLogMedID: string | null; setQuickLogMedID: (s: string | null) => void;
  showSettings: boolean; setShowSettings: (b: boolean) => void;
  showRecap: boolean; setShowRecap: (b: boolean) => void;
  pendingCareDest: CareDest | null; setPendingCareDest: (d: CareDest | null) => void;
  // person
  pathway: Pathway; persona: Persona; profile: UserProfile; setProfile: (p: UserProfile) => void;
  displayFirstName: string;
  // stores
  moments: Moment[]; insights: Insight[]; medications: Medication[]; journeys: Journey[];
  programs: Program[]; logs: SymptomLog[]; currents: CurrentsPiece[]; labSeries: LabSeries[];
  storyEvents: StoryEvent[]; careTeam: CareTeamMember[]; appointments: Appointment[]; guideItems: GuideItem[];
  recordItems: RecordItem[]; sources: RecordSource[]; consents: ConsentEntry[]; memory: MemoryItem[];
  entries: CareEntry[]; agentActions: AgentAction[];
  memories: MemoryGlimpse[]; resultToAck: { title: string; detail: string; series?: string | null } | null;
  resultAcknowledged: boolean; lookingAhead: LookingAheadNudge | null; showsLookingAhead: boolean;
  derivedJourneyGoals: Set<string>;
  // prefs
  tonePreference: string; setTonePreference: (s: string) => void;
  appearance: string; setAppearance: (s: string) => void; scheme: Scheme;
  musicOn: boolean; setMusicOn: (b: boolean) => void;
  soundOn: boolean; setSoundOn: (b: boolean) => void;
  epsilonConsent: boolean; setEpsilonConsent: (b: boolean) => void;
  eraWarmth: string; setEraWarmth: (s: string) => void;
  notificationClasses: Record<string, boolean>; toggleNotification: (k: string) => void;
  quietStart: number; quietEnd: number; setQuiet: (s: number, e: number) => void;
  // orb
  orbState: OrbMode; justBloomed: boolean;
  quickLogAck: string | null; setQuickLogAck: (s: string | null) => void;
  // companion
  turns: ConversationTurn[]; isThinking: boolean; sendMessage: (text: string) => void; sendVoiceMessage: (text: string) => Promise<string>; resolveRich: (id: string) => void;
  // derived
  pendingActions: AgentAction[]; needsYou: NeedsYou[]; careUnreadCount: number;
  // agent network
  connections: Connection[]; agentServices: AgentService[];
  agentTasks: AgentTask[];
  agentTasksWaiting: AgentTask[]; agentTasksInMotion: AgentTask[];
  tasksForAgent: (id: string) => AgentTask[];
  activeTaskCount: (id: string) => number; waitingCount: (id: string) => number;
  approveAgentTask: (id: string) => void; declineAgentTask: (id: string) => void;
  showAgentNetwork: boolean; setShowAgentNetwork: (b: boolean) => void;
  agentNetworkFocus: string | null; openAgentNetwork: (focus?: string | null) => void;
  reports: (rangeDays: number) => DoctorReport[];
  /** Hands a report or draft to Rumi Works, which delivers it through the patient's own portal after approval. */
  shareThroughPortal: (detail: string) => void;
  toggleConnection: (id: string) => void;
  toggleAgentService: (id: string) => void;
  series: (id: string) => LabSeries | undefined;
  logsNear: (medID: string) => SymptomLog[];
  hasDerivedJourney: (title: string) => boolean;
  // actions
  completeOnboarding: (vals: { firstName: string; lastName: string; birthDate: number | null; pathway: Pathway; connectedSystems: string[]; healthConnected: boolean; values: string; barrier: string; tone: string }) => void;
  switchPathway: (p: Pathway) => void;
  resetDemoPatient: () => void;
  prioritizeGuideItem: (id: string) => void;
  dismissMoment: (id: string) => void;
  keepHabit: (jid: string, hid: string) => void; keptToday: (jid: string, hid: string) => boolean;
  addEntry: (kind: EntryKind, text: string, note?: string, linkedMedID?: string) => void;
  removeEntry: (id: string) => void;
  approveAction: (id: string) => void; declineAction: (id: string) => void;
  addMemoryGlimpse: (img: string, caption: string) => void; deleteMemoryGlimpse: (id: string) => void;
  addLog: (kind: string, severity: number, note: string | null, bodyRegion?: string | null, linkedMedID?: string | null) => SupportPlan;
  addGuideItem: (kind: GuideItem["kind"], text: string, from: string) => void;
  toggleGuideResolved: (id: string) => void; removeGuideItem: (id: string) => void;
  markInsightSeen: (id: string) => void; toggleInsightSaved: (id: string) => void;
  enroll: (id: string) => void; decline: (id: string) => void;
  toggleCurrentSaved: (id: string) => void; setTaste: (id: string, v: number) => void;
  deleteMemoryNote: (id: string) => void; addMemoryNote: (text: string, from: string) => void;
  acknowledgeResult: () => void;
  /** Appointments are read-only portal context; this applies an update observed in the portal. */
  applyPortalAppointmentUpdate: (id: string, to: number) => void;
  canJoin: (a: Appointment) => boolean;
  deriveJourney: (goal: CarePlanGoal) => void;
  wipe: () => void;
}

export type OrbMode = "ambient" | "listening" | "thinking" | "speaking" | "celebrating";

const Ctx = createContext<SanoStore | null>(null);
export const useSano = (): SanoStore => {
  const v = useContext(Ctx);
  if (!v) throw new Error("useSano must be used within SanoProvider");
  return v;
};

function loadPersisted(): Record<string, unknown> | null {
  try { const raw = localStorage.getItem(PERSIST_KEY); return raw ? JSON.parse(raw) : null; } catch { return null; }
}
function savePersisted(data: Record<string, unknown>) {
  try { localStorage.setItem(PERSIST_KEY, JSON.stringify(data)); } catch { /* ignore */ }
}

export const SanoProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [browserDemo, dispatchBrowserDemo] = useReducer(browserDemoReducer, initialBrowserDemo);
  const persisted = useMemo(loadPersisted, []);
  const [liveSupport, setLiveSupport] = useState<LiveSupport[]>((persisted?.liveSupport as LiveSupport[]) ?? []);
  const [supportEvents, setSupportEvents] = useState<number[]>((persisted?.supportEvents as number[]) ?? []);
  const [supportDismissals, setSupportDismissals] = useState<{ title: string; at: number }[]>((persisted?.supportDismissals as { title: string; at: number }[]) ?? []);
  const [supportStatus, setSupportStatus] = useState<string>('Live support is optional.');
  const supportAbortRef = useRef<AbortController | null>(null);
  // On by default; an explicit "off" choice is remembered on this device.
  const [aiConsent, setAIConsentState] = useState<boolean>(persisted?.aiConsent !== false);
  const [memoryConsent, setMemoryConsentState] = useState<boolean>(persisted?.memoryConsent !== false);
  const aiOptionsRef = useRef({ consent: aiConsent });
  aiOptionsRef.current = { consent: aiConsent };
  const memoryConsentRef = useRef(memoryConsent); memoryConsentRef.current = memoryConsent;
  const [importedRecipes, setImportedRecipes] = useState<ImportedRecipe[]>((persisted?.importedRecipes as ImportedRecipe[]) ?? []);
  const [mealPlan, setMealPlan] = useState<MealPlanItem[]>((persisted?.mealPlan as MealPlanItem[]) ?? []);
  const [activityPlan, setActivityPlan] = useState<ActivityPlanItem[]>((persisted?.activityPlan as ActivityPlanItem[]) ?? []);
  const [sampleRides, setSampleRides] = useState<SampleRide[]>((persisted?.sampleRides as SampleRide[]) ?? []);
  const [mealPreferences, setMealPreferences] = useState<MealPreferences>((persisted?.mealPreferences as MealPreferences) ?? defaultMealPreferences);
  const [watchedRideId, setWatchedRideId] = useState<string | null>(null);
  const appliedRun = useRef<number>(-1);
  // The runner belongs to the root provider, not the browser sheet; minimizing never stops it.
  useEffect(() => {
    if (browserDemo.phase !== 'login' && browserDemo.phase !== 'browsing') return;
    const timer = window.setTimeout(() => dispatchBrowserDemo({ type: browserDemo.phase === 'login' ? 'login' : 'advance' }), browserDemo.phase === 'login' ? 1800 : 2400);
    return () => window.clearTimeout(timer);
  }, [browserDemo.phase, browserDemo.step, browserDemo.run]);
  const initialPathway = ((persisted?.pathway as Pathway) ?? "metabolic");
  const persona = useMemo(() => personaFor(initialPathway), [initialPathway]);
  // Memory and chat belong to this device + this sample profile, so visitors sharing a demo profile never mix.
  const savedProfile = useMemo(() => loadProfileMemory(initialPathway), [initialPathway]);

  const [hasOnboarded, setHasOnboarded] = useState<boolean>(Boolean(persisted?.hasOnboarded));
  const [pathway, setPathway] = useState<Pathway>(initialPathway);
  const [activePersona, setActivePersona] = useState<Persona>(persona);
  const [tab, setTab] = useState<Tab>("today");
  const [showConversation, setShowConversation] = useState(false);
  const [showQuickLog, setShowQuickLog] = useState(false);
  const [quickLogMedID, setQuickLogMedID] = useState<string | null>(null);
  const [showSettings, setShowSettings] = useState(false);
  const [showRecap, setShowRecap] = useState(false);
  const [pendingCareDest, setPendingCareDest] = useState<CareDest | null>(null);
  const [justBloomed, setJustBloomed] = useState(Boolean(persisted?.justBloomed));

  const [profile, setProfileState] = useState<UserProfile>(
    (persisted?.profile as UserProfile) ?? { firstName: "", lastName: "", birthDate: null, healthConnected: false, connectedSystems: [] },
  );

  const careBundle = useMemo(() => careBundleFor(pathway), [pathway]);

  const [moments, setMoments] = useState<Moment[]>(activePersona.moments);
  const [insights, setInsights] = useState<Insight[]>(activePersona.insights);
  const [medications, setMedications] = useState<Medication[]>(activePersona.medications);
  const [journeys, setJourneys] = useState<Journey[]>(activePersona.journeys);
  const [programs, setPrograms] = useState<Program[]>(seedPrograms.map((p) => ({ ...p })));
  const [logs, setLogs] = useState<SymptomLog[]>((persisted?.logs as SymptomLog[]) ?? []);
  const [currents, setCurrents] = useState<CurrentsPiece[]>(activePersona.currents);
  const [labSeries, setLabSeries] = useState<LabSeries[]>(activePersona.labSeries);
  const [storyEvents, setStoryEvents] = useState<StoryEvent[]>(activePersona.storyEvents);
  const [careTeam, setCareTeam] = useState<CareTeamMember[]>(activePersona.careTeam);
  const [appointments, setAppointments] = useState<Appointment[]>((persisted?.appointments as Appointment[]) ?? careBundle.appointments);
  const [guideItems, setGuideItems] = useState<GuideItem[]>((persisted?.guideItems as GuideItem[]) ?? activePersona.guideSeed);
  const recordItems = useMemo(() => demoPatientRecords(activePersona), [activePersona]);
  const sources = useMemo(() => demoPatientSources(activePersona), [activePersona]);
  const [consents, setConsents] = useState<ConsentEntry[]>([]);
  const [memory, setMemory] = useState<MemoryItem[]>(savedProfile?.memory ?? (persisted?.memory as MemoryItem[]) ?? demoPatientMemory(activePersona));
  const [entries, setEntries] = useState<CareEntry[]>((persisted?.entries as CareEntry[]) ?? seedEntries(activePersona));
  const [agentActions, setAgentActions] = useState<AgentAction[]>(seedActions(pathway));
  const [memories, setMemories] = useState<MemoryGlimpse[]>((persisted?.memories as MemoryGlimpse[]) ?? seedMemories(pathway));
  const [resultAcknowledged, setResultAcknowledged] = useState(false);
  const [derivedJourneyGoals, setDerivedJourneyGoals] = useState<Set<string>>(new Set());
  const [connections, setConnections] = useState<Connection[]>(connectionsSeed());
  const [agentServices, setAgentServices] = useState<AgentService[]>(agentServicesSeed());
  const [agentTasks, setAgentTasks] = useState<AgentTask[]>(agentTasksFor(initialPathway));
  const [showAgentNetwork, setShowAgentNetwork] = useState(false);
  const [agentNetworkFocus, setAgentNetworkFocus] = useState<string | null>(null);

  // preferences
  const [tonePreference, setTonePreference] = useState<string>((persisted?.tone as string) ?? "Straight talk");
  const [appearance, setAppearanceState] = useState<string>((persisted?.appearance as string) ?? "Auto");
  const [musicOn, setMusicOnState] = useState<boolean>(persisted?.musicOn !== false);
  const [soundOn, setSoundOnState] = useState<boolean>(persisted?.soundOn !== false);
  const [epsilonConsent, setEpsilonConsent] = useState<boolean>(persisted?.epsilon === true);
  const [eraWarmth, setEraWarmth] = useState<string>((persisted?.eraWarmth as string) ?? "Subtle");
  const [notificationClasses, setNotificationClasses] = useState<Record<string, boolean>>(
    (persisted?.notifs as Record<string, boolean>) ?? { "Habit moments": true, Insights: true, "Heads-ups": true, Logistics: true, "Check-ins": true },
  );
  const [quietStart, setQuietStart] = useState(21);
  const [quietEnd, setQuietEnd] = useState(8);

  const [orbState, setOrbState] = useState<OrbMode>("ambient");
  const [quickLogAck, setQuickLogAck] = useState<string | null>(null);

  // companion
  const [turns, setTurns] = useState<ConversationTurn[]>(() => memoryConsent ? restorableTurns(savedProfile?.turns ?? []) : []);
  const [isThinking, setIsThinking] = useState(false);
  const abortRef = useRef<AbortController | null>(null);
  const hasGreetedRef = useRef(turns.length > 0);

  // ---- effective scheme ----
  const [systemDark, setSystemDark] = useState(() => window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? false);
  useEffect(() => {
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const fn = (e: MediaQueryListEvent) => setSystemDark(e.matches);
    mq.addEventListener("change", fn);
    return () => mq.removeEventListener("change", fn);
  }, []);
  const scheme: Scheme = appearance === "Day" ? "day" : appearance === "Night" ? "night" : systemDark ? "night" : "day";
  useEffect(() => {
    const root = document.documentElement;
    root.classList.toggle("night", scheme === "night");
    root.classList.toggle("dark", scheme === "night");
    root.classList.toggle("day", scheme === "day");
  }, [scheme]);

  // ---- persistence ----
  const persist = useCallback(() => {
    savePersisted({
      aiConsent, memoryConsent, liveSupport, supportEvents, supportDismissals,
      hasOnboarded, pathway, profile, tone: tonePreference, appearance, musicOn, soundOn,
      epsilon: epsilonConsent, eraWarmth, notifs: notificationClasses, justBloomed,
      entries, logs, memories, guideItems,
      importedRecipes, mealPlan, activityPlan, sampleRides, mealPreferences, appointments,
    });
  }, [aiConsent, memoryConsent, liveSupport, supportEvents, supportDismissals, hasOnboarded, pathway, profile, tonePreference, appearance, musicOn, soundOn, epsilonConsent, eraWarmth, notificationClasses, justBloomed, entries, logs, memories, guideItems, importedRecipes, mealPlan, activityPlan, sampleRides, mealPreferences, appointments]);
  useEffect(() => { persist(); }, [persist]);
  useEffect(() => {
    if (turns.some(t => t.streaming)) return;
    saveProfileMemory(pathway, { memory, turns: memoryConsent ? restorableTurns(turns) : [] });
  }, [pathway, memory, turns, memoryConsent]);

  // ---- sound bindings ----
  useEffect(() => { SoundEngine.enabled = soundOn; }, [soundOn]);
  useEffect(() => { SoundEngine.setMusicEnabled(musicOn); }, [musicOn]);
  useEffect(() => {
    if (hasOnboarded) SoundEngine.playBed("ambient", 3.0);
    else { SoundEngine.currentBed = "onboarding"; }
  }, [hasOnboarded]);

  const setProfile = useCallback((p: UserProfile) => setProfileState(p), []);
  const setAppearance = useCallback((s: string) => setAppearanceState(s), []);
  const setMusicOn = useCallback((b: boolean) => setMusicOnState(b), []);
  const setSoundOn = useCallback((b: boolean) => setSoundOnState(b), []);
  const setQuiet = useCallback((s: number, e: number) => { setQuietStart(s); setQuietEnd(e); }, []);
  const toggleNotification = useCallback((k: string) => setNotificationClasses((m) => ({ ...m, [k]: !m[k] })), []);

  const reflectionAbortRef = useRef<AbortController | null>(null);
  const stopAI = useCallback(() => {
    supportAbortRef.current?.abort();
    reflectionAbortRef.current?.abort();
    abortRef.current?.abort();
    setTurns(old => old.map(t => ({ ...t, streaming: false })));
    setIsThinking(false); setOrbState('ambient');
  }, []);
  const setAIConsent = useCallback((enabled: boolean) => {
    aiOptionsRef.current.consent = enabled; stopAI(); setAIConsentState(enabled);
  }, [stopAI]);
  const setMemoryConsent = useCallback((enabled: boolean) => { stopAI(); setMemoryConsentState(enabled); }, [stopAI]);

  const displayFirstName = profile.firstName || activePersona.firstName;

  // keep a live ref of prompt-relevant state for the companion
  const promptRef = useRef({ activePersona, medications, labSeries, appointments, memory, logs, entries, guideItems, programs, agentActions, tonePreference, displayFirstName });
  promptRef.current = { activePersona, medications, labSeries, appointments, memory, logs, entries, guideItems, programs, agentActions, tonePreference, displayFirstName };

  const celebrate = useCallback(() => {
    setOrbState("celebrating");
    setTimeout(() => setOrbState("ambient"), 1600);
  }, []);

  // ---- pathway switch ----
  const applyPersona = useCallback((p: Pathway, fresh = false) => {
    supportAbortRef.current?.abort(); setLiveSupport([]); setSupportDismissals([]); setSupportEvents([]);
    reflectionAbortRef.current?.abort();
    abortRef.current?.abort(); setIsThinking(false); setOrbState('ambient');
    if (fresh) clearProfileMemory(p);
    const saved = fresh ? null : loadProfileMemory(p);
    const restored = memoryConsentRef.current ? restorableTurns(saved?.turns ?? []) : [];
    setTurns(restored); hasGreetedRef.current = restored.length > 0;
    dispatchBrowserDemo({ type: 'reset' });
    setImportedRecipes([]); setMealPlan([]); setActivityPlan([]); setSampleRides([]); setMealPreferences(defaultMealPreferences); setWatchedRideId(null);
    const per = personaFor(p);
    const cb = careBundleFor(p);
    setActivePersona(per);
    setMemory(saved?.memory ?? demoPatientMemory(per)); setConsents([]); setQuickLogAck(null);
    setMoments(per.moments); setInsights(per.insights); setMedications(per.medications);
    setJourneys(per.journeys); setCurrents(per.currents); setLabSeries(per.labSeries);
    setStoryEvents(per.storyEvents); setCareTeam(per.careTeam); setGuideItems(per.guideSeed);
    setAppointments(cb.appointments);
    setLogs([]); setEntries(seedEntries(per)); setAgentActions(seedActions(p)); setMemories(seedMemories(p));
    setDerivedJourneyGoals(new Set()); setResultAcknowledged(false);
    setConnections(connectionsSeed()); setAgentServices(agentServicesSeed()); setAgentTasks(agentTasksFor(p));
  }, []);

  const switchPathway = useCallback((p: Pathway) => {
    if (p === pathway) return;
    setPathway(p);
    applyPersona(p);
  }, [pathway, applyPersona]);

  // ---- companion ----
  const buildSystemPrompt = useCallback((): string => {
    const s = promptRef.current;
    const p = s.activePersona;
    const name = s.displayFirstName;
    const conditions = p.conditions.map((c) => `${c.name} (${c.state}) — ${c.plainLine}`).join("\n");
    const meds = s.medications.map((m) => `${m.name} ${m.dose} — ${m.purposeLine}; ${m.scheduleLine}`).join("\n");
    const labs = s.labSeries.map((ls) => {
      const latest = ls.points[ls.points.length - 1];
      return `${ls.name} [tag id: ${ls.id}]: latest ${latest.value} ${ls.unit}. ${ls.explainReading}`;
    }).join("\n");
    const appts = s.appointments.map((a) => `${a.with} — ${new Date(a.date).toLocaleDateString([], { month: "long", day: "numeric" })} at ${a.location}`).join("\n");
    const plan = p.carePlan.goals.map((g) => `${g.title}: ${g.detail}${g.progressLine ? ` (status: ${g.progressLine})` : ""}`).join("\n");
    const memories = memoryConsentRef.current ? usableMemory(s.memory).slice(0, 8).map((m) => `- ${m.text} (${m.learnedFrom})`).join("\n") : 'Memory disabled';
    const guide = s.guideItems.filter((g) => !g.resolved).map((g) => `- ${g.text}`).join("\n");
    const progLines = s.programs.filter((pr) => !pr.declined).map((pr) => `${pr.title}${pr.enrolled ? " [ENROLLED]" : ""}${pr.sponsor ? ` [sponsored by ${pr.sponsor} — disclose naturally if you bring it up]` : ""}: ${pr.summary}`).join("\n");
    const phaseLine = p.phase ? `${p.phase.kicker} — ${p.phase.headline}. ${p.phase.detail}` : "";
    return `Consented context for ${name}. Fictional sample patient ${p.firstName}; user disclosures are not sample history.

VOICE & SOUL
- Sound like a person. Contractions, rhythm, warmth. Never bullet lists unless asked.
- This release uses a synthetic demo patient, not imported patient history. External actions are simulations. Never claim you have sent, booked, paid, connected or retrieved from a real website. Offer a draft or a labeled demo task instead.
- Describe patterns as associations, not causes or medical conclusions. Invite correction and accept not now. Never recommend medication changes from lifestyle patterns.
- Default length: 2–4 sentences (~60 words). Depth only when invited.
- Zero sycophancy. Never open with praise, never say "Great question". Specific beats nice.
- Be honest that you are AI, not a nurse. Translate clinical jargon plainly.
- Hold hard feelings before fixing them. One beat of acknowledgment, then — only if useful — one small concrete next step.
- Tone preference: ${s.tonePreference}. Honor it.

CLINICAL SPINE (hard rules)
- You never diagnose, never adjust doses, never contradict the care team. You notice, prepare, connect.
- Only reference dated care instructions for this active sample patient. No medication safety assurances or generic stop dates.
- Anything that leaves the phone needs ${name}'s explicit approval.
- Rumi complements ${name}'s patient portal; it does not replace it. Care-team messages, refills, bills, payments and scheduling happen in the portal. When asked, offer to have Rumi Works do it there (with approval), or prepare a draft. Never claim Rumi itself sent, refilled, paid or booked anything.

BEHAVIORAL INTELLIGENCE
- Every reply quietly serves the goal and plan. Tie small actions to the person's own why. Make the next step tiny, scheduled, and theirs.
- Notice patterns across meds, logs, meals, movement and timing — as observations, never accusations.
- Do not offer sponsored programs or infer eligibility. Emotional support can be the whole response.

ACTION TAGS — embed at most ONE per reply, at the very end, never inside a sentence:
[[habit:Title|when-context]] · [[guide:Question]]
Use a tag only when it genuinely helps. Most replies need none.

WHO ${name.toUpperCase()} IS
Pathway: ${p.switcherLine}
${phaseLine}
Conditions:
${conditions}
Medications:
${meds}
Numbers (chartable):
${labs}
Care plan from ${p.carePlan.author}:
${plan}
Upcoming:
${appts}
Care team office: ${p.officeName}, ${p.officePhone}
Memory (sample notes explicitly labeled; never treat them as user statements):
${memories}
Recent symptom logs, voluntarily entered (dated evidence):
${JSON.stringify(s.logs.slice(-6))}
Recent life entries (sample seed entries and user-entered events, not planned behavior):
${JSON.stringify(s.entries.slice(0, 6))}
Open questions in their visit guide:
${guide || "none yet"}
Programs available:
${progLines}

Today is ${new Date().toLocaleDateString([], { weekday: "long", month: "long", day: "numeric" })}. Meet them where the day actually is.`;
  }, []);

  const reflect = useCallback(async () => {
    if (!memoryConsentRef.current || !aiOptionsRef.current.consent) return;
    reflectionAbortRef.current?.abort();
    const ctrl = new AbortController(); reflectionAbortRef.current = ctrl;
    const evidence = promptRefTurns.current.filter(t => t.role === 'user').slice(-10);
    if (!evidence.length) return;
    try {
      const raw = await streamChat('Only extract user-stated preferences, barriers and motivators. Never use sample patient facts as user biography.', evidence.map(t => ({ role: 'user', content: t.text })), () => {}, ctrl.signal, { ...aiOptionsRef.current, purpose: 'reflection' });
      if (ctrl.signal.aborted || !memoryConsentRef.current || !aiOptionsRef.current.consent) return;
      const claims = validatedClaims(raw, evidence);
      setMemory(old => [...claims.filter(c => !old.some(m => m.quote === c.quote || m.text.toLowerCase() === c.text.toLowerCase())), ...old].slice(0, 60));
    } catch { /* Optional reflection failure never fabricates memory. */ }
  }, []);

  const applySideEffects = useCallback((rich: RichElement) => {
    if (rich.t === "guideAdd") {
      addGuideItemRef.current?.("Question", rich.question, `Drafted in conversation · ${new Date().toLocaleDateString([], { month: "short", day: "numeric" })}`);
    }
  }, []);

  const ask = useCallback(async (userVisible: string | null, prompt: string) => {
    abortRef.current?.abort();
    const ctrl = new AbortController();
    abortRef.current = ctrl;
    setIsThinking(true);
    setOrbState("thinking");

    const history: ChatMessage[] = promptRefTurns.current.slice(-14).map((t) => ({ role: t.role === "user" ? "user" : "assistant", content: t.text }));
    history.push({ role: "user", content: prompt });

    const filter = makeHoldbackFilter();
    let turnId: string | null = null;
    let shown = "";
    const ensureTurn = () => {
      if (turnId) return;
      const t = newTurn("companion", "", true);
      turnId = t.id;
      setIsThinking(false);
      setOrbState("speaking");
      setTurns((prev) => [...prev, t]);
    };

    try {
      const raw = await streamChat(buildSystemPrompt(), history, (delta) => {
        if (ctrl.signal.aborted) return;
        const visible = filter(delta);
        if (visible) {
          ensureTurn();
          shown += visible;
          const cur = shown.replace(/^\n+/, "");
          setTurns((prev) => prev.map((t) => (t.id === turnId ? { ...t, text: cur } : t)));
        }
      }, ctrl.signal, aiOptionsRef.current);
      if (ctrl.signal.aborted) return;
      ensureTurn();
      const parsed = parseTags(raw);
      setTurns((prev) => prev.map((t) => (t.id === turnId ? { ...t, text: parsed.text, streaming: false } : t)));
      if (parsed.rich.t !== "none") {
        await new Promise((r) => setTimeout(r, 220));
        if (ctrl.signal.aborted) return;
        setTurns((prev) => prev.map((t) => (t.id === turnId ? { ...t, rich: parsed.rich } : t)));
        applySideEffects(parsed.rich);
      }
      if (promptRefTurns.current.filter(t => t.role === 'user').length % 5 === 0) void reflect();
    } catch (error) {
      if (ctrl.signal.aborted) return;
      ensureTurn();
      const reply = error instanceof Error ? error.message : 'Live AI is unavailable. Please try again.';
      setTurns(prev => prev.map(t => t.id === turnId ? { ...t, text: `Live AI unavailable · ${reply}`, streaming: false, rich: { t: 'none' } } : t));
    } finally {
      if (abortRef.current === ctrl) { setIsThinking(false); setOrbState("ambient"); }
    }
  }, [buildSystemPrompt, applySideEffects, reflect]);

  const promptRefTurns = useRef<ConversationTurn[]>([]);
  promptRefTurns.current = turns;

  const openConversation = useCallback((seed?: string) => {
    setShowConversation(true);
    SoundEngine.playBed("ambient");
    setOrbState("ambient");
    if (seed) {
      let prompt: string;
      if (seed.startsWith("symptom:")) {
        const kind = seed.slice("symptom:".length);
        prompt = `I just logged ${kind} in the quick log. Open the conversation about it — sit with it first, then one useful question or step. If it belongs in front of my care team, draft a guide question with the [[guide:...]] tag.`;
      } else prompt = `I tapped into the conversation from: ${seed}. Pick this thread up naturally.`;
      ask(null, prompt);
    } else if (!hasGreetedRef.current) {
      hasGreetedRef.current = true;
      ask(null, "Open the conversation with a single short, warm greeting grounded in where I actually am today. No questions about how to help — just be present, then leave space.");
    }
  }, [ask]);

  const closeConversation = useCallback(() => {
    abortRef.current?.abort();
    setIsThinking(false);
    setOrbState("ambient");
    setShowConversation(false);
    void reflect();
  }, [reflect]);

  const sendMessage = useCallback((text: string) => {
    const trimmed = text.trim();
    if (!trimmed) return;
    const turn = newTurn('user', trimmed);
    setTurns(prev => [...prev, turn]);
    // React state may not have rendered yet; the request carries the latest message explicitly.
    ask(trimmed, trimmed);
  }, [ask]);

  const sendVoiceMessage = useCallback(async (text: string): Promise<string> => {
    const trimmed = text.trim();
    if (!trimmed) return "";
    abortRef.current?.abort();
    const ctrl = new AbortController(); abortRef.current = ctrl;
    setTurns((prev) => [...prev, newTurn("user", trimmed)]);
    setIsThinking(true);
    setOrbState("thinking");
    const history: ChatMessage[] = [...promptRefTurns.current, newTurn("user", trimmed)]
      .slice(-14)
      .map((t) => ({ role: t.role === "user" ? "user" : "assistant", content: t.text }));
    const voiceSystem = `${buildSystemPrompt()}\n\nVOICE MODE — you are speaking out loud right now. Keep it to 1–2 short, warm spoken sentences. No lists, no markdown, no tags unless absolutely necessary.`;
    try {
      const raw = await streamChat(voiceSystem, history, () => {}, ctrl.signal, { ...aiOptionsRef.current, purpose: 'voice' });
      if (ctrl.signal.aborted) return '';
      const parsed = parseTags(raw);
      const reply = parsed.text;
      setTurns((prev) => [...prev, { ...newTurn("companion", reply), rich: parsed.rich }]);
      if (parsed.rich.t !== "none") applySideEffects(parsed.rich);
      return reply;
    } catch (error) {
      if (ctrl.signal.aborted) return '';
      const reply = `Live AI unavailable · ${error instanceof Error ? error.message : 'Please try again.'}`;
      setTurns((prev) => [...prev, newTurn("companion", reply)]);
      return reply;
    } finally {
      if (abortRef.current === ctrl) { setIsThinking(false); setOrbState("ambient"); }
    }
  }, [buildSystemPrompt, applySideEffects]);

  const resolveRich = useCallback((id: string) => {
    setTurns((prev) => prev.map((t) => (t.id === id ? { ...t, richResolved: true } : t)));
  }, []);

  const refreshSupport = useCallback(async (kind: 'nudge' | 'insight') => {
    const now = Date.now();
    if (!aiOptionsRef.current.consent) { setSupportStatus('Rumi AI is turned off in Settings.'); return; }
    if (supportAbortRef.current && !supportAbortRef.current.signal.aborted) return;
    if (isQuietHour(new Date().getHours(), quietStart, quietEnd) || !notificationClasses[kind === 'nudge' ? 'Habit moments' : 'Insights']) { setSupportStatus('Resting during quiet hours or your category opt-out.'); return; }
    if (shouldSuppressCoaching(promptRefTurns.current.filter(t => t.role === 'user').slice(-3).map(t => t.text).join(' '))) { setSupportStatus('No coaching agenda right now. Conversation is here if you want it.'); return; }
    if (supportEvents.filter(at => now - at < 86400000).length >= 2 || supportEvents.filter(at => now - at < 7 * 86400000).length >= 8 || supportDismissals.some(d => now - d.at < 86400000)) { setSupportStatus('Giving you space. Two live checks/day, eight/week, and a day off after dismissal.'); return; }
    const current = promptRef.current;
    const evidence = [...current.logs.slice(-5).map(log => ({ id: log.id, text: JSON.stringify(log) })), ...current.entries.slice(0, 5).map(entry => ({ id: entry.id, text: `Local sample-app entry (may be fictional): ${JSON.stringify(entry)}` }))];
    if (!evidence.length) { setSupportStatus('Not enough dated context for an observation yet.'); return; }
    const ctrl = new AbortController(); supportAbortRef.current = ctrl;
    setSupportEvents(old => [...old.filter(at => now - at < 7 * 86400000), now]);
    setSupportStatus('Considering the context…');
    try {
      const raw = await streamChat(`${buildSystemPrompt()}\nEvidence IDs: ${JSON.stringify(evidence)}\nPreviously dismissed: ${JSON.stringify(supportDismissals)}`, [{ role: 'user', content: `Offer one optional ${kind} only if evidence supports it; otherwise skip.` }], () => {}, ctrl.signal, { ...aiOptionsRef.current, purpose: kind });
      if (ctrl.signal.aborted || !aiOptionsRef.current.consent) return;
      const result = validateObservation(raw, evidence.map(e => e.id));
      if (!result) { setSupportStatus('Nothing useful to add right now.'); return; }
      setLiveSupport(old => [{ ...result, kind, id: uid('live'), at: now, evidence: evidence.filter(e => result.evidenceIds.includes(e.id)) }, ...old.filter(item => item.title !== result.title && now - item.at < 86400000)].slice(0, 3));
      setSupportStatus('A live AI observation · not a clinical conclusion.');
    } catch { if (!ctrl.signal.aborted) setSupportStatus('Live support unavailable. Please try later; no sample content substituted.'); }
    finally { if (supportAbortRef.current === ctrl) supportAbortRef.current = null; }
  }, [buildSystemPrompt, notificationClasses, quietStart, quietEnd, supportEvents, supportDismissals]);
  const dismissSupport = useCallback((id: string) => { const item = liveSupport.find(s => s.id === id); if (!item) return; supportAbortRef.current?.abort(); setSupportDismissals(old => [...old, { title: item.title, at: Date.now() }].slice(-20)); setLiveSupport(old => old.filter(s => s.id !== id)); }, [liveSupport]);
  const lastSupportEvent = useRef(`${entries[0]?.id}:${logs[0]?.id}`);
  useEffect(() => {
    const key = `${entries[0]?.id}:${logs[0]?.id}`;
    if (key === lastSupportEvent.current) return;
    lastSupportEvent.current = key;
    if (aiConsent) void refreshSupport('nudge');
  }, [entries, logs, aiConsent, refreshSupport]);

  // ---- actions ----
  const dismissMoment = useCallback((id: string) => setMoments((m) => m.filter((x) => x.id !== id)), []);

  const keptToday = useCallback((jid: string, hid: string): boolean => {
    const j = journeys.find((x) => x.id === jid);
    const h = j?.habits.find((x) => x.id === hid);
    if (!h) return false;
    const today = new Date(); today.setHours(0, 0, 0, 0);
    return h.keptDates.some((dt) => { const d = new Date(dt); d.setHours(0, 0, 0, 0); return d.getTime() === today.getTime(); });
  }, [journeys]);

  const keepHabit = useCallback((jid: string, hid: string) => {
    setJourneys((prev) => prev.map((j) => j.id !== jid ? j : { ...j, habits: j.habits.map((h) => h.id !== hid ? h : { ...h, keptDates: [...h.keptDates, Date.now()] }) }));
    celebrate(); Haptics.bloom(); SoundEngine.bloom();
  }, [celebrate]);

  const addEntry = useCallback((kind: EntryKind, text: string, note?: string, linkedMedID?: string) => {
    let entry: CareEntry;
    if (kind === "Meals") { const imported = savedRecipes.find(r => r.title === text && importedRecipes.some(i => i.recipeId === r.id)); const m = imported ? { suggestedTitle: imported.title, imageName: imported.artwork } : LifeLibrary.matchMeal(text); entry = { id: uid("ce"), kind, title: capFirst(m.suggestedTitle), detail: mealSlot(Date.now()), at: Date.now(), imageName: m.imageName, note }; }
    else if (kind === "Moves") { const m = LifeLibrary.matchMove(text); entry = { id: uid("ce"), kind, title: capFirst(m.suggestedTitle), detail: "Felt good to be active", at: Date.now(), imageName: m.imageName, note }; }
    else { const med = medications.find((x) => x.id === linkedMedID) ?? medications[0]; entry = { id: uid("ce"), kind, title: med?.name ?? capFirst(text), detail: med?.dose ?? "Taken", at: Date.now(), imageName: LifeLibrary.medImage(med?.id ?? ""), note, linkedMedID: med?.id }; }
    setEntries((prev) => [entry, ...prev]);
    setQuickLogAck(kind === 'Moves' ? 'A little movement counts. Want to find a gentle next step?' : kind === 'Meals' ? 'A meal, not a score. Want to explore what felt good today?' : 'Saved to this demo. Want to talk about how you’re feeling?');
    Haptics.success(); SoundEngine.send();
  }, [medications, importedRecipes]);

  const removeEntry = useCallback((id: string) => setEntries((prev) => prev.filter((e) => e.id !== id)), []);

  const approveAction = useCallback((id: string) => {
    const action = agentActions.find((a) => a.id === id);
    if (!action) return;
    setAgentActions((prev) => prev.map((a) => a.id === id ? { ...a, state: "done" } : a));
    setStoryEvents((prev) => [{ id: uid("s"), kind: "companion", date: Date.now(), title: action.title, detail: `Demo only · ${action.outcomeLine} · No external action taken.` }, ...prev]);
    setQuickLogAck(`Demo only · ${action.outcomeLine} · Nothing sent or charged.`);
    celebrate(); Haptics.bloom(); SoundEngine.bloom();
    setTimeout(() => setQuickLogAck((cur) => (cur?.includes(action.outcomeLine) ? null : cur)), 5000);
  }, [agentActions, celebrate]);

  const declineAction = useCallback((id: string) => setAgentActions((prev) => prev.map((a) => a.id === id ? { ...a, state: "declined" } : a)), []);

  const addMemoryGlimpse = useCallback((image: string, caption: string) => {
    setMemories((prev) => [{ id: uid("mg"), imageName: image, caption, date: Date.now() }, ...prev]);
    celebrate(); Haptics.bloom(); SoundEngine.bloom();
  }, [celebrate]);
  const deleteMemoryGlimpse = useCallback((id: string) => setMemories((prev) => prev.filter((m) => m.id !== id)), []);

  const addGuideItemImpl = useCallback((kind: GuideItem["kind"], text: string, from: string) => {
    setGuideItems((prev) => prev.some((g) => g.text === text) ? prev : [{ id: uid("gd"), kind, text, addedFrom: from, resolved: false }, ...prev]);
    Haptics.success(); SoundEngine.tick();
  }, []);
  const addGuideItemRef = useRef(addGuideItemImpl);
  addGuideItemRef.current = addGuideItemImpl;

  const addLog = useCallback((kind: string, severity: number, note: string | null, bodyRegion?: string | null, linkedMedID?: string | null): SupportPlan => {
    setLogs((prev) => [...prev, { id: uid("sl"), kind, severity, at: Date.now(), note: note || null, bodyRegion, linkedMedID }]);
    return supportPlan(pathway, kind, severity);
  }, [pathway]);

  const toggleGuideResolved = useCallback((id: string) => setGuideItems((prev) => prev.map((g) => g.id === id ? { ...g, resolved: !g.resolved } : g)), []);
  const removeGuideItem = useCallback((id: string) => setGuideItems((prev) => prev.filter((g) => g.id !== id)), []);

  const markInsightSeen = useCallback((id: string) => setInsights((prev) => prev.map((i) => i.id === id && i.status.t === "fresh" ? { ...i, status: { t: "seen" } as InsightStatus } : i)), []);
  const toggleInsightSaved = useCallback((id: string) => setInsights((prev) => prev.map((i) => {
    if (i.id !== id) return i;
    if (i.status.t === "saved") return { ...i, status: { t: "seen" } };
    if (i.status.t === "acted") return i;
    return { ...i, status: { t: "saved" } };
  })), []);

  const enroll = useCallback((id: string) => {
    const program = programs.find((p) => p.id === id);
    if (!program) return;
    setPrograms((prev) => prev.map((p) => p.id === id ? { ...p, enrolled: true, declined: false } : p));
    setMoments((prev) => prev.length < 3 ? [...prev, { id: uid("m"), kind: "checkIn", title: "Your program starts now", body: `${program.title} — the first step is two minutes. I'll walk you in.`, actionLabel: "Start" }] : prev);
    setJourneys((prev) => [...prev, { id: uid("jny"), title: program.title, why: program.personalFit, habits: [{ id: uid("hab"), title: "Two minutes with the program", contextLine: "whenever today bends a little", keptDates: [] }], gardenSeed: 57 }]);
    setAgentActions((prev) => [{ id: uid("act"), title: `Set up ${program.title}`, detail: "I'll register you, sync the schedule, and keep the first week gentle.", outcomeLine: "You're set up — first step is on Today.", glyph: "sparkles", leavesDevice: true, state: "proposed" }, ...prev]);
    setMemory((prev) => [{ id: uid("mem"), text: `Enrolled in ${program.title} — weave it in gently.`, learnedFrom: `Programs · ${new Date().toLocaleDateString([], { month: "short", day: "numeric" })}` }, ...prev]);
    celebrate(); Haptics.bloom(); SoundEngine.bloom();
  }, [programs, celebrate]);

  const decline = useCallback((id: string) => setPrograms((prev) => prev.map((p) => p.id === id ? { ...p, declined: true } : p)), []);
  const toggleCurrentSaved = useCallback((id: string) => setCurrents((prev) => prev.map((c) => c.id === id ? { ...c, saved: !c.saved } : c)), []);
  const setTaste = useCallback((id: string, v: number) => setCurrents((prev) => prev.map((c) => c.id === id ? { ...c, taste: c.taste === v ? 0 : v } : c)), []);
  const deleteMemoryNote = useCallback((id: string) => { stopAI(); setLiveSupport([]); setTurns([]); promptRefTurns.current = []; setMemory(prev => prev.filter(m => m.id !== id)); }, [stopAI]);
  const confirmMemory = useCallback((id: string) => { stopAI(); setMemory(old => old.map(m => m.id === id ? { ...m, confirmed: true, confidence: 1, claimKind: 'fact', learnedFrom: 'Confirmed by you', at: Date.now() } : m)); }, [stopAI]);
  const editMemory = useCallback((id: string, text: string) => { if (!text.trim()) return; stopAI(); setLiveSupport([]); setTurns([]); promptRefTurns.current = []; setMemory(old => old.map(m => m.id === id ? { ...m, text: text.trim().slice(0, 300), quote: text.trim().slice(0, 300), confirmed: true, confidence: 1, claimKind: 'fact', learnedFrom: 'Corrected by you', at: Date.now() } : m)); }, [stopAI]);
  const addMemoryNote = useCallback((text: string, from: string) => { setMemory((prev) => [{ id: uid("mem"), text, learnedFrom: from }, ...prev]); Haptics.success(); SoundEngine.tick(); }, []);

  const acknowledgeResult = useCallback(() => { setResultAcknowledged(true); Haptics.tick(); }, []);

  const applyPortalAppointmentUpdate = useCallback((id: string, to: number) => { setAppointments((prev) => [...prev].map((a) => a.id === id ? { ...a, date: to } : a).sort((a, b) => a.date - b.date)); }, []);
  const canJoin = useCallback((a: Appointment): boolean => { if (a.kind !== "telehealth" || !a.joinLink) return false; const minutes = (a.date - Date.now()) / 60000; return minutes <= 15 && minutes >= -90; }, []);
  const deriveJourney = useCallback((goal: CarePlanGoal) => {
    setDerivedJourneyGoals((prev) => { if (prev.has(goal.title)) return prev; const next = new Set(prev); next.add(goal.title); return next; });
    setJourneys((prev) => prev.some((j) => j.planGoal === goal.title) ? prev : [...prev, { id: uid("jny"), title: goal.title, why: goal.detail, habits: [{ id: uid("hab"), title: behavioralHabit(goal.title), contextLine: "a tiny version, built around your day", keptDates: [] }], gardenSeed: 5 + Math.floor(Math.random() * 55), planGoal: goal.title }]);
    celebrate(); Haptics.bloom(); SoundEngine.bloom();
  }, [celebrate]);

  const completeOnboarding = useCallback((vals: { firstName: string; lastName: string; birthDate: number | null; pathway: Pathway; connectedSystems: string[]; healthConnected: boolean; values: string; barrier: string; tone: string }) => {
    setTonePreference(vals.tone);
    if (vals.pathway !== pathway) { setPathway(vals.pathway); applyPersona(vals.pathway); }
    setProfileState({ firstName: vals.firstName, lastName: vals.lastName, birthDate: vals.birthDate, healthConnected: vals.healthConnected, connectedSystems: vals.connectedSystems });
    const extra: MemoryItem[] = [];
    if (vals.values) extra.push({ id: uid("mem"), text: `What matters most: ${vals.values}`, learnedFrom: "Your first conversation" });
    if (vals.barrier) extra.push({ id: uid("mem"), text: `Hardest part: ${vals.barrier}`, learnedFrom: "Your first conversation" });
    if (extra.length) setMemory((prev) => [...extra, ...prev]);
    setJustBloomed(true);
    setHasOnboarded(true);
  }, [pathway, applyPersona]);

  const resetDemoPatient = useCallback(() => {
    abortRef.current?.abort();
    applyPersona(pathway, true);
    setOrbState('ambient'); setIsThinking(false);
  }, [applyPersona, pathway]);
  const prioritizeGuideItem = useCallback((id: string) => {
    setGuideItems((prev) => { const item = prev.find((g) => g.id === id); return item ? [item, ...prev.filter((g) => g.id !== id)] : prev; });
  }, []);

  const wipe = useCallback(() => {
    abortRef.current?.abort(); reflectionAbortRef.current?.abort();
    clearProfileMemory();
    localStorage.removeItem(PERSIST_KEY);
    window.location.reload();
  }, []);

  // ---- derived ----
  const pendingActions = useMemo(() => agentActions.filter((a) => a.state === "proposed"), [agentActions]);
  const needsYou = useMemo<NeedsYou[]>(() => {
    const items: NeedsYou[] = [];
    if (!resultAcknowledged && careBundle.resultToAck) items.push({ id: "result", kind: "result", title: `New result — ${careBundle.resultToAck.title}`, detail: careBundle.resultToAck.detail, destination: { t: "records" } });
    appointments.filter((a) => a.status === "pending").forEach((a) => items.push({ id: a.id, kind: "appointment", title: `Waiting to confirm in your portal: ${a.with}`, detail: new Date(a.date).toLocaleDateString([], { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }), destination: { t: "appointmentDetail", id: a.id } }));
    return items;
  }, [resultAcknowledged, careBundle, appointments]);

  const careUnreadCount = useMemo(() => (!resultAcknowledged && careBundle.resultToAck ? 1 : 0), [resultAcknowledged, careBundle]);

  const reports = useCallback((rangeDays: number): DoctorReport[] => buildReports({ persona: activePersona, careTeam, labSeries, medications, logs, guideItems, entries, rangeDays }), [activePersona, careTeam, labSeries, medications, logs, guideItems, entries]);
  const shareThroughPortal = useCallback((detail: string) => {
    if (canStopDemo(browserDemo.phase)) { setShowAgentNetwork(true); return; }
    const appointment = appointments.find((a) => a.status !== "cancelled" && a.date > Date.now()) ?? appointments[0];
    dispatchBrowserDemo({ type: "start", scenario: "visit", patient: activePersona.firstName, detail, appointmentId: appointment?.id, appointmentDate: appointment?.date, destination: appointment?.location });
    setShowAgentNetwork(true);
  }, [browserDemo.phase, appointments, activePersona.firstName]);
  const toggleConnection = useCallback((id: string) => {
    setConnections((prev) => prev.map((c) => c.id === id ? { ...c, connected: !c.connected, accountLine: !c.connected ? sampleAccount(id, displayFirstName) : null } : c));
  }, [displayFirstName]);
  const toggleAgentService = useCallback((id: string) => setAgentServices((prev) => prev.map((a) => a.id === id ? { ...a, active: !a.active } : a)), []);

  // ---- agent activity ----
  const tasksForAgent = useCallback((id: string) => agentTasks.filter((t) => t.agentID === id), [agentTasks]);
  const agentTasksWaiting = useMemo(() => agentTasks.filter((t) => t.status === "waiting" && (agentServices.find((a) => a.id === t.agentID)?.active ?? true)), [agentTasks, agentServices]);
  const agentTasksInMotion = useMemo(() => agentTasks.filter((t) => (t.status === "working" || t.status === "scheduled") && (agentServices.find((a) => a.id === t.agentID)?.active ?? true)), [agentTasks, agentServices]);
  const activeTaskCount = useCallback((id: string) => agentTasks.filter((t) => t.agentID === id && (t.status === "working" || t.status === "waiting" || t.status === "scheduled")).length, [agentTasks]);
  const waitingCount = useCallback((id: string) => agentTasks.filter((t) => t.agentID === id && t.status === "waiting").length, [agentTasks]);
  const approveAgentTask = useCallback((id: string) => {
    const task = agentTasks.find((t) => t.id === id);
    if (!task) return;
    setAgentTasks((prev) => prev.map((t) => t.id === id ? { ...t, status: "done" as const } : t));
    setStoryEvents((prev) => [{ id: uid("s"), kind: "companion", date: Date.now(), title: task.title, detail: `Demo only · ${task.outcomeLine} · No external action taken.` }, ...prev]);
    setQuickLogAck(`Demo only · ${task.outcomeLine} · Nothing sent or charged.`);
    celebrate(); Haptics.bloom(); SoundEngine.bloom();
    setTimeout(() => setQuickLogAck((cur) => (cur?.includes(task.outcomeLine) ? null : cur)), 5000);
  }, [agentTasks, celebrate]);
  const declineAgentTask = useCallback((id: string) => { setAgentTasks((prev) => prev.filter((t) => t.id !== id)); Haptics.tick(); }, []);
  const openAgentNetwork = useCallback((focus?: string | null) => { setAgentNetworkFocus(focus ?? null); setShowAgentNetwork(true); }, []);

  const series = useCallback((id: string) => labSeries.find((s) => s.id === id), [labSeries]);
  const logsNear = useCallback((medID: string) => logs.filter((l) => l.linkedMedID === medID), [logs]);
  const hasDerivedJourney = useCallback((title: string) => derivedJourneyGoals.has(title), [derivedJourneyGoals]);
  const showsLookingAhead = Boolean(careBundle.lookingAhead);

  useEffect(() => {
    if (browserDemo.phase !== 'done' || !browserDemo.receipt || appliedRun.current === browserDemo.run) return;
    appliedRun.current = browserDemo.run;
    const task = browserDemo;
    if (task.scenario === 'recipe') {
      const selected = savedRecipes.filter(r => task.recipeIds.includes(r.id));
      setMealPreferences(task.preferences);
      setImportedRecipes(old => [...old.filter(r => !task.recipeIds.includes(r.recipeId)), ...selected.map(r => ({ recipeId: r.id, importedAt: Date.now(), insight: recipeInsight(r, task.preferences) }))]);
      const planned = task.recipeIds.map((recipeId, i) => { const date = new Date(); date.setDate(date.getDate() + i); return { id: `${recipeId}-${date.toDateString()}`, recipeId, day: date.toDateString(), slot: 'Dinner' }; });
      setMealPlan(old => [...old.filter(p => !planned.some(n => n.day === p.day && n.slot === p.slot)), ...planned]);
    } else if (task.scenario === 'activity') {
      setActivityPlan(old => [...old.filter(p => p.id !== 'saved-gentle'), { id: 'saved-gentle', title: 'Gentle mobility & a short walk', minutes: 15, image: '/img/rumi-mobility-clay-v1.webp', source: '@move.kindly · fictional saved post', day: new Date().toDateString() }]);
    } else if (task.scenario === 'labs') {
      setGuideItems(old => [...old.filter(g => g.id !== 'agent-lab-question'), { id: 'agent-lab-question', kind: 'Question', text: task.detail, addedFrom: 'Sample portal review', resolved: false }]);
    } else if (task.scenario === 'visit') {
      setStoryEvents(old => [{ id: `portal-message-${task.run}`, kind: 'companion', date: Date.now(), title: `Sent through ${activePersona.officeName}'s portal`, detail: `Rumi Works, with your approval · sample portal, no external delivery.\n${task.detail}` }, ...old]);
    } else if (task.scenario === 'ride' && task.appointmentId) {
      setSampleRides(old => [...old.filter(r => r.appointmentId !== task.appointmentId), { appointmentId: task.appointmentId, pickupAt: task.appointmentDate - task.pickupOffset * 60000, destination: task.destination, fare: task.fare, status: task.rideAction === 'cancel' ? 'cancelled' : task.rideAction === 'rebook' ? 'rebooked' : 'scheduled', driver: 'Alex · 4.94', plate: 'DEMO 204', update: task.detail, checkedAt: Date.now() }]);
    }
  }, [browserDemo, activePersona.officeName, appointments]);

  const simulateRideUpdate = useCallback((id: string, update: 'late' | 'moved' | 'cancel') => {
    const appointment = appointments.find(a => a.id === id);
    const ride = sampleRides.find(r => r.appointmentId === id);
    if (!appointment || !ride || canStopDemo(browserDemo.phase)) return;
    setWatchedRideId(null);
    if (browserDemo.scenario !== 'ride' || browserDemo.appointmentId !== id || browserDemo.phase !== 'done') dispatchBrowserDemo({ type: 'restoreRide', patient: activePersona.firstName, appointmentId: id, appointmentDate: appointment.date, destination: appointment.location, fare: ride.fare });
    const newDate = update === 'moved' ? appointment.date + 3600000 : appointment.date;
    if (update === 'moved') setAppointments(old => old.map(a => a.id === id ? { ...a, date: newDate } : a));
    setSampleRides(old => old.map(r => r.appointmentId === id ? { ...r, status: update === 'late' ? 'driver-late' : r.status, checkedAt: Date.now(), update: update === 'late' ? 'Sample driver delayed 18 minutes; replacement needs approval.' : update === 'moved' ? 'Sample portal appointment moved one hour; ride is still at its original time.' : 'Cancellation proposed; current ride unchanged until approval.' } : r));
    const detail = update === 'cancel' ? `Cancel the sample ride to ${appointment.location}. $0 sample cancellation fee. No replacement.` : `${update === 'late' ? 'Driver delayed 18 minutes. Cancel the old sample ride ($0 fee) and rebook' : 'Portal visit moved one hour. Replace the old sample ride ($0 fee)'} for $29 to ${appointment.location}. Pickup ${new Date(newDate - (update === 'late' ? 60 : 45) * 60000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}; retain an arrival buffer. Only this proposal is authorized.`;
    dispatchBrowserDemo({ type: 'rideUpdate', update, detail, appointmentDate: newDate });
    setShowAgentNetwork(true);
  }, [appointments, sampleRides, browserDemo, activePersona.firstName]);
  useEffect(() => {
    if (!watchedRideId || canStopDemo(browserDemo.phase)) return;
    const timer = window.setTimeout(() => simulateRideUpdate(watchedRideId, 'late'), 12000);
    return () => window.clearTimeout(timer);
  }, [watchedRideId, browserDemo.phase, simulateRideUpdate]);

  const dispatchReviewedBrowserEvent = useCallback((event: BrowserDemoEvent) => {
    if (event.type === 'approve' && browserDemo.phase === 'review' && browserDemo.scenario === 'ride') {
      const appointment = appointments.find(a => a.id === browserDemo.appointmentId);
      if (!appointment || appointment.status === 'cancelled') { dispatchBrowserDemo({ type: 'stop' }); return; }
      if (appointment.date !== browserDemo.appointmentDate || appointment.location !== browserDemo.destination) {
        dispatchBrowserDemo({ type: 'appointmentChanged', date: appointment.date, destination: appointment.location, detail: `$${browserDemo.fare} sample ${browserDemo.rideAction} for ${appointment.with}, now ${new Date(appointment.date).toLocaleString()} at ${appointment.location}. Pickup ${new Date(appointment.date - browserDemo.pickupOffset * 60000).toLocaleTimeString()}. $0 sample cancellation fee; no external charge.` });
        return;
      }
    }
    dispatchBrowserDemo(event);
  }, [browserDemo, appointments]);
  const value: SanoStore = {
    importedRecipes, mealPlan, activityPlan, sampleRides, mealPreferences, setMealPreferences, simulateRideUpdate, watchedRideId, setWatchedRideId,
    aiConsent, setAIConsent, memoryConsent, setMemoryConsent, stopAI, confirmMemory, editMemory,
    liveSupport, supportStatus, refreshSupport, dismissSupport,
    browserDemo, dispatchBrowserDemo: dispatchReviewedBrowserEvent, resetDemoPatient, prioritizeGuideItem,
    tab, setTab, hasOnboarded, showConversation, openConversation, closeConversation,
    showQuickLog, setShowQuickLog, quickLogMedID, setQuickLogMedID, showSettings, setShowSettings,
    showRecap, setShowRecap, pendingCareDest, setPendingCareDest,
    pathway, persona: activePersona, profile, setProfile, displayFirstName,
    moments, insights, medications, journeys, programs, logs, currents, labSeries, storyEvents,
    careTeam, appointments, guideItems, recordItems, sources, consents, memory,
    entries, agentActions, memories,
    resultToAck: careBundle.resultToAck ?? null, resultAcknowledged, lookingAhead: careBundle.lookingAhead ?? null, showsLookingAhead, derivedJourneyGoals,
    tonePreference, setTonePreference, appearance, setAppearance, scheme,
    musicOn, setMusicOn, soundOn, setSoundOn, epsilonConsent, setEpsilonConsent, eraWarmth, setEraWarmth,
    notificationClasses, toggleNotification, quietStart, quietEnd, setQuiet,
    orbState, justBloomed, quickLogAck, setQuickLogAck,
    turns, isThinking, sendMessage, sendVoiceMessage, resolveRich,
    pendingActions, needsYou, careUnreadCount,
    connections, agentServices, reports, shareThroughPortal, toggleConnection, toggleAgentService,
    agentTasks, agentTasksWaiting, agentTasksInMotion, tasksForAgent, activeTaskCount, waitingCount, approveAgentTask, declineAgentTask,
    showAgentNetwork, setShowAgentNetwork, agentNetworkFocus, openAgentNetwork,
    series, logsNear, hasDerivedJourney,
    completeOnboarding, switchPathway, dismissMoment, keepHabit, keptToday, addEntry, removeEntry,
    approveAction, declineAction, addMemoryGlimpse, deleteMemoryGlimpse, addLog,
    addGuideItem: addGuideItemImpl, toggleGuideResolved, removeGuideItem, markInsightSeen, toggleInsightSaved,
    enroll, decline, toggleCurrentSaved, setTaste, deleteMemoryNote, addMemoryNote, acknowledgeResult,
    applyPortalAppointmentUpdate, canJoin, deriveJourney, wipe,
  };

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
};

function mealSlot(ts: number): string {
  const h = new Date(ts).getHours();
  if (h >= 5 && h < 11) return "Breakfast";
  if (h >= 11 && h < 15) return "Lunch";
  if (h >= 15 && h < 17) return "Afternoon";
  return "Dinner";
}
function behavioralHabit(title: string): string {
  const l = title.toLowerCase();
  if (l.includes("walk") || l.includes("move") || l.includes("evening")) return "A few minutes of activity";
  if (l.includes("bp") || l.includes("pressure")) return "A quick morning reading";
  if (l.includes("water") || l.includes("hydrat")) return "Refill the water bottle";
  if (l.includes("prehab") || l.includes("strong")) return "Today's prehab set";
  if (l.includes("nausea")) return "The on-schedule dose reminder";
  return "One small step toward this";
}
