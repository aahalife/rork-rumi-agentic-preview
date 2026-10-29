import React from "react";
import { cn } from "@/lib/utils";
import { Icon } from "./Icon";
import { Orb } from "./Orb";
import { useSano, type Tab } from "../store";
import { SoundEngine, Haptics } from "../sound";

/** Persistent navigation and companion access, outside every page's scroll layer. */
export const Dock: React.FC = () => {
  const s = useSano();
  const tabButton = (id: Tab, label: string, glyph: string) => {
    const active = s.tab === id || (id === 'you' && (s.tab === 'journeys' || s.tab === 'currents'));
    return <button key={id} onClick={() => { Haptics.tick(); s.setTab(id); }} aria-current={active ? 'page' : undefined} className={cn('press relative min-h-14 min-w-0 rounded-full flex flex-col items-center justify-center gap-1', active ? 'brand-soft brand-ink' : 'text-ink-muted')}>
      <span className="relative"><Icon name={glyph} size={20} />{id === 'care' && s.careUnreadCount > 0 && <span className="absolute -top-1 -right-1 size-2 bg-warm rounded-full" />}</span>
      <span className="text-[11px] font-rounded font-semibold">{label}</span>
    </button>;
  };
  return <nav aria-label="Floating navigation" className="absolute inset-x-0 bottom-0 pb-[calc(0.75rem+env(safe-area-inset-bottom))] px-4 pointer-events-none z-40">
    <div className="dock-frost pointer-events-auto grid grid-cols-5 items-center gap-1 p-2 rounded-[34px]">
      {tabButton('today', 'Today', 'sun.haze')}
      {tabButton('care', 'Care', 'cross.case')}
      <button onClick={() => { SoundEngine.glass(); s.openConversation(); }} aria-label="Talk with Rumi AI" className="press min-h-14 min-w-0 flex flex-col items-center justify-center rounded-full gap-0.5 brand-ink">
        <Orb size={40} state={s.orbState} scheme={s.scheme} halo={false} />
        <span className="text-[10px] font-rounded font-semibold whitespace-nowrap">Rumi AI</span>
      </button>
      {tabButton('you', 'You', 'book.closed')}
      <button onClick={() => s.setShowAgentNetwork(true)} aria-label={s.browserDemo.phase === 'review' ? 'Review pending approval' : 'Open task workspace'} className="press min-h-14 min-w-0 rounded-full flex flex-col items-center justify-center gap-1 text-ink-muted">
        <span className="relative"><Icon name={s.browserDemo.phase === 'review' ? 'hand' : 'sparkles'} size={20} />{s.browserDemo.phase === 'review' && <span className="absolute -top-1 -right-1 size-2 rounded-full bg-gold" />}</span>
        <span className="text-[11px] font-rounded font-semibold">{s.browserDemo.phase === 'review' ? 'Review' : 'Work'}</span>
      </button>
    </div>
  </nav>;
};
