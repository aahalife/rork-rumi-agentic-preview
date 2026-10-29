import type { RichElement, ConversationTurn } from "./types";
import { deviceId } from "./device";

const TOOLKIT_URL = (import.meta.env.EXPO_PUBLIC_TOOLKIT_URL as string) || "https://toolkit.rork.com";
const TOOLKIT_KEY = (import.meta.env.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY as string) || "";
const MODEL = "claude-sonnet-5-5";
const FUNCTIONS_URL = "/~api";

export interface AIOptions { consent: boolean; purpose?: string }

export interface ChatMessage { role: "user" | "assistant"; content: string }

/** Stream a completion token-by-token. Calls onDelta with visible chunks and
 *  resolves with the full raw text (tags included). Throws on network failure
 *  without disguising scripted sample text as a live reply. */
export async function streamChat(
  system: string,
  messages: ChatMessage[],
  onDelta: (delta: string) => void,
  signal?: AbortSignal,
  options?: AIOptions,
): Promise<string> {
  if (!options?.consent) throw new Error("Rumi AI is turned off. You can turn it back on in Settings.");
  const res = await fetch(`${FUNCTIONS_URL}/ai/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Rumi-Device": deviceId(),
    },
    body: JSON.stringify({
      consent: true,
      context: system,
      purpose: options.purpose ?? "conversation",
      messages: messages.filter(m => m.content.trim()).slice(-14),
    }),
    signal,
  });
  if (!res.ok || !res.body) {
    const data = await res.json().catch(() => null);
    throw new Error(data?.error ?? "Rumi’s live AI is unavailable. Please try again.");
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let raw = "";
  let buffer = "";
  let completed = false;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      const t = line.trim();
      if (!t.startsWith("data:")) continue;
      const payload = t.slice(5).trim();
      if (payload === "[DONE]") { completed = true; continue; }
      let json;
      try { json = JSON.parse(payload); } catch { continue; }
      if (json.error) throw new Error("The reply was interrupted. Please try again.");
      {
        const delta: string = json?.choices?.[0]?.delta?.content ?? "";
        if (delta) { raw += delta; onDelta(delta); }
      }
    }
  }
  if (!completed || !raw.trim()) throw new Error("The reply was interrupted. Please try again.");
  return raw;
}

/** Strip `[[kind:payload]]` tags; returns clean text + the first rich element. */
export function parseTags(input: string): { text: string; rich: RichElement } {
  let text = input;
  let rich: RichElement = { t: "none" };
  for (;;) {
    const open = text.indexOf("[[");
    if (open < 0) break;
    const close = text.indexOf("]]", open + 2);
    if (close < 0) break;
    const inner = text.slice(open + 2, close);
    text = text.slice(0, open) + text.slice(close + 2);
    if (rich.t !== "none") continue;
    const ci = inner.indexOf(":");
    const kind = (ci < 0 ? inner : inner.slice(0, ci)).trim().toLowerCase();
    const payload = ci < 0 ? "" : inner.slice(ci + 1).trim();
    const parts = payload.split("|").map((p) => p.trim());
    switch (kind) {
      case "trend": rich = { t: "trend", id: payload.toLowerCase() }; break;
      case "habit": rich = { t: "habitProposal", title: parts[0] || payload, context: parts[1] || "whenever today allows" }; break;
      case "guide": rich = { t: "guideAdd", question: payload }; break;
      case "action": break;
      case "program": break;
    }
  }
  return { text: text.trim(), rich };
}

/** As tokens arrive we withhold anything inside [[...]] from the visible stream. */
export function makeHoldbackFilter() {
  let holdback = "";
  return (delta: string): string => {
    holdback += delta;
    let visible = "";
    for (;;) {
      const open = holdback.indexOf("[[");
      if (open >= 0) {
        visible += holdback.slice(0, open);
        const close = holdback.indexOf("]]", open + 2);
        if (close >= 0) {
          holdback = holdback.slice(close + 2);
        } else {
          holdback = holdback.slice(open);
          return visible;
        }
      } else if (holdback.endsWith("[")) {
        visible += holdback.slice(0, -1);
        holdback = "[";
        return visible;
      } else {
        visible += holdback;
        holdback = "";
        return visible;
      }
    }
  };
}

export const newTurn = (role: "user" | "companion", text: string, streaming = false): ConversationTurn => ({
  id: `turn_${Math.random().toString(36).slice(2)}`,
  role, text, rich: { t: "none" }, richResolved: false, streaming,
});

export const HAS_KEY = TOOLKIT_KEY.length > 0;
export { TOOLKIT_URL, TOOLKIT_KEY, MODEL, FUNCTIONS_URL };
