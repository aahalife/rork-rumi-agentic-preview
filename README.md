# Rumi — companion app, web experience, and AI backend

**Handoff snapshot: October 2, 2026.** Rumi is the product name. `Nudge`, `Sano`, and `sano` are historical code/target names, not additional products. Preserve them until a deliberate migration; indiscriminate renaming will break asset, persistence, and Xcode references.

Rumi helps people understand care information, prepare for visits, remember what matters, and take small practical steps. Its personality is warm, brief, nonjudgmental, and autonomy-supportive. It is explicitly AI, not a clinician, emergency service, or substitute for care.

> This repository is a sophisticated, interactive **demo with real AI/voice plumbing**, not a production healthcare platform. Sample records, simulated workflows, and locally stored visitor disclosures coexist. Do not connect real patients or charge/submit external actions until the release gates in the handoff are met.

## Start here

For a plain-English walkthrough of the current simplified iPhone and Web demos, start with [DEMO_GUIDE.md](DEMO_GUIDE.md). It includes copy-and-paste AI prompts, expected sample results, approval steps and platform limitations. The older product snapshot below is historical; use the guide and latest handoff checkpoints for the simplified experience.

| Document | Purpose |
|---|---|
| [PRODUCTION_HANDOFF.md](PRODUCTION_HANDOFF.md) | Current architecture, real/demo/partial inventory, assumptions, blockers, proposed production architecture, milestones, acceptance gates, and a copy/paste Codex brief |
| [DESIGN_REFERENCE.md](DESIGN_REFERENCE.md) | Information architecture, screen behavior, colors, typography, materials, animation timings, orb/shader/audio details, accessibility and parity requirements, exact source references |
| [ASSET_AUDIT.md](ASSET_AUDIT.md) | Asset locations, tracking/remote evidence, reproducibility, external dependencies, licensing gaps |
| [tools/audit-handoff.py](tools/audit-handoff.py) | Read-only asset hashes/tracking, catalog checks, selected asset references, and documentation path validation; `--manifest` prints a full inventory |

**Source of truth:** executable code for what works today; the handoff for known limitations and recommended next work; the design reference for preservation constraints. Historical specifications are intent, not evidence of implementation. Older plan entries mentioning an AI preview code or default-off AI were superseded. Existing explicit off choices are still respected.

## Repository map

```text
ios/Nudge/                 Native SwiftUI app (iOS 18+)
  Models/                  Domain types and fictional patient fixtures
  ViewModels/              AppModel, CompanionEngine, BrowserDemoModel, OrbState
  Services/                AI, voice, persistence, portal/browser bridge
  Views/                   Screens and reusable visual components
  Utilities/               Theme, fonts, springs, haptics, public configuration
  Shaders/                 Metal orb, gradient, ripple and light effects
  Assets.xcassets/          Bundled images and app icon
  Fonts/                   Fraunces and Hermione TTFs
  Resources/               Orb videos, music, effects, agent-bridge.js
ios/Nudge.xcodeproj/       Xcode project and test targets
ios/NudgeTests/            Logic/integration-policy tests
ios/NudgeUITests/          UI tests (not implied by unit-test results)
web/src/sano/              React product implementation
web/src/components/ui/     Installed reusable UI primitives
web/src/test/              Vitest/jsdom tests
web/public/                Versioned images, fonts, audio, orb videos, icon
functions/                Cloudflare worker: Anthropic SSE + voice proxies + budgets
tmp/                      Tracked historical specs and visual/media references
.rork/                    Rork-managed project state, history and approved plans
```

`rork.json` registers `ios` (Swift), `web` (Vite/React), and `functions` (Cloudflare). There is **no native Android app** in this repository. A browser running on Android is not an Android release.

## What is actually implemented

- Native/web branded shell, Today/Care/You, centered orb dock, persistent quick-log button, work/review workspace, rich sample care screens, day/night palettes, frosted cards, local artwork and sound.
- Direct server-to-Anthropic streaming, client Stop/unavailable states, input/output bounds, purpose-specific instructions, and durable chat request counters. Code pins `claude-sonnet-5-5`; verify model access and request schema for the deployment account rather than assuming availability or silently substituting another model.
- Real microphone/transcription/AI/speech code using ElevenLabs, but both clients' complete live voice acceptance remains outstanding.
- AI and memory default on for new local installs. No AI preview code. Separate switches permit opt-out. Memory candidates require supporting user quotes and confirmation before shaping replies.
- Per-browser/per-install, per-sample-profile memory and recent transcript persistence. No authenticated user accounts or cloud memory synchronization.
- Autonomous **sample** task progression with explicit approval popups for consequential sample actions; changed proposals require fresh review. A separate native connected-portal client exists, but its external service is not supplied in this repository.

**Descoped by design (Oct 6, 2026):** Rumi complements the patient portal rather than duplicating it. Care-team messaging, refills, bills/payments, wallet, savings programs, the documents vault and in-app appointment changes were removed; Rumi Works performs those in the patient's real portal/service with approval.

**Not implemented as production services:** patient identity/authorization, provider record ingestion, Rumi Works against real portals, real ride booking, Instagram authorization, server-owned task execution, audited account deletion/export, push delivery, production observability/compliance. See the detailed inventory, including misleading legacy success copy, in the handoff.

## Development prerequisites

- Bun; use the lockfile in `web/bun.lock`. Web currently uses React 19, Vite 8, TypeScript 5.9, Tailwind 3, Vitest 4; exact versions are in `web/package.json` and the lockfile.
- macOS and modern Xcode with the iOS 26 SDK for the native app (deployment minimum iOS 18). Guarded iOS 26 APIs still require an SDK that knows them. Do not try to build UIKit/SwiftUI with Linux Swift.
- Python 3 for the handoff audit (standard library only).
- Rork-managed Cloudflare deployment, or a deliberate standalone Cloudflare port. This is **not yet a self-contained Wrangler project**.

