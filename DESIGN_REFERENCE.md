# Rumi design and interaction reference

**Audited October 2, 2026.** This is a preservation contract and source map for production work, not permission to redesign the product. Numeric values below describe the current implementation. Where web and iOS differ, both are recorded; do not assume pixel identity. Source files remain authoritative for individual screen-specific values.

Related: [README](README.md), [production handoff](PRODUCTION_HANDOFF.md), [asset audit](ASSET_AUDIT.md).

## 1. Product character and non-negotiables

- Calm, luminous, tactile, editorial. Soft clay illustrations, living light, rounded controls, a glass companion orb, and readable frosted surfaces. Not a medical dashboard, generic chatbot, productivity scorecard, or neon sci-fi assistant.
- Rumi is visibly AI; warm and useful without pretending to be a person or clinician. One deliberate conversational move at a time. No streak shame, dependency language, false reassurance, invented prognosis, or unsupported clinical instructions.
- Preserve the **Today / Care / You** mental model. The central orb is a persistent door to conversation; Work becomes Review when permission is needed. Journeys and Currents are subordinate destinations, not two more primary dock tabs.
- Important controls belong to root/safe-area chrome, not scrolling cards: centered dock orb, Today log +, task approval reminder, task composer.
- Dimensionality is subtle: glass rims, blurred washes, glows, breathing, gentle scale. Keep text stable and legible; never let decorative animation block approval or suggest that a network operation succeeded.
- Explicitly distinguish sample records, personal disclosures, planned activities, completion logs, AI observations, drafts, and real provider confirmations.
- Existing assets are prepared/bundled media. Do not call them real-time generated or fetched from a person's Instagram.

## 2. Information architecture and screen map

### Root hierarchy

```text
Introduction → optional record connection door → Explore demo
Root
  Today — daily support, orb, one leading moment, visit preparation, life log
  Care — outcomes and Needs you, then records/care tools
  Rumi AI — conversation overlay; voice is a separate full-screen state
  You — Insights / Story, journeys, personal library, settings/privacy
  Work / Review — autonomous task workspace and approval queue
Secondary
  Journeys · Currents · records/lab explanation · discussion guide
  appointments (read-only) · care plan · medications · records
  reports · connections · care team · life catalog
  (messaging, refills, bills, wallet, savings and documents stay in the
   patient's portal; Rumi Works operates them there — descoped Oct 6, 2026)
Sheets/covers
  quick log · settings · exact-proposal review · recap · voice
```

Root implementations: `ios/Nudge/Views/RootView.swift`, `web/src/sano/SanoApp.tsx`. Native entry is `ios/Nudge/NudgeApp.swift` → `ios/Nudge/ContentView.swift`; web entry is `web/src/main.tsx` → `web/src/App.tsx` → product page/provider. In web, most product navigation is state-driven, not URL-addressable. Production deep links/back behavior need implementation without changing the visible hierarchy.

### Screen-by-screen source and behavior contract

Paths in the iOS column are relative to `ios/Nudge/Views/`; web paths are relative to `web/src/sano/`. These are file locators, not promises that every route is already connected to a live service.

