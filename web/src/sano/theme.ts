/** Sano design tokens mirrored from the iOS Theme. Earthy means the *feel* —
 *  the palette itself stays luminous and alive. */

export type Scheme = "day" | "night";
export type AccentKey = "warm" | "life" | "sky" | "gold" | "rose" | "attention";

/** Accent → tailwind text/bg token name (drives `text-warm`, `bg-life/15` etc). */
export const accentToken: Record<AccentKey, string> = {
  warm: "warm",
  life: "life",
  sky: "sky",
  gold: "gold",
  rose: "rose",
  attention: "attention",
};

/** Living-gradient palette tuned per time of day. */
export function gradientPalette(scheme: Scheme, hour: number): [string, string, string] {
  if (scheme === "night") {
    if (hour >= 5 && hour < 9) return ["#183D32", "#234538", "#10241F"];
    if (hour >= 9 && hour < 17) return ["#163C32", "#244A3D", "#10241F"];
    if (hour >= 17 && hour < 21) return ["#244333", "#17382E", "#10241F"];
    return ["#17372D", "#214137", "#10241F"];
  }
  if (hour >= 5 && hour < 9) return ["#E3F5EA", "#FFF4CD", "#F8FAF8"];
  if (hour >= 9 && hour < 17) return ["#DDF4EA", "#F3F8EF", "#F8FAF8"];
  if (hour >= 17 && hour < 21) return ["#E6F3E8", "#FFF3CF", "#F8FAF8"];
  return ["#E5F2EA", "#F1F5E8", "#F8FAF8"];
}

export function conversationPalette(scheme: Scheme): [string, string, string] {
  return scheme === "night"
    ? ["#183C32", "#23483B", "#10241F"]
    : ["#DDF4EA", "#FFF4CD", "#F8FAF8"];
}

/** The companion gradient shells. */
export function companionColors(scheme: Scheme): [string, string, string] {
  return scheme === "night"
    ? ["#6EE7D8", "#9D8CFF", "#FF9FB2"]
    : ["#FFC9A8", "#F2A0BC", "#B39DE8"];
}

/** Soft pastel halo behind the orb. */
export function orbHalo(scheme: Scheme): string {
  return scheme === "night"
    ? "radial-gradient(circle, rgba(75,197,171,0.25), rgba(255,229,128,0.12) 45%, transparent 70%)"
    : "radial-gradient(circle, rgba(75,197,171,0.25), rgba(255,229,128,0.18) 45%, transparent 70%)";
}

export const FIXTURE_HOUR = new Date().getHours();
