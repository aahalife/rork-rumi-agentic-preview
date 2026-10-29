// Offline codec bridge only: never receives authentication or opens a network connection.
// Swift owns audio, authenticated transport, consent and lifecycle.
import { gateway } from '@ai-sdk/gateway';
import type { Experimental_RealtimeClientEvent } from 'ai';
const model = gateway.experimental_realtime('openai/gpt-realtime-2');
export async function encode(event: string): Promise<string> {
  return JSON.stringify(await model.serializeClientEvent(JSON.parse(event) as Experimental_RealtimeClientEvent));
}
export function decode(event: string): string {
  const parsed = model.parseServerEvent(JSON.parse(event));
  return JSON.stringify(Array.isArray(parsed) ? parsed : [parsed]);
}