| Surface | iOS | Web | Preserve / production behavior |
|---|---|---|---|
| Introduction | `Onboarding/OnboardingFlowView.swift`, `Onboarding/OnboardingConversationView.swift`, `Onboarding/RecordConnectView.swift` | `screens/Onboarding.tsx` | Orb-led welcome, “A little less to carry,” one primary CTA, optional connection; currently connection is unavailable, not fake OAuth success |
| Today | `Today/TodayCanvasView.swift`, `Today/MomentCard.swift` | `screens/Today.tsx` | Demo badge, greeting, orb, one leading moment with expansion, live-support panel, visit prep, life strip; avoid crowding all tools onto home |
| Live support | `Today/LiveSupportPanelView.swift` | `ui/LiveSupportPanel.tsx` | Separate AI observations with Why this/evidence, dismiss, optional check; insufficient evidence is a valid empty outcome |
| Navigation chrome | `Components/NudgeDock.swift`, `Components/FloatingLogButtonView.swift` | `ui/Dock.tsx`, `SanoApp.tsx` | Five slots: Today, Care, orb, You, Work/Review; keep reachable at bottom; Today + floats above dock on right |
| Care hub | `Care/CareHubView.swift` | `screens/Care.tsx` (`CareHub`) | Outcome-first cards, Needs you, progressive disclosure of records/tools; do not equate local task counts with external work completed |
| Portal note | `Care/CareHubView.swift` (`portalNote`) | `screens/Care.tsx` (`PortalNote`) | Explains that messages, refills and bills stay in the patient's portal; tapping opens Rumi Works |
| Appointments/calendar | `Care/AppointmentsView.swift` | `screens/Care.tsx` | Read-only portal context: date/time/location/visit kind, prep, trip plan, ride option; confirm/reschedule opens Rumi Works; test month boundaries, timezone and cancelled visits |
| Care plan | `Care/CarePlanView.swift` | `screens/Care.tsx` | Goals and clinician provenance; accepted local habit must not rewrite a clinician's instructions |
| Medications | `Meds/MedicationsView.swift`, `Meds/MedDetailView.swift` | `screens/Care.tsx`, `screens/shared.tsx` | Understanding and adherence: purpose, schedule, guidance, watchlist, tide, local logs, “Ask Rumi about it”; no supply/refill UI; do not infer safe dosing from a generated card |
| Records/labs | `You/RecordsDrawerView.swift`, `You/LabDetailView.swift`, `You/ExplainSheet.swift`, `You/ConditionOverviewView.swift` | `screens/You.tsx`, `screens/shared.tsx` | Category/source labels, chart → plain-language detail; expose dates, units and source, not just colored trends |
| Reports/visit prep | `Care/ReportsView.swift`, `You/DiscussionGuideView.swift` | `screens/Care.tsx`, `agentNetwork.ts` (`buildReports`) | Per-doctor context and editable questions; “Send through my portal with Rumi Works” hands off to an approval-gated portal task; never claim delivery without an external receipt |
| Connections/team | `Care/ConnectionsView.swift`, `You/CareTeamView.swift` | `screens/AgentNetwork.tsx`, `screens/You.tsx` | Connection scope/status and revocation; toggling a local flag is not provider authorization |
| You | `You/YouView.swift`, `Insights/InsightsHubView.swift`, `You/StoryTimelineView.swift` | `screens/You.tsx` | Insights/Story segmentation, journeys hero and quick doors; sample insight cards distinct from live support |
| Journeys/garden | `Journeys/JourneysView.swift`, `Components/LightGardenView.swift`, `Components/MemoryOrbView.swift` | `screens/Journeys.tsx` | Optional small habits, kept dates, held photo moments, growth/celebration without performance pressure |
| Currents | `Currents/CurrentsView.swift`, `Currents/CurrentsPlayerSheets.swift` | `screens/Currents.tsx` | Editorial reading/listening/watching, saved/taste states; do not confuse sample material with individualized clinical guidance |
| Life catalog/plans | `Life/LifeCatalogView.swift`, `Life/PlannedActivityView.swift` | `screens/You.tsx`, `ui/EverydayPlan.tsx`, `recipeCollection.ts` | Prepared plans separate from completed meals/movement; image continuity from source → saved plan → picker → log |
| Quick log | `Log/QuickLogView.swift`, `Log/LibraryPicker.swift`, `Log/BodyMapView.swift` | `screens/QuickLog.tsx` | Meals/Moves/Meds plus symptoms where offered, optional detail, acknowledge save; do not make every log trigger intrusive coaching |
| Conversation | `Conversation/ConversationView.swift` | `screens/Conversation.tsx` | Spacious transcript, grounded suggestions, Stop reply, latest-position following, explicit unavailable state, anchored composer |
| Voice | `Conversation/VoiceModeView.swift`, `Components/VoiceGradientGlow.swift` | `screens/Conversation.tsx` (`VoiceOverlay`) | Listening/thinking/speaking/error status with visible stop; microphone must not be inferred from orb animation |
| Sample task workspace | `Care/BrowserDemoView.swift`, `Care/SampleSitePreviewView.swift` | `screens/BrowserDemo.tsx`, `ui/SitePreview.tsx`, `ui/SocialRecipePreview.tsx`, `ui/SampleRideCard.tsx` | Browser above one conversation/progress stream; collapse/larger preview; minimize does not stop in-process runner; exact approval is outside scrolling detail |
| Connected native portal | `Care/PortalWorkspaceView.swift` | No equivalent complete web client | Separate service/access; preserve current origin and page-bound approval protections |
| Approval | `Components/ApprovalReviewView.swift` | `screens/BrowserDemo.tsx` | Popup exact proposal; Approve, Decline, Review later; remind outside chat; changes invalidate old proposal |
| Settings/memory | `Settings/SettingsView.swift`, `Settings/AIPrivacySettingsView.swift`, `Settings/MemoryReviewView.swift`, `Settings/PrivacyCenterView.swift` | `screens/Settings.tsx` | Appearance, sound, tone, AI/memory switches, inspect/correct/forget with evidence; export/delete must be real before release |
| Recap | `You/RecapPlayerView.swift` | `screens/Recap.tsx` | Full-screen editorial sequence, slow art/motion, skip/close, music; current content is not a proven server-generated personalized recap |

