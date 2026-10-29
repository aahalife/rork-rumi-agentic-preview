import { useEffect, useRef, useState } from 'react';
import { ShieldCheck, ArrowRight, LogOut, CheckCircle2 } from 'lucide-react';

const base = 'https://egoicdonmuudwvbsockm.supabase.co/functions/v1/rumi-app-api';
const appId = '50594005-ee06-4087-abdf-733596f001e6';
interface Session { user_id: string; session_id: string; access_token: string; refresh_token: string; expires_at: string }
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
interface Challenge { challenge_id: string; status: string; expires_in?: number; messaging_number?: string }
interface Memory { memory_consent?: string; items?: { id: string; body?: { text?: string }; kind?: string }[] }
const resources = ['me', 'context', 'records', 'goals', 'actions', 'visit-questions', 'call-preferences', 'connections', 'messaging/status', 'conversations'];

export default function Account({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [session, setSession] = useState<Session | null>(null);
  const current = useRef<Session | null>(null);
  const refresh = useRef<Promise<Session> | null>(null);
  const epoch = useRef(0);
  const requests = useRef(new Set<AbortController>());
  const [phone, setPhone] = useState(''); const [code, setCode] = useState('');
  const [challenge, setChallenge] = useState<Challenge | null>(null);
  const [notice, setNotice] = useState(''); const [busy, setBusy] = useState(false);
  const [memory, setMemory] = useState<Memory | null>(null);
  const [resource, setResource] = useState('me'); const [result, setResult] = useState('');
  const [goal, setGoal] = useState(''); const [review, setReview] = useState<{ id: string; text: string } | null>(null); const [uncertain, setUncertain] = useState(false);
  useEffect(() => () => { epoch.current++; requests.current.forEach(r => r.abort()); current.current = null; }, []);
  useEffect(() => { if (!open) { epoch.current++; requests.current.forEach(r => r.abort()); requests.current.clear(); current.current = null; refresh.current = null; setSession(null); setMemory(null); setChallenge(null); setCode(''); setPhone(''); setResult(''); setGoal(''); setReview(null); setUncertain(false); setNotice(''); setBusy(false); } }, [open]);
  async function request<T>(path: string, method = 'GET', body?: object, token?: string, id?: string): Promise<T> {
    const version = epoch.current; const controller = new AbortController(); requests.current.add(controller);
    const timeout = setTimeout(() => controller.abort(), 30000);
    try {
      const response = await fetch(`${base}/${path}`, { method, signal: controller.signal, credentials: 'omit', redirect: 'error', cache: 'no-store', headers: { 'x-rumi-app-id': appId, Accept: 'application/json', ...(body ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(id ? { 'Idempotency-Key': id } : {}) }, body: body ? JSON.stringify(body) : undefined });
      if (epoch.current !== version) throw new Error('Account view changed; response discarded.');
      if (!response.ok) throw new Error(response.status === 401 ? 'Session unavailable or expired. Verify your account again.' : `Rumi could not complete this request (HTTP ${response.status}). Browser access also requires the service to allow this website’s origin.`);
      const text = await response.text(); if (text.length > 2000000) throw new Error('Response is too large to display safely.');
      if (epoch.current !== version) throw new Error('Account view changed; response discarded.');
      return JSON.parse(text) as T;
    } finally { clearTimeout(timeout); requests.current.delete(controller); }
  }
  function checkedChallenge(value: Challenge) { if (!uuid.test(value.challenge_id) || typeof value.status !== 'string') throw new Error('Invalid verification challenge returned.'); return value; }
  function accept(value: Session) {
    if (!uuid.test(value.user_id) || !uuid.test(value.session_id) || !/^[a-f0-9]{64}$/.test(value.access_token) || !/^[a-f0-9]{64}$/.test(value.refresh_token) || !Number.isFinite(Date.parse(value.expires_at))) throw new Error('Invalid session returned.');
    if (current.current && (current.current.user_id !== value.user_id || current.current.session_id !== value.session_id)) throw new Error('Refreshed session identity did not match. Verify your account again.');
    current.current = value; setSession(value); return value;
  }
  async function token() {
    const value = current.current; if (!value) throw new Error('Verify your existing Rumi account first.');
    if (Date.parse(value.expires_at) > Date.now() + 60000) return value.access_token;
    if (!refresh.current) refresh.current = request<Session>('v1/auth/refresh', 'POST', { refresh_token: value.refresh_token }).then(accept).finally(() => { refresh.current = null; });
    try { return (await refresh.current).access_token; } catch (error) { current.current = null; setSession(null); setMemory(null); setResult(''); setReview(null); setGoal(''); throw error; }
  }
  async function run(fn: () => Promise<void>) { if (busy) return; const version = epoch.current; setBusy(true); setNotice(''); try { await fn(); } catch (error) { if (version === epoch.current) setNotice(error instanceof Error ? error.message : 'The service could not be reached. Check connectivity and allowed browser origins.'); } finally { if (version === epoch.current) setBusy(false); } }
  if (!open) return null;
  return <div className="rw-account">
    <div className="rw-symbol"><ShieldCheck size={28} /></div><h2>Your Rumi, connected.</h2><p>Verify your existing Rumi account. This is separate from the fictional demo.</p>
    <div className="rw-note"><strong>Owner-confirmed service</strong><span className="rw-url">{base}</span><span>Public app ID · {appId}</span></div>
    <button className="rw-row" disabled={busy} onClick={() => void run(async () => { await request('health'); const config = await request<{ records_mode?: string }>('v1/config'); setNotice(`Health and configuration responded. Records mode: ${config.records_mode ?? 'not returned'}. This does not verify personal records.`); })}>Check service connection <ArrowRight size={18} /></button>
    {!session ? <form onSubmit={e => { e.preventDefault(); void run(async () => { if (!/^\+[1-9]\d{7,14}$/.test(phone)) throw new Error('Use an international phone number starting with +.'); setChallenge(checkedChallenge(await request<Challenge>('v1/auth/challenges', 'POST', { phone_number: phone }))); }); }}>
      <label>Phone number<input autoComplete="tel" type="tel" placeholder="+1 555 123 4567" value={phone} onChange={e => setPhone(e.target.value)} required /></label><p className="rw-small">Only request a code for an account you own or are authorized to test. This sends a real verification request.</p><button className="rw-primary" disabled={busy}>Request code in Rumi iMessage</button>
    </form> : <div className="rw-note"><CheckCircle2 size={18} /><strong>Verified session · This tab only</strong></div>}
    {challenge && !session && <div className="rw-card"><h3>{challenge.status.replace(/_/g, ' ')}</h3>{challenge.status === 'imessage_connection_needed' && <p>Send Hi in your existing Rumi thread{challenge.messaging_number ? ` at ${challenge.messaging_number}` : ''}, then resend this challenge before it expires.</p>}<p className="rw-small">{challenge.expires_in ? `${challenge.expires_in}-second expiry window. ` : ''}Resending does not extend the original expiry.</p><label>Six-digit code<input value={code} inputMode="numeric" autoComplete="one-time-code" maxLength={6} onChange={e => setCode(e.target.value)} /></label><div className="rw-actions"><button className="rw-primary" disabled={busy || !/^\d{6}$/.test(code)} onClick={() => void run(async () => { accept(await request<Session>(`v1/auth/challenges/${challenge.challenge_id}/verify`, 'POST', { code })); setCode(''); setPhone(''); setChallenge(null); })}>Verify code</button><button disabled={busy} onClick={() => void run(async () => setChallenge(checkedChallenge(await request<Challenge>(`v1/auth/challenges/${challenge.challenge_id}/send`, 'POST', {}))))}>Resend</button></div></div>}
    {session && <>
      <button className="rw-row" disabled={busy} onClick={() => void run(async () => setMemory(await request<Memory>('v1/memory', 'GET', undefined, await token())))}>Read shared memory <ArrowRight size={18} /></button>
      {memory && <div className="rw-card"><h3>Saved context</h3><p>Memory permission: {memory.memory_consent ?? 'not returned'}</p>{memory.items?.map(i => <p key={i.id}>{i.body?.text ?? 'Saved item'}</p>)}{memory.memory_consent === 'granted' && <><label>A goal you choose<textarea value={goal} maxLength={2000} onChange={e => setGoal(e.target.value)} /></label><button disabled={!goal.trim() || uncertain || busy} className="rw-primary" onClick={() => setReview({ id: crypto.randomUUID(), text: goal.trim() })}>Review exact goal</button></>}</div>}
      {review && <div className="rw-card rw-review"><h3>Save this exact goal to real Rumi?</h3><p>{review.text}</p><p className="rw-small">Real shared-memory write, not a demo receipt.</p><button className="rw-primary" disabled={busy} onClick={() => { const item = review; setReview(null); void run(async () => { const access = await token(); const permission = await request<Memory>('v1/memory', 'GET', undefined, access); setMemory(permission); if (permission.memory_consent !== 'granted') throw new Error('Memory permission is not granted. Nothing was saved.'); uncertainWrite(); const receipt = await request<{ committed?: boolean }>('v1/goals', 'POST', { text: item.text, quote: item.text }, access, item.id); if (receipt.committed !== true) throw new Error('Rumi did not explicitly confirm the save. Inspect goals before retrying.'); setUncertain(false); setGoal(''); setNotice('Rumi explicitly confirmed the goal save.'); }); }}>Confirm save to Rumi</button><button onClick={() => setReview(null)}>Cancel</button></div>}
      <label>Read-only service response<select value={resource} onChange={e => { setResource(e.target.value); setResult(''); }}>{resources.map(r => <option key={r}>{r}</option>)}</select></label><button className="rw-row" disabled={busy} onClick={() => void run(async () => setResult(JSON.stringify(await request(`v1/${resource}`, 'GET', undefined, await token()), null, 2)))}>Read {resource} <ArrowRight size={18} /></button>{result && <pre>{result}</pre>}
      {uncertain && <div className="rw-note">Save not confirmed. It may have reached Rumi. Inspect saved goals; do not blindly retry.<button onClick={() => setUncertain(false)}>I have checked saved goals</button></div>}
      <button disabled={busy} className="rw-row" onClick={() => void run(async () => { await request('v1/auth/logout', 'POST', {}, await token()); current.current = null; setSession(null); setMemory(null); setResult(''); setReview(null); setGoal(''); setUncertain(false); setChallenge(null); setNotice('Signed out through Rumi.'); })}><LogOut size={18} /> Sign out through Rumi</button>
    </>}
    <p className="rw-small">Browser sessions stay in memory, not local storage. Closing this account view removes device access, but does not revoke remote sessions or pause calls. New API ElevenLabs playback and other writes are not connected.</p>
    {notice && <p role="status" className="rw-note">{notice}</p>}{busy && <p role="status">Contacting Rumi…</p>}<button className="rw-row" onClick={onClose}>Back to welcome</button>
  </div>;
  function uncertainWrite() { setUncertain(true); }
}
