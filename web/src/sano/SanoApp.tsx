import React, { useEffect } from "react";
import { useSano } from "./store";
import { SoundEngine } from "./sound";
import { LivingGradient, RippleLayer } from "./ui/LivingGradient";
import { Orb } from "./ui/Orb";
import { Dock } from "./ui/Dock";
import { Glass } from "./ui/Glass";
import { Icon } from "./ui/Icon";
import { conversationPalette } from "./theme";
import { Onboarding } from "./screens/Onboarding";
import { Today } from "./screens/Today";
import { CareHub } from "./screens/Care";
import { YouHub } from "./screens/You";
import { Journeys } from "./screens/Journeys";
import { Currents } from "./screens/Currents";
import { Conversation } from "./screens/Conversation";
import { QuickLog } from "./screens/QuickLog";
import { Settings } from "./screens/Settings";
import { Recap } from "./screens/Recap";
import { BrowserDemo } from "./screens/BrowserDemo";
import { Sheet } from "./ui/Sheet";

/** Outer page — ambient wash behind a centered device column on desktop. */
export const SanoApp: React.FC = () => {
  const s = useSano();

  useEffect(() => {
    const unlock = () => SoundEngine.unlock();
    window.addEventListener("pointerdown", unlock, { once: true });
    return () => window.removeEventListener("pointerdown", unlock);
  }, []);

  return (
    <div className="min-h-[100dvh] w-full grid place-items-center bg-base">
      <div
        id="rumi-device"
        className="relative overflow-hidden w-full"
        style={{ maxWidth: 440, height: "100dvh", boxShadow: "0 40px 120px -30px rgba(0,0,0,0.5)" }}
      >
        <LivingGradient scheme={s.scheme} />
        <RippleLayer scheme={s.scheme} />

        {s.hasOnboarded ? <RootShell /> : <Onboarding />}
      </div>
    </div>
  );
};

const RootShell: React.FC = () => {
  const s = useSano();
  return (
    <div className="absolute inset-0">
      <div className={s.showConversation ? "opacity-0 pointer-events-none transition-opacity" : "absolute inset-0 anim-fade transition-opacity"}>
        {s.tab === "today" && <Today />}
        {s.tab === "care" && <CareHub />}
        {s.tab === "you" && <YouHub />}
        {s.tab === "journeys" && <Journeys />}
        {s.tab === "currents" && <Currents />}
      </div>

      {/* The companion is everywhere — except on Today (which has the big orb). */}
      {!s.showConversation && s.tab !== "today" && (
        <div className="absolute top-3 right-4 z-30">
          <button
            onClick={() => { SoundEngine.glass(); s.openConversation(); }}
            className="press grid place-items-center rounded-full glass p-1"
            aria-label="Talk with Rumi"
          >
            <Orb size={36} state={s.orbState} scheme={s.scheme} halo={false} />
          </button>
        </div>
      )}

      {!s.showConversation && <>
        <Dock />
        {s.tab === 'today' && <button onClick={() => { s.setQuickLogMedID(null); s.setShowQuickLog(true); }} className="press absolute bottom-[calc(6.5rem+env(safe-area-inset-bottom))] right-5 z-40 grid place-items-center size-14 rounded-full dock-frost text-ink" aria-label="Log something"><Icon name="plus" size={24} /></button>}
      </>}

      {s.showConversation && <Conversation />}

      {s.quickLogAck && <AckToast text={s.quickLogAck} />}

      <Sheet open={s.showQuickLog} onClose={() => { s.setShowQuickLog(false); s.setQuickLogMedID(null); }}>
        <QuickLog />
      </Sheet>
      <Sheet open={s.showSettings} onClose={() => s.setShowSettings(false)}>
        <Settings />
      </Sheet>
      <Sheet open={s.showAgentNetwork} full onClose={() => s.setShowAgentNetwork(false)}>
        <BrowserDemo />
      </Sheet>
      {s.showRecap && <Recap />}
    </div>
  );
};

const AckToast: React.FC<{ text: string }> = ({ text }) => {
  const s = useSano();
  return (
    <div className="absolute inset-x-0 z-40 flex justify-center px-6 pointer-events-none" style={{ bottom: 112 }}>
      <Glass
        radius={28}
        className="pointer-events-auto anim-rise max-w-[92%] p-4 flex items-start gap-3 cursor-pointer"
      >
        <Orb size={34} state={s.orbState} scheme={s.scheme} halo={false} />
        <div><p className="font-rounded text-[15px] text-ink leading-snug pt-1">{text}</p><div className="flex justify-between gap-4 mt-2"><button onClick={() => { s.setQuickLogAck(null); s.openConversation('pattern'); }} className="min-h-11 brand-ink font-rounded text-[14px] font-semibold">Talk it through</button><button onClick={() => s.setQuickLogAck(null)} className="min-h-11 brand-ink font-rounded text-[14px]">Not now</button></div></div>
      </Glass>
    </div>
  );
};
