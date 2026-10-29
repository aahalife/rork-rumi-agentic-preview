import React from 'react';
import { act, cleanup, render } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SanoProvider, useSano } from '../sano/store';
import { savedRecipes } from '../sano/recipeCollection';
import type { DemoScenario } from '../sano/browserDemo';
vi.mock('../sano/sound', () => ({ SoundEngine: new Proxy({}, { get: () => vi.fn() }), Haptics: new Proxy({}, { get: () => vi.fn() }) }));
let current: ReturnType<typeof useSano> | null = null;
function Probe() { current = useSano(); return null; }
const store = (): ReturnType<typeof useSano> => { if (!current) throw new Error('Provider not mounted'); return current; };
const tick = (count = 1) => { for (let i = 0; i < count; i++) act(() => { vi.advanceTimersByTime(2500); }); };
const start = (scenario: DemoScenario) => act(() => { const s = store(); const a = s.appointments.find(a => a.kind === 'inPerson')!; s.dispatchBrowserDemo({ type: 'start', scenario, patient: s.persona.firstName, detail: 'Exact sample $24 proposal', appointmentId: a.id, appointmentDate: a.date, destination: a.location, preferences: s.mealPreferences }); });
beforeEach(() => { vi.useFakeTimers(); localStorage.clear(); render(<SanoProvider><Probe /></SanoProvider>); });
afterEach(() => { cleanup(); current = null; vi.useRealTimers(); });
describe('per-device, per-profile memory', () => {
  it('turns AI and memory on by default', () => {
    expect(store().aiConsent).toBe(true); expect(store().memoryConsent).toBe(true);
  });
  it('keeps memory under this device and profile, and restores it after reload', () => {
    act(() => store().addMemoryNote('I walk best after lunch', 'Your conversation'));
    const device = localStorage.getItem('rumi.device.v1');
    expect(device).toMatch(/^[A-Za-z0-9-]{20,64}$/);
    const key = `rumi.profile.v1.${device}.${store().pathway}`;
    expect(JSON.parse(localStorage.getItem(key) ?? '{}').memory[0].text).toBe('I walk best after lunch');
    expect(JSON.parse(localStorage.getItem('sano.web.v1') ?? '{}').memory).toBeUndefined();
    cleanup(); current = null; render(<SanoProvider><Probe /></SanoProvider>);
    expect(store().memory[0].text).toBe('I walk best after lunch');
  });
  it('another visitor on the same demo profile starts with their own clean memory', () => {
    act(() => store().addMemoryNote('Private to visitor A', 'Your conversation'));
    cleanup(); current = null;
    localStorage.setItem('rumi.device.v1', 'visitor-b-0000000000000000');
    vi.resetModules();
    return import('../sano/store').then(({ SanoProvider: FreshProvider, useSano: freshUse }) => {
      let fresh: ReturnType<typeof freshUse> | null = null;
      function FreshProbe() { fresh = freshUse(); return null; }
      render(<FreshProvider><FreshProbe /></FreshProvider>);
      expect(fresh!.memory.some(m => m.text === 'Private to visitor A')).toBe(false);
    });
  });
  it('switching profiles keeps each profile’s memory separate', () => {
    act(() => store().addMemoryNote('Marcus-only note', 'Your conversation'));
    act(() => store().switchPathway('oncology'));
    expect(store().memory.some(m => m.text === 'Marcus-only note')).toBe(false);
    act(() => store().switchPathway('metabolic'));
    expect(store().memory[0].text).toBe('Marcus-only note');
  });
});