### Navigation geometry

- Web app is a centered **440px maximum-width**, **100dvh** device column, overflow hidden. Desktop is not a responsive clinical dashboard. `SanoApp.tsx` uses a large outer shadow; mobile fills the viewport.
- Web root z-order: backdrop/ripple → scene → top orb (`z-30`) → dock/Today + (`z-40`) → sheets (`z-50`). Conversation hides and disables pointer events on scene content; accessibility focus isolation still needs verification.
- Web dock: horizontal **16px** margin, **8px** inner padding, **34px** radius, minimum **56px** buttons; bottom **12px + safe-area inset**. Orb **40px**, labels **10–11px**. Today log + **56px**, right **20px**, bottom `6.5rem + safe-area inset`.
- iOS dock: horizontal **16pt**, inner **8pt horizontal / 7pt vertical**, item minimum **56pt**, bottom offset **6pt**; shadow radius **24pt**, y **11pt**, opacity **0.22**. Check safe-area layout rather than translating web CSS literally.
- Most native screen margins **20–22pt**, care grid gap **12pt**, content card padding **17–18pt**. Native Today/Care manually reserve approximately **150/132pt** at scroll bottom; verify all content remains reachable.
- Native root tabs contain NavigationStacks/sheets; preserve selected tab and scroll position when dismissing conversation. Test switching back from secondary You libraries; routes are not uniformly persistent today.

## 3. Color, typography, material

### Semantic colors

Canonical: `ios/Nudge/Utilities/Theme.swift`, `web/src/index.css`, `web/src/sano/theme.ts`. CSS tokens are RGB triplets, not HSL despite some generic component conventions. Use these actual values, not historical “Indigo Night” comments.

| Token | Day | Night |
|---|---|---|
| Base | `#F8FAF8` | `#10241F` |
| Surface | `#FFFFFF` | `#1A332B` |
| Raised | `#EFF7F1` | `#244338` |
| Ink | `#343937` | `#F0F7F1` |
| Muted ink | `#646C68` | `#AECABD` |
| Edge | `#DCE8DF` | `#3C5C4F` |
| Shadow | `#89A995` | `#000000` |
| Warm | `#E0764E` | `#FF9E7E` |
| Life | `#7FAE7E` | `#8FEFC0` |
| Sky | `#6E9CC8` | `#8FC6FF` |
| Gold (semantic name) | `#D9A348` | `#C8B6FF` |
| Rose | `#D8849B` | `#FF9FB2` |
| Attention | `#D98A3D` | `#FFBE8F` |
| Brand forest text | `#003B30` | `#A0E4D1` |

Brand accents: mint `#4BC5AB`, blush `#F2BDB5`, sun `#FFE580`. Reserve mint/forest for brand entry/navigation; semantic colors explain context, not diagnosis. Dark is a forest world, not a black inversion.

