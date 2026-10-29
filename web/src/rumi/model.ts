import { z } from 'zod';

export type Member = 'primary' | 'maria' | 'tom';
export const members: Member[] = ['primary', 'maria', 'tom'];
export const profiles = {
  primary: { name: 'Primary demo member', initials: 'PM', subtitle: 'Supplied clinical scenario', program: 'Diabetes & lipid care discussion', description: 'Long-standing type 2 diabetes and hyperlipidemia. Name, age and weight were not supplied.', meds: ['Atorvastatin 40 mg', 'Metformin ER 2000 mg', 'Mounjaro 12.5 mg'], goals: ['Prepare questions about repeat labs', 'Discuss cholesterol and kidney health with my PCP', 'Plan a manageable weekday meal'] },
  maria: { name: 'Maria Alvarez', initials: 'MA', subtitle: 'Diabetes care · DeRx story', program: 'Transform Diabetes Care', description: 'Fictional member, age 55. Endocrinologist Dr. Priya Shah and PCP Dr. Marcus Lee at fictional Riverside Primary Care. CVS pickup preference.', meds: ['Glargine 24 units at bedtime · Baseline', 'Semaglutide 0.25 mg · Fictional story'], goals: ['A short after-dinner walk', 'Plan easy weekday dinners', 'Prepare questions for Dr. Shah'] },
  tom: { name: 'Tom Becker', initials: 'TB', subtitle: 'Prevention · Digital-first support', program: 'Weight Management Prevention', description: 'Fictional member, age 58. Largely self-managing. No supplied diabetes diagnosis, insulin or GLP-1. No connected monitoring devices.', meds: ['No insulin or GLP-1 story'], goals: ['Walk ten minutes after lunch, four days a week', 'Keep a more consistent bedtime', 'Find quick weekday meals'] },
};
export const metrics = ['HbA1c', 'LDL-C', 'eGFR', 'Weight', 'Sleep', 'Activity', 'BMI', 'CGM glucose', 'Time in range'] as const;
export type Metric = typeof metrics[number];
export const units: Record<Metric, string> = { HbA1c: '%', 'LDL-C': 'mg/dL', eGFR: 'mL/min/1.73 m²', Weight: 'lb', Sleep: 'hours', Activity: 'steps', BMI: 'kg/m²', 'CGM glucose': 'mg/dL', 'Time in range': '%' };
export interface Query { operation: 'latest' | 'trend' | 'lastN' | 'sideBySide' | 'cohort' | 'timeInRange'; metrics: Metric[]; days?: number; count?: number }
export interface Point { date: number; value: number }
export interface Series { metric: Metric; points: Point[]; facts: string[]; limitation: string }
export interface Insight { id: string; member: Member; query: Query; series: Series[]; anchor: number }
export interface Turn { id: string; role: 'user' | 'assistant'; text: string; insights?: Insight[]; kind?: string; invitesGoal?: boolean }
export interface Ingredient { name: string; amount: number; unit: string }
export interface State { anchor: number; messages: Turn[]; goals: string[]; remembering: boolean; stage: number; semaglutide: number; receipts: { text: string; date: number }[]; saved: string[]; cart: Ingredient[]; ride?: string }
export const initialState = (member: Member): State => ({ anchor: new Date().setHours(0, 0, 0, 0), messages: [], goals: [...profiles[member].goals], remembering: false, stage: 0, semaglutide: 0, receipts: [], saved: [], cart: [] });
export function loadStates(): Record<Member, State> {
  const defaults = Object.fromEntries(members.map(m => [m, initialState(m)])) as Record<Member, State>;
  const short = z.string().max(6000);
  const schema = z.object({ anchor: z.number().finite().min(0).max(8640000000000000), remembering: z.boolean(), stage: z.number().int().min(0).max(4), semaglutide: z.number().int().min(0).max(2), goals: z.array(short).max(200), receipts: z.array(z.object({ text: short, date: z.number().finite() })).max(1000), saved: z.array(z.enum(['bowl', 'tray'])).max(2), cart: z.array(z.object({ name: z.string().max(100), amount: z.number().finite().nonnegative().max(100000), unit: z.string().max(30) })).max(200), ride: short.optional(), messages: z.array(z.object({ id: z.string().uuid(), role: z.enum(['user', 'assistant']), text: short, kind: z.enum(['live', 'guided', 'preview', 'calculated']).optional(), invitesGoal: z.boolean().optional(), insights: z.array(z.object({ member: z.enum(['primary', 'maria', 'tom']), query: z.unknown() })).max(4).optional() })).max(1000) });
  try {
    const raw = localStorage.getItem('rumi.web.isolated-demo.v1') || '{}';
    if (raw.length > 5000000) return defaults;
    const saved = JSON.parse(raw);
    for (const m of members) {
      try {
        const parsed = schema.parse(saved[m]);
        if (m !== 'maria' && (parsed.stage !== 0 || parsed.semaglutide !== 0)) continue;
        const messages: Turn[] = parsed.messages.map(t => ({ ...t, insights: t.insights?.map(i => { if (i.member !== m) throw new Error('Member mismatch'); const query = parseQueries(JSON.stringify({ requests: [i.query] }))[0]; return evaluate(query, m, parsed.anchor); }) })) as Turn[];
        defaults[m] = { ...parsed, messages } as State;
      } catch { /* Invalid member data resets only that member. */ }
    }
  } catch { /* Corrupted local fixtures reset safely. */ }
  return defaults;
}
export const dateLabel = (date: number) => new Date(date).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
export const number = (n: number) => n.toLocaleString(undefined, { maximumFractionDigits: 2 });
export function observations(member: Member, metric: Metric, anchor: number): Point[] {
  let offsets: number[] = [], values: number[] = [];
  if (member === 'primary') {
    offsets = [270, 70]; values = metric === 'HbA1c' ? [9, 8.8] : metric === 'LDL-C' ? [130, 130] : metric === 'eGFR' ? [60, 55] : [];
  } else if (metric === 'Weight') { offsets = [92, 60, 30, 0]; values = member === 'maria' ? [216.7, 214.2, 211.4, 208.7] : [228, 226.5, 225.8, 224]; }
  else if (metric === 'HbA1c') { offsets = member === 'maria' ? [92, 50, 0] : [0]; values = member === 'maria' ? [8.6, 8.2, 7.8] : [5.8]; }
  else if (member === 'tom' && (metric === 'Sleep' || metric === 'Activity')) {
    offsets = Array.from({ length: 14 }, (_, i) => 13 - i);
    values = offsets.map((_, i) => metric === 'Sleep' ? 6.4 + [0.2, -0.4, 0.5, -0.1, -0.3, 0.1, 0][i % 7] : 4800 + [400, -600, 800, -300, -400, 100, 0][i % 7]);
  }
  return values.map((value, i) => { const date = new Date(anchor); date.setDate(date.getDate() - offsets[i]); return { date: date.getTime(), value }; });
}
export function parseQueries(raw: string): Query[] {
  const envelope = JSON.parse(raw) as { requests?: Query[] };
  if (!envelope || Object.keys(envelope).join() !== 'requests' || !Array.isArray(envelope.requests) || envelope.requests.length < 1 || envelope.requests.length > 4) throw new Error('Invalid insight request. No unverified chart was created.');
  for (const q of envelope.requests) {
    if (!q || Object.keys(q).some(k => !['operation', 'metrics', 'days', 'count'].includes(k)) || !['latest', 'trend', 'lastN', 'sideBySide', 'cohort', 'timeInRange'].includes(q.operation) || !Array.isArray(q.metrics) || q.metrics.some(m => !metrics.includes(m)) || new Set(q.metrics).size !== q.metrics.length || q.metrics.length !== (q.operation === 'sideBySide' ? 2 : 1) || (q.days != null && (!Number.isInteger(q.days) || q.days < 1 || q.days > 3650)) || (q.count != null && (!Number.isInteger(q.count) || q.count < 1 || q.count > 20)) || (q.operation === 'lastN' && q.count == null) || (q.operation === 'timeInRange' && q.metrics[0] !== 'Time in range')) throw new Error('The model returned an unsupported query. No numbers or patient IDs were accepted.');
  }
  return envelope.requests;
}
export function evaluate(query: Query, member: Member, anchor: number): Insight {
  parseQueries(JSON.stringify({ requests: [query] }));
  return { id: crypto.randomUUID(), query, member, anchor, series: query.metrics.map(metric => {
    let points = observations(member, metric, anchor);
    const cutoff = new Date(anchor); cutoff.setDate(cutoff.getDate() - (query.days ?? 3650));
    if (query.days) points = points.filter(p => p.date >= cutoff.getTime() && p.date <= anchor);
    const available = points.length;
    if (query.operation === 'latest') points = points.slice(-1);
    if (query.operation === 'lastN') points = points.slice(-(query.count ?? 4));
    if (query.operation === 'cohort') return { metric, points: [], facts: ['No validated comparison dataset is installed for this demo.'], limitation: 'No peer average, percentile or demographic match was inferred.' };
    if (query.operation === 'timeInRange' || metric === 'Time in range') return { metric, points: [], facts: ['No CGM readings or coverage interval are available to calculate time in range.'], limitation: 'No target or synthetic percentage was substituted.' };
    if (!points.length) return { metric, points, facts: [`No ${metric} observations are available for this member in the requested period.`], limitation: 'Missing data is not zero. BMI requires height and weight; CGM requires actual readings.' };
    const facts = points.map(p => `${metric}: ${number(p.value)} ${units[metric]} · ${member === 'primary' ? p.date === observations(member, metric, anchor)[1]?.date ? 'Repeat supplied result' : 'Earlier supplied result' : dateLabel(p.date)}.`);
    if (points.length > 1 && query.operation !== 'latest') { const delta = points[points.length - 1].value - points[0].value; facts.push(delta === 0 ? 'First-to-last change: unchanged.' : `First-to-last change: ${delta > 0 ? '+' : ''}${number(delta)} ${metric === 'HbA1c' ? 'percentage points' : units[metric]}.`); }
    return { metric, points, facts, limitation: `${member === 'primary' ? 'Supplied fictional scenario. Dates are illustrative, not actual lab dates.' : 'Fictional sample records. Intermediate weights and dates are synthetic.'} No clinical assessment, reference range or cause is inferred.${query.operation === 'lastN' && available < (query.count ?? 4) ? ` Only ${available} results available, fewer than requested.` : ''}` };
  }) };
}
export function explicitData(text: string): boolean {
  return /\b(show|plot|chart|compare|comparison|latest|last \d+|trend|over time|over (?:the last )?\d+ (?:days|weeks|months|years)|side by side|time in range|how many|what (?:is|was|are|were)|review my (?:repeat )?labs)\b/i.test(text) && /\b(a1cs?|hba1cs?|ldl|egfr|weight|bmi|sleep|steps|activity|glucose|cgm|labs|time in range)\b/i.test(text) && !/\b(chest pain|can.t breathe|fainting|unconscious|seizure|low (?:blood )?(?:glucose|sugar)|suicid|kill myself)\b/i.test(text);
}
export const insightTool = { type: 'function', function: { name: 'read_demo_insights', description: 'Read-only fictional-member charts. Up to four requests. Never supply values, dates, patient IDs or diagnoses. SideBySide takes two metrics; others one. Cohort and missing data are honestly unavailable.', parameters: { type: 'object', properties: { requests: { type: 'array', minItems: 1, maxItems: 4, items: { type: 'object', properties: { operation: { type: 'string', enum: ['latest', 'trend', 'lastN', 'sideBySide', 'cohort', 'timeInRange'] }, metrics: { type: 'array', items: { type: 'string', enum: [...metrics] }, minItems: 1, maxItems: 2 }, days: { type: 'integer', minimum: 1, maximum: 3650 }, count: { type: 'integer', minimum: 1, maximum: 20 } }, required: ['operation', 'metrics'], additionalProperties: false } } }, required: ['requests'], additionalProperties: false } } };
export const recipes = [
  { id: 'bowl', title: 'Lemon chickpea & rice bowl', creator: 'weekday.table.demo', image: '/img/rumi-chickpea-source-v1.webp', ingredients: [{ name: 'Chickpeas', amount: 1, unit: 'can' }, { name: 'Brown rice', amount: 150, unit: 'g' }, { name: 'Olive oil', amount: 15, unit: 'mL' }, { name: 'Lemon', amount: 1, unit: 'whole' }, { name: 'Spinach', amount: 100, unit: 'g' }] },
  { id: 'tray', title: 'Salmon & broccoli tray dinner', creator: 'onepan.kitchen.demo', image: '/img/grilled_salmon_lemon_greens.png', ingredients: [{ name: 'Salmon', amount: 2, unit: 'fillets' }, { name: 'Broccoli', amount: 1, unit: 'head' }, { name: 'Lemon', amount: 1, unit: 'whole' }, { name: 'Olive oil', amount: 15, unit: 'mL' }] },
];
export function netNew(ingredients: Ingredient[], cart: Ingredient[]) {
  const pantry: Ingredient[] = [{ name: 'Chickpeas', amount: 1, unit: 'can' }, { name: 'Brown rice', amount: 100, unit: 'g' }, { name: 'Olive oil', amount: 30, unit: 'mL' }];
  return ingredients.map(i => ({ ...i, amount: Math.max(0, i.amount - [...pantry, ...cart].filter(p => p.name === i.name && p.unit === i.unit).reduce((s, p) => s + p.amount, 0)) })).filter(i => i.amount > 0);
}