describe('root-owned autonomous end-to-end workspace', () => {
  it('imports source and art into catalog and meal plan without logging a consumed meal', () => {
    const before = store().entries.length; start('recipe'); act(() => store().setShowAgentNetwork(false)); tick(6);
    expect(store().browserDemo.phase).toBe('done'); expect(store().importedRecipes).toHaveLength(1); expect(store().mealPlan).toHaveLength(1); expect(store().entries).toHaveLength(before);
    const recipe = savedRecipes.find(r => r.id === store().importedRecipes[0].recipeId)!; expect(recipe.image).not.toBe(recipe.artwork);
    act(() => store().addEntry('Meals', recipe.title)); expect(store().entries[0].imageName).toBe(recipe.artwork);
    const persisted = JSON.parse(localStorage.getItem('sano.web.v1') ?? '{}'); expect(persisted.importedRecipes).toHaveLength(1);
  });
  it('follow-up goals generate a populated restricted week plan', () => {
    start('recipe'); tick(6); act(() => store().dispatchBrowserDemo({ type: 'followup', text: 'Plan this week dairy-free high protein' })); tick(5);
    expect(store().mealPlan).toHaveLength(7); expect(store().importedRecipes.length).toBeGreaterThanOrEqual(7);
    expect(store().mealPlan.every(p => !savedRecipes.find(r => r.id === p.recipeId)?.allergens.includes('milk'))).toBe(true);
  });
  it('portal labs add a local question; sending a visit message still needs permission', () => {
    start('labs'); tick(5); expect(store().guideItems.some(g => g.id === 'agent-lab-question')).toBe(true);
    const sent = () => store().storyEvents.filter(e => e.id.startsWith('portal-message-'));
    start('visit'); tick(5); expect(store().browserDemo.phase).toBe('review'); expect(sent()).toHaveLength(0);
    act(() => store().dispatchBrowserDemo({ type: 'approve' })); expect(sent()).toHaveLength(1); expect(sent()[0].detail).toContain('no external delivery');
  });
  it('links rides to visits and does not cancel the existing ride on decline', () => {
    start('ride'); tick(5); expect(store().sampleRides).toHaveLength(0); act(() => store().dispatchBrowserDemo({ type: 'approve' }));
    const ride = store().sampleRides[0]; const a = store().appointments.find(a => a.id === ride.appointmentId)!;
    expect(ride.pickupAt).toBe(a.date - 45 * 60000);
    act(() => store().simulateRideUpdate(a.id, 'late')); tick(4); expect(store().browserDemo.phase).toBe('review'); expect(store().sampleRides[0].fare).toBe(24);
    act(() => store().dispatchBrowserDemo({ type: 'stop' })); expect(store().sampleRides[0].status).toBe('driver-late'); expect(store().sampleRides[0].fare).toBe(24);
  });
  it('detects an opted-in sample delay while minimized, then rebooks only after fresh approval', () => {
    start('ride'); tick(5); act(() => store().dispatchBrowserDemo({ type: 'approve' })); const id = store().sampleRides[0].appointmentId;
    act(() => { store().setShowAgentNetwork(false); store().setWatchedRideId(id); }); tick(5); expect(store().sampleRides[0].status).toBe('driver-late');
    tick(4); expect(store().browserDemo.phase).toBe('review'); expect(store().sampleRides[0].fare).toBe(24);
    act(() => store().dispatchBrowserDemo({ type: 'approve' })); expect(store().sampleRides[0].status).toBe('rebooked'); expect(store().sampleRides[0].fare).toBe(29);
  });
  it('appointment moves update visit info while old pickup remains until approval', () => {
    start('ride'); tick(5); act(() => store().dispatchBrowserDemo({ type: 'approve' })); const old = store().sampleRides[0]; const a = store().appointments.find(a => a.id === old.appointmentId)!;
    act(() => store().simulateRideUpdate(a.id, 'moved')); expect(store().appointments.find(item => item.id === a.id)?.date).toBe(a.date + 3600000); expect(store().sampleRides[0].pickupAt).toBe(old.pickupAt);
    tick(4); act(() => store().dispatchBrowserDemo({ type: 'approve' })); expect(store().sampleRides[0].pickupAt).toBe(old.pickupAt + 3600000);
  });
  it('invalidates a ride proposal when the appointment changes before approval', () => {
    start('ride'); tick(5); const id = store().browserDemo.appointmentId; const newDate = store().browserDemo.appointmentDate + 3600000;
    act(() => store().applyPortalAppointmentUpdate(id, newDate)); act(() => store().dispatchBrowserDemo({ type: 'approve' })); expect(store().browserDemo.phase).toBe('browsing'); expect(store().sampleRides).toHaveLength(0);
    tick(); act(() => store().dispatchBrowserDemo({ type: 'approve' })); expect(store().sampleRides[0].pickupAt).toBe(newDate - 45 * 60000);
  });
  it('cancellation is a reviewed action and patient reset clears all imported plans', () => {
    start('ride'); tick(5); act(() => store().dispatchBrowserDemo({ type: 'approve' })); const id = store().sampleRides[0].appointmentId;
    act(() => store().simulateRideUpdate(id, 'cancel')); tick(4); expect(store().sampleRides[0].status).toBe('scheduled'); act(() => store().dispatchBrowserDemo({ type: 'approve' })); expect(store().sampleRides[0].status).toBe('cancelled');
    start('recipe'); tick(6); act(() => store().switchPathway('oncology')); expect(store().mealPlan).toHaveLength(0); expect(store().importedRecipes).toHaveLength(0); expect(store().sampleRides).toHaveLength(0); expect(store().browserDemo.phase).toBe('idle');
  });
  it('portal follow-up goals revise the draft and require approval again', () => {
    const sent = () => store().storyEvents.filter(e => e.id.startsWith('portal-message-'));
    start('visit'); tick(5);
    act(() => store().dispatchBrowserDemo({ type: 'followup', text: 'Include a question about my refill before the visit' }));
    expect(store().browserDemo.phase).toBe('browsing'); act(() => store().dispatchBrowserDemo({ type: 'approve' })); expect(sent()).toHaveLength(0);
    tick(3); expect(store().browserDemo.phase).toBe('review'); expect(store().browserDemo.detail).toContain('my refill');
    act(() => store().dispatchBrowserDemo({ type: 'approve' })); expect(sent()[0].detail).toContain('my refill');
  });
  it('portal-duplicative features are not rebuilt inside Rumi', () => {
    const s = store() as unknown as Record<string, unknown>;
    for (const key of ['threads', 'bills', 'walletCards', 'careDocuments', 'savings', 'requests', 'payBill', 'startThread', 'confirmAppointment']) expect(s[key]).toBeUndefined();
    expect(store().needsYou.every(n => n.kind === 'result' || n.kind === 'appointment')).toBe(true);
  });
  it('sharing a report hands off to Rumi Works and still needs approval', () => {
    act(() => store().shareThroughPortal('Primary care summary for Dr. Patterson'));
    expect(store().showAgentNetwork).toBe(true); expect(store().browserDemo.scenario).toBe('visit');
    tick(5); expect(store().browserDemo.phase).toBe('review'); expect(store().browserDemo.detail).toContain('Dr. Patterson');
  });
  it('activity planning stays distinct from completion logging', () => { const n = store().entries.length; start('activity'); tick(5); expect(store().activityPlan).toHaveLength(1); expect(store().entries).toHaveLength(n); });
});