Time-of-day washes in `gradientPalette` change at **05:00, 09:00, 17:00, 21:00**. Web day triplets: dawn `#E3F5EA/#FFF4CD/#F8FAF8`, daytime `#DDF4EA/#F3F8EF/#F8FAF8`, evening `#E6F3E8/#FFF3CF/#F8FAF8`, late `#E5F2EA/#F1F5E8/#F8FAF8`. Night uses darker greens from the source function. Conversation day palette `#DDF4EA/#FFF4CD/#F8FAF8`; night `#183C32/#23483B/#10241F`.

Companion shells: day peach/pink/lilac `#FFC9A8/#F2A0BC/#B39DE8`; night aqua/lilac/rose `#6EE7D8/#9D8CFF/#FF9FB2`. Do not extend the orb's lilac into a generic purple UI redesign.

### Typography

Native: `ios/Nudge/Utilities/NudgeType.swift`. Web: `web/src/index.css`, `web/tailwind.config.ts`.

- Display/wordmark: **HermioneFREE**, CSS family `Hermione` with **0.01em** tracking.
- Editorial headings: **Fraunces** regular/medium/semibold/bold and 400 italic. iOS serif helper defaults semibold; web weight varies by component.
- Body/controls: system rounded; web fallback stack includes `SF Pro Rounded`, `ui-rounded`, Nunito, Quicksand, system UI. Nunito/Quicksand are fallback names, **not bundled fonts**. Expect platform differences.
- Numeric values: rounded with tabular/monospaced digits.
- Kicker: **11**, semibold, web uppercase **0.16em** tracking.
- Examples: native Today greeting **30pt**, Care heading **32pt**, Settings heading **28pt**, privacy display **32pt**, Rumi wordmark **24–25pt**. Web onboarding heading **38px**, secondary **29px**, body **16px**; web Settings heading **34px**.
- Typical content **14–16**, secondary labels **11–13.5**. Production must scale these for Dynamic Type/zoom; fixed point values are implementation, not justification for inaccessible sizes.
- Font licensing, especially HermioneFREE commercial rights, is not established by the filenames. Obtain licenses before release.

### Glass and frosted content

Native: `ios/Nudge/Views/Components/GlassSurface.swift`, `ios/Nudge/Views/Components/FrostedSurface.swift`.

- Content is **frosted**, controls can use Liquid Glass. Do not wrap every element in nested glass.
- `FrostedSurface`: default **30pt** continuous corner radius; regular material + surface tint **0.38 day / 0.36 night**; **2pt** directional white rim, second **0.7pt** inset rim at **4pt**; shadow **22pt**, y **8pt**, opacity **0.10**. Reduce Transparency replaces the material with solid surface.
- Shared organic/glass wrappers default to **36pt** radius; screen cards also use **24/26/28/30pt**. Inspect the caller before consolidating.
- iOS 26 glass APIs are availability-guarded with older-system material fallbacks.

Web (`web/src/index.css`):

| Class | Recipe |
|---|---|
| `.glass` | Tint alpha **0.50 day / 0.42 night**, blur **26px**, saturation **180%**, 1px border, inset hairline and diffuse shadow |
| `.glass-strong` | Base alpha + **0.20**, blur **40px**, saturation **200%** |
| `.organic` | Surface gradient **0.76 → 0.46** (night **0.85 → 0.60**), blur **28px**, saturation **135%**, luminous **2px** rim plus 3px soft inset |
| `.dock-frost` | Surface alpha **0.92**, blur **36px**, saturation **140%**; stronger opacity keeps navigation labels readable over cards |

Production: Reduce Transparency must cover the dock too; the current web media query covers organic/glass/glass-strong but not all custom surfaces. Validate contrast over bright art, dark mode and disabled controls.

## 4. Motion catalog

### Shared springs and press feedback

Native `ios/Nudge/Utilities/NudgeSpring.swift`:

| Preset | Response | Damping fraction | Intent |
|---|---:|---:|---|
| `ui` | 0.42 | 0.82 | ordinary UI transitions |
| `gentle` | 0.55 | 0.86 | calmer scene/state movement |
| `delight` | 0.38 | 0.66 | a restrained celebratory response |

Native `NudgeButtonStyle`: pressed scale **0.96**, opacity **0.88**; animation disabled under Reduce Motion, but state still scales. Web `.press`: **180ms**, `cubic-bezier(0.34,1.3,0.64,1)`, scale **0.955**, opacity **0.90**. Do not add audio to every scroll or tap; `tick` sound is deliberately silent.

