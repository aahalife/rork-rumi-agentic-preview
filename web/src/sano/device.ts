import type { ConversationTurn, MemoryItem, Pathway } from './types';

const DEVICE_KEY = 'rumi.device.v1';
const PROFILE_PREFIX = 'rumi.profile.v1.';
let cached: string | null = null;

function randomId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  return Array.from({ length: 32 }, () => Math.floor(Math.random() * 16).toString(16)).join('');
}

/** Random per-browser install ID. It never contains personal data and is only used to
 *  separate this visitor's memory and rate limits from other people using the same demo profile. */
export function deviceId(): string {
  try {
    const saved = localStorage.getItem(DEVICE_KEY);
    if (saved && /^[A-Za-z0-9-]{20,64}$/.test(saved)) { cached = saved; return saved; }
    const fresh = randomId();
    localStorage.setItem(DEVICE_KEY, fresh);
    cached = fresh;
    return fresh;
  } catch {
    // Storage blocked (private mode): keep one ID for this page session.
    cached = cached ?? randomId();
    return cached;
  }
}

/** What Rumi keeps for one sample profile on one device. */
export interface ProfileMemory { memory?: MemoryItem[]; turns?: ConversationTurn[] }

const profileKey = (pathway: Pathway) => `${PROFILE_PREFIX}${deviceId()}.${pathway}`;

export function loadProfileMemory(pathway: Pathway): ProfileMemory | null {
  try { const raw = localStorage.getItem(profileKey(pathway)); return raw ? JSON.parse(raw) as ProfileMemory : null; } catch { return null; }
}

export function saveProfileMemory(pathway: Pathway, data: ProfileMemory): void {
  try { localStorage.setItem(profileKey(pathway), JSON.stringify(data)); } catch { /* storage full or blocked */ }
}

export function clearProfileMemory(pathway?: Pathway): void {
  try {
    if (pathway) { localStorage.removeItem(profileKey(pathway)); return; }
    Object.keys(localStorage).filter(k => k.startsWith(PROFILE_PREFIX)).forEach(k => localStorage.removeItem(k));
    localStorage.removeItem(DEVICE_KEY);
    cached = null;
  } catch { /* ignore */ }
}

/** Only finished, real replies are worth restoring. */
export function restorableTurns(turns: ConversationTurn[]): ConversationTurn[] {
  return turns.filter(t => !t.streaming && t.text.trim() && !t.text.startsWith('Live AI unavailable')).slice(-40).map(t => ({ ...t, streaming: false }));
}
