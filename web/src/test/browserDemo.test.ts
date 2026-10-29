/// <reference types="node" />
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';
import { browserDemoReducer as reduce, initialBrowserDemo, demoScenarios, type DemoScenario, type BrowserDemoState } from '../sano/browserDemo';
import { curateRecipes, defaultMealPreferences, savedRecipes } from '../sano/recipeCollection';
import { demoPatientRecords, demoPatientSources } from '../sano/demoPatient';
import { personaFor } from '../sano/fixtures';
const start = (scenario: DemoScenario): BrowserDemoState => reduce(initialBrowserDemo, { type: 'start', scenario, patient: 'Marcus', detail: 'Sample $24 proposal', appointmentId: 'visit-1', appointmentDate: Date.now(), destination: 'Clinic' });
const run = (state: BrowserDemoState): BrowserDemoState => { state = reduce(state, { type: 'login' }); for (let i = 0; i < 6; i++) state = reduce(state, { type: 'advance' }); return state; };
const lastReply = (s: BrowserDemoState): string => s.messages[s.messages.length - 1]?.text ?? '';
describe('autonomous sample safeguards', () => {
  it.each(Object.keys(demoScenarios) as DemoScenario[])('%s completes read-only work and gates submissions', scenario => {
    let state = start(scenario);
    state = reduce(state, { type: 'approve' }); expect(state.phase).toBe('login');
    state = reduce(state, { type: 'collapse' }); state = run(state);
    expect(state.collapsed).toBe(true);
    if (scenario === 'ride' || scenario === 'visit') { expect(state.phase).toBe('review'); expect(state.receipt).toBeNull(); state = reduce(state, { type: 'approve' }); }
    expect(state.phase).toBe('done'); expect(state.receipt).toContain('no external action taken');
  });
  it('chat is optional, answers from context and never authorizes', () => {
    let state = run(start('ride'));
    state = reduce(state, { type: 'followup', text: 'Explain this' }); expect(lastReply(state)).toContain('$24');
    state = reduce(state, { type: 'followup', text: 'Approve and book' }); expect(lastReply(state)).toContain('approval card'); expect(state.phase).toBe('review');
    state = reduce(state, { type: 'stop' }); expect(reduce(state, { type: 'approve' }).phase).toBe('stopped');
  });
  it('pause, stop and interrupted timers cannot advance', () => {
    let state = reduce(start('ride'), { type: 'login' }); state = reduce(state, { type: 'pause' });
    expect(reduce(state, { type: 'advance' })).toBe(state);
    state = reduce(state, { type: 'resume' }); state = reduce(state, { type: 'interrupt' }); expect(state.phase).toBe('failed');
    state = reduce(state, { type: 'retry' }); expect(state.phase).toBe('login'); state = reduce(state, { type: 'stop' }); expect(reduce(state, { type: 'login' })).toBe(state);
  });
  it('price changes and ride updates invalidate prior approvals', () => {
    let state = run(start('ride')); state = reduce(state, { type: 'changeFare' }); expect(reduce(state, { type: 'approve' }).receipt).toBeNull();
    state = reduce(state, { type: 'advance' }); state = reduce(state, { type: 'approve' }); expect(state.receipt).toContain('$29');
    state = reduce(state, { type: 'rideUpdate', update: 'late', detail: 'Replace delayed ride for $29' }); expect(state.phase).toBe('browsing'); expect(state.rideAction).toBe('rebook'); expect(state.receipt).toBeNull();
    expect(reduce(state, { type: 'approve' }).phase).toBe('browsing'); state = run(state); expect(state.phase).toBe('review');
    state = reduce(state, { type: 'stop' }); expect(state.receipt).toBeNull();
  });
  it('recipe follow-up goals really change curation and week plan', () => {
    let state = run(start('recipe')); expect(state.recipeIds).toHaveLength(1);
    state = reduce(state, { type: 'followup', text: 'Plan this week dairy-free gluten-free nut-free high protein under 15 minutes' });
    expect(state.phase).toBe('browsing'); state = run(state); expect(state.phase).toBe('done'); expect(state.recipeIds.length).toBeGreaterThan(1);
    for (const id of state.recipeIds) { const recipe = savedRecipes.find(r => r.id === id)!; expect(recipe.allergens).not.toContain('milk'); expect(recipe.allergens).not.toContain('nuts'); expect(recipe.tags).toContain('gluten-free'); expect(recipe.minutes).toBeLessThanOrEqual(15); }
    expect(state.detail).toContain('Ranked by protein');
  });
  it('has 36 populated posts and never silently drops restrictions', () => {
    expect(savedRecipes).toHaveLength(36);
    expect(new Set(savedRecipes.map(r => r.image)).size).toBe(36);
    for (const recipe of savedRecipes) { expect(existsSync(resolve(process.cwd(), 'public', recipe.image.slice(1)))).toBe(true); expect(existsSync(resolve(process.cwd(), 'public', recipe.artwork.slice(1)))).toBe(true); } expect(new Set(savedRecipes.map(r => r.title)).size).toBe(36);
    expect(savedRecipes.every(r => r.ingredients.length > 2 && r.method.length > 1 && r.protein > 0 && r.caption && r.author)).toBe(true);
    expect(curateRecipes({ ...defaultMealPreferences, maxMinutes: 0 })).toHaveLength(0);
    const state = reduce(initialBrowserDemo, { type: 'start', scenario: 'recipe', patient: 'Marcus', detail: '', preferences: { ...defaultMealPreferences, maxMinutes: 0 } }); expect(state.phase).toBe('failed');
  });
  it.each(['metabolic', 'oncology', 'procedure', 'cardiometabolic'] as const)('%s keeps sample records isolated', pathway => {
    const persona = personaFor(pathway); expect(demoPatientRecords(persona).filter(r => r.category === 'Medications').map(r => r.title)).toEqual(persona.medications.map(m => m.name)); expect(demoPatientSources(persona).every(s => !s.connected)).toBe(true);
  });
});
