import React, { useEffect, useState } from "react";
import { useSano } from "../store";
import { SoundEngine } from "../sound";
import { Orb } from "../ui/Orb";
import { Icon } from "../ui/Icon";

/** Brief introduction and one optional connection door. No simulated portal sign-in. */
export const Onboarding: React.FC = () => {
  const s = useSano();
  const [connecting, setConnecting] = useState<boolean>(false);
  const [unavailable, setUnavailable] = useState<boolean>(false);
  useEffect(() => { SoundEngine.playBed("onboarding", 2.6); }, []);
  const finish = (): void => {
    s.setEpsilonConsent(false);
    s.completeOnboarding({ firstName: "", lastName: "", birthDate: null, pathway: s.pathway, connectedSystems: [], healthConnected: false, values: "", barrier: "", tone: s.tonePreference });
    s.setTab("today");
    SoundEngine.playBed("ambient", 2.4);
  };
  return (
    <div className="absolute inset-0 brand-atmosphere overflow-y-auto">
      <div className="flex justify-between px-5 pt-3">
        <button aria-label="Back to introduction" onClick={() => { setConnecting(false); setUnavailable(false); }} className={`size-11 grid place-items-center text-ink ${connecting ? "" : "invisible"}`}><Icon name="chevronLeft" size={18} /></button>
        <button aria-label="Toggle music" onClick={() => s.setMusicOn(!s.musicOn)} className="size-11 grid place-items-center text-ink"><Icon name={s.musicOn ? "volume" : "mute"} size={18} /></button>
      </div>
      <div className="px-7 pt-8 pb-10 max-w-md mx-auto">
        <div className="flex justify-center mb-10"><Orb size={connecting ? 92 : 154} state="ambient" scheme={s.scheme} halo={false} /></div>
        <div key={connecting ? "connect" : "welcome"} className="brand-reveal space-y-6">
          <h1 className="font-serif text-[38px] leading-tight brand-ink">{connecting ? <>Your story.<br />In one place.</> : "Hi, I’m Rumi."}</h1>
          {!connecting && <h2 className="font-serif text-[29px] text-ink">A little less to carry.</h2>}
          <p className="font-rounded text-[16px] leading-relaxed text-ink-muted">{connecting ? "Connect your healthcare providers to bring your records together. Choose what to share, and add more sources whenever you’re ready." : "I help you make sense of your records, prepare for visits, and keep the next step simple. You’re always in charge."}</p>
          {connecting && <div className="flex items-center gap-4 py-3"><div className="size-14 rounded-full brand-soft grid place-items-center"><Icon name="file" size={24} className="brand-ink" /></div><div><p className="font-rounded text-[14px] text-ink font-medium">Labs, medications & visit history</p><p className="font-rounded text-[12px] text-ink-muted mt-1">From the sources you authorize</p></div></div>}
          <button className="w-full rounded-full min-h-[54px] px-5 font-rounded text-[16px] font-semibold bg-[#003B30] text-white" onClick={() => connecting ? setUnavailable(true) : setConnecting(true)}>{connecting ? "Connect my records" : "Get started"}</button>
          {unavailable && <div role="status" className="rounded-2xl bg-white/70 p-4 text-ink"><p className="font-rounded text-[14px] font-medium">Records connection isn’t enabled yet</p><p className="font-rounded text-[13px] text-ink-muted mt-1">Secure provider authorization needs to be configured. You can explore without entering any portal credentials.</p></div>}
          {connecting && <button onClick={finish} className="w-full min-h-12 font-rounded text-[14px] brand-ink">Explore the demo for now</button>}
          <p className="font-rounded text-[12px] text-ink-muted leading-relaxed">{connecting ? "This preview uses sample records. No provider has been connected and no medical history has been imported." : "Practical support, not a diagnosis or emergency service."}</p>
        </div>
      </div>
    </div>
  );
};
