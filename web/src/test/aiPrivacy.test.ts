import { afterEach, describe, expect, it, vi } from 'vitest';
import { newTurn, parseTags, streamChat } from '../sano/ai';
import { usableMemory, validatedClaims } from '../sano/aiMemory';
import { isQuietHour, shouldSuppressCoaching, validateObservation } from '../sano/aiSupport';

afterEach(() => vi.unstubAllGlobals());

describe('consented live AI', () => {
  it('never sends data once AI is turned off', async () => {
    const fetch = vi.fn(); vi.stubGlobal('fetch', fetch);
    await expect(streamChat('private context', [{ role: 'user', content: 'Hi' }], () => {})).rejects.toThrow('turned off');
    await expect(streamChat('private context', [{ role: 'user', content: 'Hi' }], () => {}, undefined, { consent: false })).rejects.toThrow('turned off');
    expect(fetch).not.toHaveBeenCalled();
  });
  it('identifies the device with a random install ID and no access code', async () => {
    const encoder = new TextEncoder();
    const fetch = vi.fn(async (_url: string, _init: RequestInit) => new Response(new ReadableStream({ start(c) { c.enqueue(encoder.encode('data: {"choices":[{"delta":{"content":"Hi"}}]}\n\ndata: [DONE]\n\n')); c.close(); } })));
    vi.stubGlobal('fetch', fetch);
    await streamChat('ctx', [{ role: 'user', content: 'Hi' }], () => {}, undefined, { consent: true });
    const headers = fetch.mock.calls[0][1].headers as Record<string, string>;
    expect(headers['X-Rumi-Device']).toMatch(/^[A-Za-z0-9-]{20,64}$/);
    expect(headers['X-Rumi-Device']).toBe(localStorage.getItem('rumi.device.v1'));
    expect(headers.Authorization).toBeUndefined();
  });
  it('reads fragmented text-only SSE and never substitutes a model', async () => {
    const encoder = new TextEncoder();
    const fetch = vi.fn(async () => new Response(new ReadableStream({ start(c) { c.enqueue(encoder.encode('data: {"choices":[{"delta":{"con')); c.enqueue(encoder.encode('tent":"Hello"}}]}\n\ndata: [DONE]\n\n')); c.close(); } })));
    vi.stubGlobal('fetch', fetch);
    const delta = vi.fn();
    expect(await streamChat('sample context', [{ role: 'user', content: 'Latest message' }], delta, undefined, { consent: true })).toBe('Hello');
    expect(delta).toHaveBeenCalledWith('Hello');
    expect(fetch).toHaveBeenCalledWith('/~api/ai/chat', expect.objectContaining({ method: 'POST' }));
  });
  it('rejects interrupted streams rather than returning partial success', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('data: {"choices":[{"delta":{"content":"Partial"}}]}\n\n')));
    await expect(streamChat('', [{ role: 'user', content: 'Hi' }], () => {}, undefined, { consent: true })).rejects.toThrow('interrupted');
  });
  it('model tags cannot create refill, booking or sponsored action cards', () => {
    for (const tag of ['refill:Drug|Ready at pharmacy', 'action:Book|Pay', 'program:Sponsor']) expect(parseTags(`Text [[${tag}]]`).rich).toEqual({ t: 'none' });
  });
});

describe('memory provenance and gentle governance', () => {
  it('rejects invented evidence and companion-only quotes', () => {
    const raw = JSON.stringify({ claims: [{ text: 'A preference', quote: 'I like evenings', confidence: 0.9, kind: 'fact' }] });
    expect(validatedClaims(raw, [newTurn('companion', 'I like evenings')])).toEqual([]);
    expect(validatedClaims(raw, [newTurn('user', 'I like mornings')])).toEqual([]);
  });
  it('requires confirmation and caps hypotheses, not all facts, at 0.3', () => {
    const turns = [newTurn('user', 'I like evenings after work')];
    const raw = JSON.stringify({ claims: [{ text: 'Prefers evenings', quote: 'I like evenings', confidence: 0.95, kind: 'hypothesis' }] });
    const claims = validatedClaims(raw, turns, 100);
    expect(claims[0].confidence).toBe(0.3); expect(claims[0].confirmed).toBe(false);
    expect(usableMemory(claims, 100)).toEqual([]);
    expect(usableMemory([{ ...claims[0], confirmed: true }], 100)).toHaveLength(1);
    expect(usableMemory([{ ...claims[0], confirmed: true }], 46 * 86400000)).toHaveLength(0);
  });
  it('rejects insights without available evidence IDs', () => {
    expect(validateObservation('{"title":"Observation","body":"Something","evidenceIds":["invented"]}', ['actual'])).toBeNull();
    expect(validateObservation('{"skip":true}', ['actual'])).toBeNull();
  });
  it('respects quiet hours and distress rather than pushing a habit agenda', () => {
    expect(isQuietHour(23, 21, 8)).toBe(true); expect(isQuietHour(7, 21, 8)).toBe(true); expect(isQuietHour(12, 21, 8)).toBe(false);
    expect(shouldSuppressCoaching('I am overwhelmed and scared')).toBe(true);
    expect(shouldSuppressCoaching('I prefer a short walk')).toBe(false);
  });
});