### Web keyframes (all defined in `web/src/index.css`)

| Motion | Current parameters |
|---|---|
| Brand reveal | **800ms** ease-out; opacity 0→1, blur 5→0px, y 8→0px |
| Scene fade | **500ms**, `cubic-bezier(0.22,1,0.36,1)`, scale 1.03→1 |
| Push | **400ms**, `cubic-bezier(0.32,0.72,0,1)`, x 8%→0 |
| Rise | **600ms**, y 14→0px |
| Bloom | **600ms**, `cubic-bezier(0.34,1.56,0.64,1)`, scale .6→1.15→1 |
| Breath | **5.5s** ease-in-out, scale 1→1.045→1 |
| Halo | **5.5s**, opacity .55→.85; scale 1→1.12 |
| Bob | **6s**, y 0→−7px→0 |
| Sweep | **4.5s** repeating, x −120%→220%, skew −18 degrees; brief rim illumination |
| Ground ripple | **.95s**, 34px origin glow grows to 3.2×, removed at 960ms |
| Voice particles | **4.8s** linear, from +22vh to −104vh; 5px luminous dots |
| Browser working frame | **3s**, mint↔gold perimeter glow |
| Browser action pointer | **2.4s**, (−30,+12px) offset to target; slight press pulse |
| Thinking dots | `shimmerDots`, opacity .3→1 and y −3px; per-element duration/delay live in conversation component |
| Streaming glow | `streamGlow`, text-shadow 16→26px; don't announce every token |

The existence of a keyframe does not prove every screen uses it. Follow component call sites. Reduce Motion covers many classes, but not all inline ripples, video playback, or sheet transitions yet.

### Living atmosphere and touch light

- Web `web/src/sano/ui/LivingGradient.tsx`: three blurred radial centers, sizes **70/64/72%**, periods **26/32/38s**, phase offsets **0/−6/−14s**, blur **8px**. Fine SVG grain **.04 day / .05 night**.
- Native `ios/Nudge/Views/Components/LivingGradientView.swift` + `ios/Nudge/Shaders/LivingGradient.metal`: shader-backed animated ground; preserve the source's temporal/color behavior rather than approximate with a single flat gradient.
- Web `RippleLayer` ignores buttons, links, inputs, textareas, and `data-no-ripple`. Ripple is ground atmosphere, not a button splash.
- Native `ios/Nudge/Views/Components/RippleEffect.swift`, `ios/Nudge/Shaders/Effects.metal`: ripple propagation **1200pt/s**, touch-glow front **950pt/s**, decay `exp(-t*2.1)`. Confirm an effect is actually attached; some source comments/state still describe effects not wired at every root.
- Native `LightSweep` in `GlassSurface.swift`: **1.35s**, default strength **.5**, lens displacement **2.4**, max sample offset **4×4pt**. Ambient sweep default interval **9s** with −2…+3s jitter, strength **.4**.
- `ios/Nudge/Views/Components/MeltModifier.swift` and `Effects.metal` define melt/removal treatment. Use only at actual call sites, not as an app-wide transition by assumption.

## 5. Orb: state, rendering, and meaning

Canonical state: `ios/Nudge/ViewModels/OrbState.swift`; rendering: `ios/Nudge/Views/Components/VideoOrbView.swift`, `ios/Nudge/Views/Components/OrbView.swift`, `ios/Nudge/Shaders/Orb.metal`; web `web/src/sano/ui/Orb.tsx` and store orb state.

| State | Native breath period | Energy | Meaning |
|---|---:|---:|---|
| Ambient | 4.0s | .25 | present, not secretly recording |
| Listening | 2.6s | .70 | should correspond to actual active voice capture |
| Thinking | 2.0s | .55 | request pending |
| Speaking | 1.7s | .62 | reply arriving/playing |
| Celebrating | 1.2s | 1.0 | meaningful user completion; returns after 1.6s |
| Concerned | 5.5s | .16 | subdued support, not diagnosis |
| Resting | 6.0s | .10 | low activity |

