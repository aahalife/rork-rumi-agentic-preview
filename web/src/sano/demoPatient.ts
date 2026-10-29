import type { Persona, RecordItem, RecordSource, MemoryItem } from './types';

/** Records are derived from the selected sample persona; never mixed with provider imports. */
export function demoPatientRecords(persona: Persona): RecordItem[] {
  const labs: RecordItem[] = persona.labSeries.flatMap((series) => {
    const latest = [...series.points].sort((a, b) => b.date - a.date)[0];
    return latest ? [{ id: `demo-${persona.pathway}-${series.id}`, category: 'Labs' as const, title: series.name, detail: `${latest.value} ${series.unit} · sample result`, date: latest.date, source: `Sample · ${series.provenance}`, seriesID: series.id }] : [];
  });
  const meds: RecordItem[] = persona.medications.map((med) => ({ id: `demo-${persona.pathway}-${med.id}`, category: 'Medications', title: med.name, detail: `${med.dose} · ${med.scheduleLine}`, date: Date.now(), source: `Sample · ${med.pharmacy}` }));
  const conditions: RecordItem[] = persona.conditions.map((condition) => ({ id: `demo-${persona.pathway}-${condition.name}`, category: 'Conditions', title: condition.name, detail: condition.state, date: Date.now(), source: 'Synthetic patient history' }));
  return [...labs, ...meds, ...conditions];
}
export function demoPatientSources(persona: Persona): RecordSource[] {
  return [{ id: `demo-${persona.pathway}`, name: `${persona.firstName}’s sample history`, railLabel: 'Demo fixture · not imported', connected: false, lastSync: Date.now() }];
}
export function demoPatientMemory(persona: Persona): MemoryItem[] {
  return [{ id: 'demo-identity', text: `This is ${persona.firstName}’s synthetic demo, not the user’s medical history.`, learnedFrom: 'Demo patient' }, { id: 'demo-journey', text: persona.journeys[0]?.why ?? 'One small step at a time.', learnedFrom: 'Sample journey' }];
}
