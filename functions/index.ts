import { handleAI, modelStatus } from "./rumi-ai";
import { handleCompanion, type CompanionEnv } from "./rumi-companion";
export { RumiCompanionHub } from "./rumi-companion";
export { RumiBudget } from "./rumi-ai";

interface Env extends CompanionEnv {
  ELEVENLABS_API_KEY?: string;
}

const ELEVENLABS_ORIGIN = "https://api.elevenlabs.io";
const RUMI_VOICE_ID = "L0yTtpRXzdyzQlzALhgD";

const corsHeaders: HeadersInit = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Rumi-Device",
};

function cors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) headers.set(key, value);
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

function json(data: unknown, init: ResponseInit = {}): Response {
  return cors(Response.json(data, { ...init, headers: { ...init.headers, ...corsHeaders } }));
}

function requireElevenLabsKey(env: Env): string | Response {
  const key = env.ELEVENLABS_API_KEY?.trim();
  if (!key) {
    return json({ ok: false, error: "ElevenLabs is not configured." }, { status: 503 });
  }
  return key;
}

async function proxySpeechToText(request: Request, env: Env): Promise<Response> {
  const key = requireElevenLabsKey(env);
  if (typeof key !== "string") return key;

  const upstream = await fetch(`${ELEVENLABS_ORIGIN}/v1/speech-to-text`, {
    method: "POST",
    headers: { "xi-api-key": key },
    body: request.body,
  });

  const headers = new Headers(upstream.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.delete("set-cookie");
  return new Response(upstream.body, { status: upstream.status, statusText: upstream.statusText, headers });
}

async function proxyTextToSpeech(request: Request, env: Env): Promise<Response> {
  const key = requireElevenLabsKey(env);
  if (typeof key !== "string") return key;

  let body: { text?: string; model_id?: string; voice_settings?: unknown } = {};
  try {
    body = await request.json();
  } catch {
    return json({ ok: false, error: "Expected JSON body." }, { status: 400 });
  }

  const text = body.text?.trim();
  if (!text) return json({ ok: false, error: "Text is required." }, { status: 400 });

  const upstream = await fetch(`${ELEVENLABS_ORIGIN}/v1/text-to-speech/${RUMI_VOICE_ID}?output_format=mp3_44100_128`, {
    method: "POST",
    headers: {
      "xi-api-key": key,
      "Content-Type": "application/json",
      Accept: "audio/mpeg",
    },
    body: JSON.stringify({
      text,
      // Turbo v2.5 keeps live spoken turns low-latency while holding the
      // project's custom voice; callers may still override per request.
      model_id: body.model_id ?? "eleven_turbo_v2_5",
      voice_settings: body.voice_settings ?? {
        stability: 0.48,
        similarity_boost: 0.82,
        style: 0.2,
        use_speaker_boost: true,
      },
    }),
  });

  const headers = new Headers(upstream.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.delete("set-cookie");
  return new Response(upstream.body, { status: upstream.status, statusText: upstream.statusText, headers });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });

    if (url.pathname.startsWith("/companion/")) return cors(await handleCompanion(request, env));

    if (url.pathname === "/ai/status" && request.method === "GET") return cors(await modelStatus(env));
    if (url.pathname === "/ai/chat" && request.method === "POST") return cors(await handleAI(request, env));

    if (url.pathname === "/ping") {
      return json({ ok: true, now: new Date().toISOString() });
    }

    if (url.pathname === "/voice/stt" && request.method === "POST") {
      return proxySpeechToText(request, env);
    }

    if (url.pathname === "/voice/tts" && request.method === "POST") {
      return proxyTextToSpeech(request, env);
    }

    return json({ ok: false, error: "Not found" }, { status: 404 });
  },
};