Energy transitions over **.9s** using smoothstep.

### Video treatment

- Bundled loops: `orb_day.mp4`, `orb_night.mp4`, `orb_think.mp4`, `orb_speak.mp4`, `orb_bloom.mp4`.
- Native: two muted AVPlayer layers and loopers; **.7s** crossfade, outgoing layer paused at **.8s**. Small orbs **<60pt** use Metal instead. Circular mask opaque through **86%** radius. Core Animation breathing **.985→1.025**, autoreversing; a full cycle is twice the animation's supplied duration.
- Web: one muted/inline/autoplay/loop video, source replaced for state; no identical native-style dual-player crossfade. Listening shares speaking video. Mask alpha full at **56%**, .7 at **66%**, transparent at **75%**. Halo extends **.42× size** beyond bounds, blur **6px**; night screen blend.
- Native Today orb about **112pt**, conversation **110pt**. Web onboarding **154px**, connection step **92px**, conversation **108px**, corner **36px**, dock **40px**.
- Native Metal orb: **30fps** timeline; three gradient shells, breathing **±3%**, shell size **1.3×**, halo **1.9×**, specular **.26×** offset **−.11/−.14×**. Celebration ring scale **.9→1.9**, stroke **6→1pt**, opacity **.7→0**.
- Video does not currently fully honor Reduce Motion/background suspension. Add static fallback/poster and lifecycle pausing while retaining visual identity. Missing media must fail gracefully.
- Native conversation orb tap can set `.listening` without opening the microphone. Fix this semantic discrepancy rather than documenting it as live voice functionality.

## 6. Conversation, tasks and permission interaction

### Main conversation

Sources: `ios/Nudge/Views/Conversation/ConversationView.swift`, `ios/Nudge/ViewModels/CompanionEngine.swift`, `web/src/sano/screens/Conversation.tsx`, `web/src/sano/store.tsx`.

- Brief grounded opener once per conversation; restored chat should not be flooded with repeated greetings.
- Appended user text, pending state, streamed companion text, compact supported rich result. Hold back `[[...]]` tags from the visible stream.
- Stay at latest only when reader is within **90pt/px** of bottom. If the reader scrolls up, preserve position and show New activity. Test multi-line messages, keyboard appearance, cards appearing after text, and long streams.
- Web transcript uses **20px** horizontal padding, **96px** top and **176px** bottom reservation; composer remains outside it. Native input supports **1–4 lines**, rounded **15pt**, send/voice **44pt**.
- Native drag-to-close threshold **110pt**, opacity decreases with `dragY/900`; keep an explicit close button.
- Stop cancels work; outages are visible errors, not scripted replies disguised as generated content. No sensitive provider internals in user errors.
- AI default-on disclosure is presently in Settings. Production needs a visible pre-transmission explanation and appropriately reviewed consent behavior; do not silently transmit sensitive real records just because the demo defaults on.

### Autonomous task workspace

State machines: `web/src/sano/browserDemo.ts`, `ios/Nudge/ViewModels/BrowserDemoModel.swift`. Views: `web/src/sano/screens/BrowserDemo.tsx`, `ios/Nudge/Views/Care/BrowserDemoView.swift`.

- Choose a supported sample scenario; fixed sign-in/progress advances without repetitive Continue clicks. Web login delay **1800ms**, progression **2400ms** in root provider.
- Keep browser preview above lower transcript/progress. Collapse is independent of runner state. Minimizing should preserve work within the running app, not imply server/background execution after termination.
- Reading/drafting/local plans can finish without external permission; visit submission and rides stop for review. Stop/decline do not fabricate a receipt. Changed fare/appointment/details revoke the old review.
- Automatically open review for a new exact proposal. Review later dismisses popup but **does not approve**; pinned reminder and dock Review state remain.
- Long details scroll inside reachable review surface, not above off-screen Approve/Decline buttons. Show recipient, purpose, price/currency/fee, timing/timezone, destination, payload and sample/live status as applicable.
- Chat saying “approve,” source-page instructions, or model action tags must not authorize anything.
- Browser glow/action pointer indicates demonstration progress, not proof of a real click or browser session.
- Native connected portal is separate: `ios/Nudge/Services/AgentSession.swift`, `ios/Nudge/Services/AgentBridge.swift`, `ios/Nudge/Services/PortalActionPolicy.swift`, `ios/Nudge/Resources/agent-bridge.js`. Bind production authorization to the exact current page/form/proposal and single-use execution; never weaken this for conversational convenience.