### Web

From `web/`:

```sh
bun install --frozen-lockfile
bun run dev
bun run test
bunx tsc --noEmit -p tsconfig.app.json
bun run build
```

The dev server is configured on port 8080. `bun run lint` is available; the existing repository can have standalone ESLint findings unrelated to a specific change. Report them rather than claiming a clean lint run from a successful build.

**Important:** the client calls `/~api`. Rork hosting supplies that same-origin reverse proxy; local Vite does not. A fresh localhost clone can display the UI while AI fails until you configure a development proxy or portable backend base URL. See `web/vite.config.ts`, `web/src/sano/ai.ts`, and the portability section of the handoff. Never solve this by putting provider secrets in browser envs.

### Native iPhone

Open `ios/Nudge.xcodeproj`; use scheme `Nudge`. The project uses synchronized file groups; new files under the app folder are discovered without manually duplicating build-phase entries. Signing/team values must be configured for the owner's Apple account before device or App Store builds.

`Config.swift` is deliberately ignored and injected by Rork, so a plain clone lacks it. Outside Rork, supply a **local, ignored** `Config.swift` inside `ios/Nudge/` defining these public fields used by `ios/Nudge/Utilities/AppConfig.swift`:

```swift
enum Config {
    static let EXPO_PUBLIC_TOOLKIT_URL = ""
    static let EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY = ""
    static let EXPO_PUBLIC_RORK_FUNCTIONS_URL = "https://YOUR-BACKEND-HOST"
}
```

The toolkit-named value is legacy client configuration, not the Anthropic or ElevenLabs secret. The main AI path calls your own backend. Audit/remove unused toolkit exports rather than copying any secret into this file. Supply the correct backend explicitly; the current fallback points at this demo's deployment.

Useful local Xcode commands (choose an installed simulator identifier):

```sh
xcodebuild -list -project ios/Nudge.xcodeproj
xcodebuild -showdestinations -project ios/Nudge.xcodeproj -scheme Nudge
xcodebuild -project ios/Nudge.xcodeproj -scheme Nudge -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' build
xcodebuild -project ios/Nudge.xcodeproj -scheme Nudge -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' -only-testing:NudgeTests test
```

UI tests are separate. Simulator success does not establish device signing, App Store Release success, physical microphone behavior, or accessibility acceptance.

### Backend and secrets

`functions/index.ts` routes requests. `functions/rumi-ai.ts` contains model policy, validation, streaming, and `RumiBudget`. Configuration placement:

| Value | Placement | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | Server secret | Live AI |
| `ELEVENLABS_API_KEY` | Server secret | Speech recognition and playback |
| `EXPO_PUBLIC_RORK_FUNCTIONS_URL` | Public native build config | Backend origin |
| `EXPO_PUBLIC_TOOLKIT_URL`, `EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY` | Existing public legacy client config | Review usage before migrating |

Do not commit `.env`, provider credentials, session cookies, portal invitation codes, or signing keys. Env values and vendor accounts **do not travel with a Git clone**. `RUMI_PREVIEW_CODE` is no longer used. The separate browser-agent invitation code is unrelated and is still required for that external service.

Rork builds/deploys each app with its app path. Outside Rork, implement the Cloudflare deployment/binding adapter described in the handoff before claiming the backend can deploy independently.

## Tests and evidence

Last implementation checkpoint before this documentation pass: **55 web tests**, **16 native tests**, successful web/static build and iOS simulator build, deployed backend, and an actual no-code streamed backend reply. These are scoped results, not full production acceptance. Voice, authenticated hosted-portal execution, UI/keyboard visual behavior, clinical safety review, and physical-device/Release validation remain incomplete.

**Fresh validation during this handoff:** all 55 web tests passed and web static/build checks passed. Vitest emitted existing React `act(...)` warnings in autonomous-workspace tests; they should be cleaned up, not mistaken for failure-free test hygiene. Native tests/build and live provider calls were not rerun for this documentation-only application change; their 16-test/build/smoke results above are from the prior implementation checkpoint. The new asset/document audit passed with zero failures over 345 files (294,750,585 bytes).

This handoff adds a reproducible audit:

```sh
python3 tools/audit-handoff.py
python3 tools/audit-handoff.py --manifest
```

The audit checks bundled/reference asset bytes, Git tracking, Xcode image filenames, literal web URLs plus known dynamic recipe/tap assets, identical shared media, and documentation paths. It is not a full runtime asset crawler or screenshot test.

## Git / GitHub handoff

All runtime asset folders and tracked reference recordings are included, not just source code. The pre-handoff local commit and `origin/main` matched at `0b9226efbe11d9b539d912c80c23dfbb30aca90e`. That proves synchronization to the configured repository remote at that time, **not independent confirmation of a downstream GitHub mirror**. New documents follow Rork's managed synchronization; no manual commit or push was performed. See [ASSET_AUDIT.md](ASSET_AUDIT.md) for the exact verification boundary.

Keep `.rork/` tracked and intact, including history. Do not delete it or add ignore rules/hooks that exclude it. Existing history is not application runtime data and should not be publicly distributed without the owner's privacy review. Rotation, not history deletion, is the remedy for leaked credentials.

## Production handoff to Codex

Give Codex this repository and start with the ready-to-paste brief at the end of [PRODUCTION_HANDOFF.md](PRODUCTION_HANDOFF.md). Ask it to preserve the established design and work in independently validated milestones, not replace the app with a generic dashboard. The handoff explicitly identifies decisions requiring the owner, provider agreements, credentials, and clinical/legal review; an AI coding agent cannot manufacture those approvals.
