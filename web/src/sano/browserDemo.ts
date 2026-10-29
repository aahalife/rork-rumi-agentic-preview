import { curateRecipes, defaultMealPreferences, recipeInsight, savedRecipes, type MealPreferences } from './recipeCollection';
export type DemoScenario = 'labs' | 'visit' | 'recipe' | 'ride' | 'activity';
export type DemoPhase = 'idle' | 'login' | 'browsing' | 'paused' | 'review' | 'done' | 'stopped' | 'failed';
export interface BrowserDemoState {
  scenario: DemoScenario | null; phase: DemoPhase; step: number; collapsed: boolean;
  patient: string; detail: string; receipt: string | null; fare: number;
  messages: { role: 'you' | 'rumi'; text: string }[];
  run: number; selectedRecipeId: string; recipeIds: string[]; preferences: MealPreferences;
  planWeek: boolean; appointmentId: string; appointmentDate: number; destination: string;
  rideAction: 'book' | 'rebook' | 'cancel'; pickupOffset: number;
}
export type BrowserDemoEvent =
  | { type: 'start'; scenario: DemoScenario; patient: string; detail: string; appointmentId?: string; appointmentDate?: number; destination?: string; preferences?: MealPreferences }
  | { type: 'followup'; text: string }
  | { type: 'rideUpdate'; update: 'late' | 'moved' | 'cancel'; detail: string; appointmentDate?: number }
  | { type: 'appointmentChanged'; date: number; destination: string; detail: string }
  | { type: 'restoreRide'; patient: string; appointmentId: string; appointmentDate: number; destination: string; fare: number }
  | { type: 'selectRecipe'; id: string }
  | { type: 'login' | 'advance' | 'pause' | 'resume' | 'interrupt' | 'retry' | 'stop' | 'approve' | 'collapse' | 'changeFare' | 'reset' };
