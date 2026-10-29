import React from 'react';
import { useSano } from '../store';
import { canStopDemo } from '../browserDemo';
import { fmtTime } from '../lifeLibrary';

/** All ride events affect only the local sample workspace, and changed actions need fresh permission. */
export function SampleRideCard({ appointmentId }: { appointmentId: string }) {
  const s = useSano();
  const appointment = s.appointments.find(a => a.id === appointmentId);
  const ride = s.sampleRides.find(r => r.appointmentId === appointmentId);
  if (!appointment) return null;
  const ready = !canStopDemo(s.browserDemo.phase);
  return <section aria-label="Visit ride details" className="organic rounded-3xl p-4 space-y-3 text-ink">
    <h3 className="font-serif text-xl">Your visit, all in one place</h3><p className="font-rounded text-sm">{appointment.with} · {new Date(appointment.date).toLocaleDateString()} · {fmtTime(appointment.date)}</p>
    {ride ? <><div className="rounded-2xl bg-surface p-3 font-rounded text-sm space-y-1"><p className="font-semibold">Sample UberX · {ride.status} · ${ride.fare}</p><p>Pickup {fmtTime(ride.pickupAt)} · Home → {ride.destination}</p><p>{ride.driver} · Blue Toyota · {ride.plate}</p><p className="text-xs text-ink-muted">{ride.update}</p><p className="text-xs text-ink-muted">Sample event checked {fmtTime(ride.checkedAt)} · no live tracking, booking or charge</p></div>{ride.status !== 'cancelled' && <><button disabled={!ready} onClick={() => s.setWatchedRideId(s.watchedRideId === appointmentId ? null : appointmentId)} className="min-h-11 rounded-full glass px-3 brand-ink font-rounded text-sm disabled:opacity-40">{s.watchedRideId === appointmentId ? 'Stop watching sample updates' : 'Watch sample updates'}</button>{s.watchedRideId === appointmentId && <p className="text-xs text-ink-muted">A sample delay will arrive in 12 seconds, even with the browser minimized. This is not live monitoring.</p>}<details><summary className="min-h-11 text-sm font-rounded cursor-pointer">Preview a sample update</summary><p className="text-xs text-ink-muted font-rounded">Inject an event to show monitoring and fresh approval. Nothing changes at a ride service.</p><div className="flex flex-wrap gap-2">{([['late', 'Driver delayed'], ['moved', 'Appointment moved'], ['cancel', 'Cancel ride']] as const).map(([event, title]) => <button disabled={!ready} key={event} onClick={() => s.simulateRideUpdate(appointmentId, event)} className="min-h-11 rounded-full glass px-3 font-rounded text-xs disabled:opacity-40">{title}</button>)}</div>{!ready && <p className="text-xs text-ink-muted">Reopen or finish this ride task before injecting another event.</p>}</details></>}</> : <button onClick={() => { s.dispatchBrowserDemo({ type: 'start', scenario: 'ride', patient: s.persona.firstName, detail: `$24 sample UberX from Home to ${appointment.location}. Pickup ${fmtTime(appointment.date - 45 * 60000)}; visit ${fmtTime(appointment.date)}. 25-minute route, 20-minute arrival buffer. $0 sample cancellation fee; no real charge.`, appointmentId, appointmentDate: appointment.date, destination: appointment.location }); s.setShowAgentNetwork(true); }} className="min-h-11 rounded-full glass px-4 brand-ink font-rounded text-sm">Ask Rumi to arrange my ride</button>}
  </section>;
}
