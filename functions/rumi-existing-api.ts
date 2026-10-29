/** Adapter for the supplied rumi_api service. No provider secrets or webchat links reach clients. */
export interface ExistingAPIEnv {
  RUMI_API_ORIGIN?: string;
  /** Server-provisioned subject -> existing signed webchat token, after ownership verification. */
  RUMI_API_CHAT_LINKS?: string;
  RUMI_API_INIT_SECRET?: string;
}
export const usesExistingAPI = (env: ExistingAPIEnv): boolean => !!env.RUMI_API_ORIGIN;

function origin(env: ExistingAPIEnv): string {
  try {
    const url = new URL(env.RUMI_API_ORIGIN || "");
    if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash || (url.pathname !== "/" && url.pathname !== "")) throw new Error();
    // Fixed operator-owned origin only; never accept an upstream URL from a request.
    return url.origin;
  } catch { throw new Error("The existing Rumi API needs a valid HTTPS service origin."); }
}
function accountToken(env: ExistingAPIEnv, subject: string): string {
  let token: unknown;
  try { token = JSON.parse(env.RUMI_API_CHAT_LINKS || "{}")[subject]; } catch { /* fail closed */ }
  if (typeof token !== "string" || !/^\d{8,15}\.\d{1,12}\.[a-f0-9]{32}$/.test(token)) throw new Error("This account needs its verified private Rumi chat link provisioned on the server.");
  if (Number(token.split(".")[1]) <= Date.now() / 1000) throw new Error("Your private Rumi chat link expired. Request a fresh link from your existing Rumi conversation.");
  return token;
}
export function existingAccountReady(env: ExistingAPIEnv, subject: string): boolean {
  try { origin(env); accountToken(env, subject); return true; } catch { return false; }
}
export function existingAccountNumber(env: ExistingAPIEnv, subject: string): string {
  return `+${accountToken(env, subject).split(".")[0]}`;
}
export async function existingChat(env: ExistingAPIEnv, subject: string, text: string): Promise<string> {
  const base = origin(env), token = accountToken(env, subject);
  if (!text.trim() || text.length > 2000) throw new Error("The existing Rumi service accepts messages up to 2,000 characters.");
  let response: Response;
  try {
    response = await fetch(`${base}/chat/${token}/send`, { method: "POST", redirect: "error", headers: { "Content-Type": "application/json", "Accept": "application/json" }, body: JSON.stringify({ text }), signal: AbortSignal.timeout(125000) });
  } catch { throw new Error("The existing Rumi service did not confirm a reply. It may have received your message; this request will not be resent automatically."); }
  if (response.status === 410 || response.status === 404) throw new Error("Your private Rumi chat link is unavailable or expired. Request a fresh link from your existing conversation.");
  if (response.status === 409) throw new Error("Start your existing Rumi conversation by text before continuing here.");
  if (response.status === 429) throw new Error("Rumi is already replying in another channel. Wait before sending a new message.");
  if (!response.ok) throw new Error("The existing Rumi service could not confirm a reply. Check that conversation before sending again.");
  try {
    const data = await response.json() as { replies?: unknown };
    if (!Array.isArray(data.replies) || !data.replies.length || data.replies.length > 50 || !data.replies.every((part: unknown) => typeof part === "string" && part.length <= 20000)) throw new Error();
    const reply = data.replies.join("\n\n");
    if (!reply.trim() || reply.length > 50000) throw new Error();
    return reply;
  } catch { throw new Error("Rumi may have replied, but the response could not be read. This request will not be resent automatically."); }
}
/** Existing API mints its own proof; never duplicate ELEVEN_LLM_SECRET in this service or on the phone. */
export async function existingCallData(env: ExistingAPIEnv, subject: string, number: string): Promise<Record<string, unknown>> {
  const base = origin(env), token = accountToken(env, subject);
  const phone = `+${token.split(".")[0]}`;
  if (phone !== number) throw new Error("Shared-memory calls can only ring this account’s verified Rumi number.");
  if (!env.RUMI_API_INIT_SECRET) throw new Error("The existing Rumi call initiation connection needs setup.");
  const response = await fetch(`${base}/eleven/initiation`, { method: "POST", redirect: "error", headers: { "Content-Type": "application/json", "X-Rumi-Secret": env.RUMI_API_INIT_SECRET }, body: JSON.stringify({ caller_id: phone }), signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw new Error("The existing Rumi service could not authorize this call.");
  const data = await response.json() as { user_id?: unknown; custom_llm_extra_body?: { person_id?: unknown; proof?: unknown } };
  const extra = data.custom_llm_extra_body;
  if (data.user_id !== phone || extra?.person_id !== phone || typeof extra.proof !== "string" || !/^[a-f0-9]{64}$/.test(extra.proof)) throw new Error("The existing Rumi service returned invalid call authorization.");
  return { user_id: phone, custom_llm_extra_body: { person_id: phone, proof: extra.proof, reason: "call_me" } };
}