export const demoScenarios: Record<DemoScenario, { title: string; page: string; steps: string[] }> = {
  labs: { title: 'Check my latest labs', page: 'MyChart / Test results', steps: ['Opening your test results', 'Comparing the result with your history', 'Adding a question to your discussion guide'] },
  visit: { title: 'Prepare for my visit', page: 'MyChart / Messages', steps: ['Opening your visit details', 'Gathering your questions and observations', 'Drafting a message for your care team'] },
  recipe: { title: 'Find a saved recipe', page: 'Instagram / Saved', steps: ['Reading 36 saved recipe posts', 'Checking ingredients against your preferences', 'Opening the recipe and extracting its method', 'Creating your Rumi meal card and day plan'] },
  ride: { title: 'Arrange a ride', page: 'Uber / Reserve', steps: ['Reading your appointment and arrival instructions', 'Checking route and pickup buffer', 'Comparing rides and preparing the booking'] },
  activity: { title: 'Find an activity for me', page: 'Instagram / Saved activity', steps: ['Opening saved movement ideas', 'Checking intensity and available time', 'Adding a gentle activity to your plan'] },
};
export const initialBrowserDemo: BrowserDemoState = { scenario: null, phase: 'idle', step: 0, collapsed: false, patient: '', detail: '', receipt: null, fare: 24, messages: [], run: 0, selectedRecipeId: 'saved-0', recipeIds: ['saved-0'], preferences: defaultMealPreferences, planWeek: false, appointmentId: '', appointmentDate: 0, destination: '', rideAction: 'book', pickupOffset: 45 };
export const canStopDemo = (phase: DemoPhase): boolean => ['login', 'browsing', 'paused', 'review', 'failed'].includes(phase);
function say(state: BrowserDemoState, text: string): BrowserDemoState { return { ...state, messages: [...state.messages, { role: 'rumi' as const, text }].slice(-40) }; }
function finish(state: BrowserDemoState): BrowserDemoState {
  const receipt = `Task summary · ${state.scenario ? demoScenarios[state.scenario].title : ''}\n${state.detail}\nCompleted in the sample workspace; no external action taken.`;
  return say({ ...state, phase: 'done', receipt }, receipt);
}
function recipeProposal(state: BrowserDemoState): BrowserDemoState {
  const matches = curateRecipes(state.preferences);
  const preferred = matches.find(r => r.id === state.selectedRecipeId) ?? matches[0];
  if (!preferred) return say({ ...state, phase: 'failed' }, 'No saved post matches these filters. Adjust your preferences; I will not relax restrictions silently.');
  const choices = state.planWeek ? [preferred, ...matches.filter(r => r.id !== preferred.id)].slice(0, 7) : [preferred];
  return { ...state, selectedRecipeId: preferred.id, recipeIds: choices.map(r => r.id), detail: `${preferred.title} · @${preferred.author}\n${recipeInsight(preferred, state.preferences)}\n${state.planWeek ? `${choices.length} meals for the coming week` : 'Today’s dinner'} in your local plan. Source photo retained alongside a prepared Rumi illustration; no live image generation is implied.` };
}
/** Autonomous offline runner: reading/drafting complete without permission; submissions still require approval. */
export function browserDemoReducer(state: BrowserDemoState, event: BrowserDemoEvent): BrowserDemoState {
  switch (event.type) {
    case 'start': {
      if (canStopDemo(state.phase)) return state;
      let next: BrowserDemoState = { ...initialBrowserDemo, run: state.run + 1, scenario: event.scenario, patient: event.patient, detail: event.detail, phase: 'login', preferences: event.preferences ?? defaultMealPreferences, appointmentId: event.appointmentId ?? '', appointmentDate: event.appointmentDate ?? 0, destination: event.destination ?? '' };
      if (event.scenario === 'recipe') next = recipeProposal(next);
      return say(next, 'I’ll use the fixed sample sign-in and handle the steps. You can minimize the browser, ask questions or add a goal. I’ll stop for any external-action proposal.');
    }
    case 'login': return state.phase === 'login' ? say({ ...state, phase: 'browsing' }, state.scenario ? demoScenarios[state.scenario].steps[0] : '') : state;
    case 'advance': {
      if (state.phase !== 'browsing' || !state.scenario) return state;
      if (state.step < demoScenarios[state.scenario].steps.length - 1) return say({ ...state, step: state.step + 1 }, demoScenarios[state.scenario].steps[state.step + 1]);
      return state.scenario === 'ride' || state.scenario === 'visit' ? say({ ...state, phase: 'review' }, `I’ve prepared this exact proposal. Please review before I ${state.scenario === 'visit' ? 'send' : state.rideAction}.\n${state.detail}`) : finish(state);
    }
    case 'followup': {
      const text = event.text.trim().slice(0, 2000);
      if (!text || !state.scenario) return state;
      let next: BrowserDemoState = { ...state, messages: [...state.messages, { role: 'you' as const, text }].slice(-40) };
      const command = text.toLowerCase();
      if (/^(stop|cancel|decline)$/.test(command)) return say(browserDemoReducer(next, { type: 'stop' }), 'Stopped this task. Existing saved plans or previously approved sample rides remain unchanged.');
      if (command === 'pause' || command === 'resume') return say(browserDemoReducer(next, { type: command }), command === 'pause' ? 'Paused; nothing advances.' : 'I’m continuing autonomously.');
      if (/^(continue|next|show next step)$/.test(command)) return say(next, 'I’m handling the steps automatically. You don’t need to click through.');
      if (state.scenario === 'recipe' && /week|plan|protein|dairy|gluten|nut.free|vegetarian|vegan|quick|15 minute|today|dinner/.test(command) && !/approve|pay|send/.test(command)) {
        const preferences = { ...state.preferences, dairyFree: state.preferences.dairyFree || /dairy.free|vegan/.test(command), glutenFree: state.preferences.glutenFree || /gluten.free/.test(command), nutFree: state.preferences.nutFree || /nut.free/.test(command), vegetarian: state.preferences.vegetarian || /vegetarian|vegan/.test(command), highProtein: state.preferences.highProtein || /protein/.test(command), maxMinutes: /15|quick/.test(command) ? 15 : state.preferences.maxMinutes };
        next = recipeProposal({ ...next, preferences, selectedRecipeId: /protein/.test(command) ? '' : state.selectedRecipeId, planWeek: /week/.test(command) || state.planWeek, phase: 'browsing', step: 1, receipt: null, run: state.run + 1 });
        return say(next, `I’ll re-curate the saved posts for that goal and update the local meal plan. ${next.detail}`);
      }
      if ((state.scenario === 'labs' || state.scenario === 'visit') && /^(add|include|ask about|also ask|tell them)\b/.test(command) && !/approve|pay/.test(command)) {
        return say({ ...next, detail: `${state.detail}\nAdditional question from you: ${text}`, phase: 'browsing', step: 1, receipt: null, run: state.run + 1 }, state.scenario === 'visit' ? 'I’ll include that in the draft and ask you to review the revised message before sending.' : 'I’ll add that to your local discussion guide. No medication or diagnosis change is made.');
      }
      if (/send|book|approve|pay/.test(command)) return say(next, 'Use the approval card to review the exact proposal. Chat never authorizes a submission.');
      if (/explain|what|which|where|summary|detail|why|ingredient/.test(command)) return say(next, `From this sample task: ${state.detail}`);
      return say(next, 'I can explain this task, pause or stop it, include a question in a portal draft or discussion guide (start with “Include”), or re-curate recipes for “this week”, “high protein”, “dairy-free”, “gluten-free”, “nut-free” or “under 15 minutes”. Other goals need a connected agent; this sample does not claim to execute them.');
    }
    case 'selectRecipe': {
      if (state.scenario !== 'recipe' || state.phase === 'stopped') return state;
      if (!savedRecipes.some(r => r.id === event.id)) return state;
      return say(recipeProposal({ ...state, selectedRecipeId: event.id, phase: 'browsing', step: 2, receipt: null, run: state.run + 1 }), 'I’ll open this post, check its ingredients and add it only if it matches your filters.');
    }
    case 'appointmentChanged': return state.phase === 'review' && state.scenario === 'ride' ? say({ ...state, phase: 'browsing', step: 2, appointmentDate: event.date, destination: event.destination, detail: event.detail }, 'The appointment changed before approval. I’ve withdrawn the old proposal and need fresh permission.') : state;
    case 'restoreRide': return canStopDemo(state.phase) ? state : { ...initialBrowserDemo, phase: 'done', scenario: 'ride', run: state.run + 1, patient: event.patient, appointmentId: event.appointmentId, appointmentDate: event.appointmentDate, destination: event.destination, fare: event.fare };
    case 'rideUpdate': {
      if (state.scenario !== 'ride' || state.phase !== 'done') return state;
      return say({ ...state, phase: 'browsing', step: 0, receipt: null, run: state.run + 1, rideAction: event.update === 'cancel' ? 'cancel' : 'rebook', fare: event.update === 'cancel' ? 0 : 29, pickupOffset: event.update === 'late' ? 60 : 45, appointmentDate: event.appointmentDate ?? state.appointmentDate, detail: event.detail }, `Sample update detected. ${event.detail} I’ll prepare options, but won’t cancel or rebook without your approval.`);
    }
    case 'pause': return state.phase === 'browsing' ? { ...state, phase: 'paused' } : state;
    case 'resume': return state.phase === 'paused' ? { ...state, phase: 'browsing' } : state;
    case 'interrupt': return state.phase === 'browsing' ? { ...state, phase: 'failed' } : state;
    case 'retry': return state.phase === 'failed' ? { ...state, phase: 'login', step: 0, run: state.run + 1 } : state;
    case 'stop': return canStopDemo(state.phase) ? { ...state, phase: 'stopped', receipt: null } : state;
    case 'approve': return state.phase === 'review' && (state.scenario === 'ride' || state.scenario === 'visit') ? finish(state) : state;
    case 'collapse': return { ...state, collapsed: !state.collapsed };
    case 'changeFare': return state.phase === 'review' && state.scenario === 'ride' ? say({ ...state, fare: state.fare + 5, detail: state.detail.replace(`$${state.fare}`, `$${state.fare + 5}`), phase: 'browsing' }, 'The fare changed. I’ll show a new proposal; previous permission never carries over.') : state;
    case 'reset': return { ...initialBrowserDemo, run: state.run + 1 };
  }
}
export function demoActivity(state: BrowserDemoState): string {
  switch (state.phase) {
    case 'idle': return 'Choose something you would like Rumi to help with.';
    case 'login': return 'Opening the fixed sample account automatically…';
    case 'browsing': return state.scenario ? demoScenarios[state.scenario].steps[state.step] : '';
    case 'paused': return 'Nothing advances while paused. Resume when you’re ready.';
    case 'review': return 'Ready for your review. Nothing happens until you approve.';
    case 'done': return 'Your task summary is ready to review.';
    case 'stopped': return 'Stopped. No pending action was taken; existing saved work remains unchanged.';
    case 'failed': return 'The session was interrupted or no match was found. No external action was taken.';
  }
}
