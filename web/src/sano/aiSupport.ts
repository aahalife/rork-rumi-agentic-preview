export interface SupportObservation { title: string; body: string; evidenceIds: string[] }

/** Reject unsupported provenance and oversized output before creating a visible insight. */
export function validateObservation(raw: string, evidenceIds: string[]): SupportObservation | null {
  try {
    const v = JSON.parse(raw.replace(/^```(?:json)?\s*|\s*```$/g, ''));
    if (v.skip || typeof v.title !== 'string' || typeof v.body !== 'string' || v.title.length > 120 || v.body.length > 900 || !Array.isArray(v.evidenceIds) || !v.evidenceIds.length || !v.evidenceIds.every((id: unknown) => typeof id === 'string' && evidenceIds.includes(id))) return null;
    return { title: v.title, body: v.body, evidenceIds: v.evidenceIds };
  } catch { return null; }
}

export function isQuietHour(hour: number, start: number, end: number): boolean {
  return start === end || (start < end ? hour >= start && hour < end : hour >= start || hour < end);
}

/** A new coaching agenda is never scheduled while the person may need emotional or urgent support. */
export function shouldSuppressCoaching(text: string): boolean {
  return /\b(suicid|kill myself|end my life|hurt myself|hopeless|scared|overwhelmed|devastated|bad news|can't cope|chest pain|can't breathe|cannot breathe|grief|died)\b/i.test(text);
}