## 7. Charts, organic data visualization and artwork

- Web `web/src/sano/ui/DataViz.tsx` (`GlowChart`): SVG width basis **320**, default height **200**, padding **14×22**, range pad **18%**, Catmull–Rom-derived cubic smoothing. Main stroke **2.4**, glow stroke **2.6** opacity **.45**, blur **5**, area alpha **.28→0**, selected dot radius **5.5**. Pointer selects nearest x point; annotate supplied events.
- Native `ios/Nudge/Views/Components/GlowChart.swift`: native chart implementation, paired with `You/LabDetailView.swift`. Preserve source dates/units/provenance. Production needs accessible tabular readings and empty/single-point handling. Smooth lines must not imply a real continuous measurement.
- `TideView` (native component and web DataViz) expresses adherence softly, not a moral score. Web fill clamp **.06…1**, default height **64**, three layers with **5/6.3/7.6s** bob periods. Do not interpret a seeded wave as observed adherence.
- `SceneVisual` is seeded decorative light, not a health metric: five web blobs, **14px** blur, default **120px** height, **18px** radius.
- Garden, memory bubbles, story and recap should use the existing layered/artful components, not standard dashboard charts. Native source locators: `ios/Nudge/Views/Components/LightGardenView.swift`, `ios/Nudge/Views/Components/MemoryOrbView.swift`, `ios/Nudge/Views/You/StoryTimelineView.swift`, `ios/Nudge/Views/You/RecapPlayerView.swift`.
- Artwork grammar: soft editorial clay, rounded silhouettes, matte surfaces, gentle directional light, pale warm surroundings, actual activity recognizable. Source post photo is distinct from the saved clay illustration.
- Mobility/walk pair: web `rumi-mobility-source-v1.webp` / `rumi-mobility-clay-v1.webp`; native `wellness_routine_figures` / `mobility_stretch_walk` catalogs. Chickpea source/clay images and 36 recipe images live in web public assets.
- Do not generalize the corrected mobility image to “all art matches.” `web/src/sano/lifeLibrary.ts` still maps several vegetarian meals to salmon/chicken-named art and many distinct activities to shoes. Native `ios/Nudge/Models/LifeModels.swift` provides its own mapping. Audit meaning, not only missing filenames.
- Native fill images need a size anchor and clipped overlay so overflowing image layout cannot swallow nearby taps. Preserve explicit frame/overlay layout when refactoring cards.

## 8. Sound, voice, haptics

Sources: `ios/Nudge/Services/SoundEngine.swift`, `ios/Nudge/Services/VoiceSession.swift`, `ios/Nudge/Utilities/Haptics.swift`, `web/src/sano/sound.ts`, `web/src/sano/screens/Conversation.tsx`.

| Sound behavior | Native | Web |
|---|---|---|
| Onboarding bed | Barley Thunder, volume **.42** | Same file, **.50** |
| Ambient bed | Stone Kintsugi, **.30** | Same file, **.34** |
| Bed transition | Default **2.4s** crossfade | Default fade **1.6s**, first gesture unlock can use **2.4s** |
| Tap notes | Five ta clips, two players each, phrase `[0,2,4,2,3,1,4,0,2,3]`, min spacing **90ms** | Cycles five clips, volume **.50** |
| Routine tick | Intentionally silent | Intentionally silent |
| Glass / send | **.22 / .30** | Glass **.50**, send plays ta |
| Bloom / whoosh | **.45 / .30** | **.60 / .50** |
| Recap | Separate native recap music, **.60**, fade **1.6s** | Inspect recap's current playback rather than assume matching native track |

Web sound must unlock with a user gesture; blocked autoplay is not a provider error. Web fade uses frame counts, not elapsed time, so nominal seconds vary with refresh rate and overlapping fades can race. Fix with elapsed-time interpolation/cancellation. Native `.playback` + `.mixWithOthers` can play in silent mode; align copy and mute behavior. Recap uses a different enable gate; test that music-off is meaningful everywhere.

