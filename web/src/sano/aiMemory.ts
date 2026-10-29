import type { ConversationTurn, MemoryItem } from './types';

/** Only user evidence, never the companion's guesses, may support a memory candidate. */
export function validatedClaims(raw: string, turns: ConversationTurn[], now = Date.now()): MemoryItem[] {
  let data: unknown;
  try { data = JSON.parse(raw.replace(/^```(?:json)?\s*|\s*```$/g, '')); } catch { return []; }
  const claims = (data as { claims?: unknown[] })?.claims;
  if (!Array.isArray(claims)) return [];
  return claims.slice(0, 3).flatMap(value => {
    if (!value || typeof value !== 'object') return [];
    const c = value as Record<string, unknown>;
    if (typeof c.text !== 'string' || c.text.length > 300 || typeof c.quote !== 'string' || c.quote.length < 8 || typeof c.confidence !== 'number' || !Number.isFinite(c.confidence) || !['fact', 'hypothesis'].includes(String(c.kind))) return [];
    const evidence = turns.find(t => t.role === 'user' && t.text.includes(c.quote as string));
    if (!evidence) return [];
    return [{ id: crypto.randomUUID(), text: c.text, learnedFrom: 'Your conversation · awaiting your confirmation', quote: c.quote, evidenceId: evidence.id, at: now, confidence: Math.min(Math.max(c.confidence, 0), c.kind === 'hypothesis' ? 0.3 : 0.8), claimKind: c.kind as 'fact' | 'hypothesis', confirmed: false }];
  });
}

/** Unsupported/stale candidates never become personal facts in an AI prompt. */
export function usableMemory(items: MemoryItem[], now = Date.now()): MemoryItem[] {
  return items.filter(m => m.confirmed !== false && (!m.at || now - m.at < 45 * 86400000));
}