Native haptics: light tick **.6**, soft glass **.8**, medium pull, success notification; bloom soft **.55** at 0, medium **1.0** at **160ms**, light **.4** at **340ms**. Web `navigator.vibrate` optional fallback: **6ms**, **8ms**, `[4,30,8]`, **14ms**, `[10,24,16]`. Unsupported browser vibration should not affect functionality.

Native voice records mono AAC **44.1kHz**, meters every **42ms**, uses speech threshold **.06**, quiet **.04**, **26 quiet frames**, minimum **1s**, and recycles silence after **8s**. STT/TTS are network operations. Production must test cancel during permission/transcription/playback, denied mic access, Bluetooth routes, interruptions, and clean temporary audio. Never ship the permission copy “nowhere else” while audio is sent to an external transcription provider.

## 9. Sheets, transition semantics and accessibility gaps

- Web `web/src/sano/ui/Sheet.tsx`: portal inside device frame, 32% black backdrop with **2px** blur, **300ms** opacity; slide **360ms** with `cubic-bezier(.32,.72,0,1)`. Standard top **5%**, radius **30px**; full variant edge-to-edge. Includes dialog role but not a complete focus trap/Escape/focus-return implementation. Complete semantics without changing appearance.
- Native sheets use native safe areas/presentation. Scrollable multi-detent sheets should scroll rather than unexpectedly resize; verify the actual sheet call sites.
- Large type, bold text, high contrast, dark/light, Reduce Motion/Transparency, keyboard-only, VoiceOver/TalkBack/browser screen-reader behavior require acceptance. Do not mark accessibility done because some controls have labels.
- Video orb loops, generated ripple DOM, inline animations and native CAAnimation need explicit Reduce Motion handling.
- Some small close/delete controls remain below **44×44pt**. Preserve visual size if desired but enlarge hit region.
- Web chart scrubbing needs keyboard and textual alternatives. Empty chart series must not crash on first/last point access.
- Hidden scenes need accessibility isolation, not opacity alone. Dialog focus must not reach the dock behind it. Approval focus should land on heading/details, not accidentally authorize.
- App backgrounds, materials and static assets can be pixel-regression tested; dynamic orb video/gradient frames require deterministic clocks/posters or perceptual tolerances.

## 10. Visual acceptance checklist for production milestones

Capture both platforms before refactoring; compare afterward using the same seeded profile/time/settings.

- [ ] Introduction and record connection unavailable/success/cancel states.
- [ ] Today first screen, scrolled bottom, expanded moments; + and dock never move with content.
- [ ] All five dock targets, pending-review badge, selected-tab semantics.
- [ ] Care hub, expanded tools, Needs you, calendar and detail back stacks.
- [ ] You Insights/Story, lab chart/detail, journey/garden, memory and Currents.
- [ ] Chat start, restored chat, 2000-character user message, long streamed reply, error/retry, Stop, scroll-back/New activity, keyboard shown/hidden.
- [ ] Work browsing/minimized/collapsed/expanded; paused/failed/retried/stopped; no network claim from animation alone.
- [ ] Review appears automatically, long proposal controls reachable, Review later remains blocked, new fare/payload reopens fresh review, approve once only.
- [ ] Voice permission denied, active recording, thinking, speaking, stop, interruption and offline.
- [ ] Memory correction/deletion visibly changes next context; private session shared-device explanation is honest.
- [ ] Smallest supported iPhone, large iPhone, iPad/window widths if supported, portrait/landscape; Android Chrome browser, Safari/Chrome desktop keyboard, mobile keyboard safe areas.
- [ ] Day/night, large type/200% zoom, Reduce Motion/Transparency, bold text, VoiceOver, battery/background pause, silent switch/music-off.
- [ ] Artwork names match meals/activities, source/photo and clay are intentionally distinct; no broken asset or clipped tappable region.

These are release gates, not a claim that the current source passes them. Exact component code and bundled reference recordings in [ASSET_AUDIT.md](ASSET_AUDIT.md) provide the visual starting point.
