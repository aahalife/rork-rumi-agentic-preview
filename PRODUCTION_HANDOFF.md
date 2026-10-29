# Rumi production engineering handoff

**Prepared October 2, 2026 for an incoming implementation team / Codex agent.** This describes the actual repository, not an imaginary finished backend. Follow [DESIGN_REFERENCE.md](DESIGN_REFERENCE.md) for visual and interaction fidelity and [README.md](README.md) for setup. The requested destination is a full production app and backend; the sections labeled **proposed** below are work to implement, not existing capabilities.

## Simplified iPhone checkpoint — October 29, 2026

This checkpoint concerns `ios-rumi` and the isolated `/companion/*` service, not the larger native/web app described below. The simplified app now has retained website browsing, model-proposed actions with native exact-action approval, authenticated chat/history, ElevenLabs voice and approved scheduled calls, Photon v2 Beta linking/messages, and charts backed by manually entered dated/source-labelled measurements. These are implemented integration paths, not end-to-end acceptance claims. Automatic medical-record import is not implemented.

### Validation and delivery

- The final `ios-rumi` checks passed after the private-form approval guard and account-change conversation reset: **simulator build succeeded**. Device/Release success and native UI interactions have not been verified.
- Backend bundling/deployment passed previously at `https://rumi-cvs-agentic-backend.rork.app`; service configuration status is not evidence of successful model execution.
- Regenerated `deliveries/rumi-works-interactive-browser.patch`; `git apply --check --whitespace=error` succeeded against the unchanged linked fork at `2a6a5e0`. The exporter includes companion-only backend routes, not the larger app's legacy public endpoints or private Rork history.
- No GitHub branch was created, pushed or merged. Apply the patch from the target repository root on an independently created feature branch. Review the exported server configuration and replace the app's service origin if deploying elsewhere.
- No live authenticated browser-agent, microphone conversation, outbound/scheduled call, verified two-way Photon exchange, or chart interaction was exercised. No integration tests were run. Backend deployment is not an independent strict TypeScript validation.

### Private service activation required

Configure these settings through the hosting operator's private secret-management surface, never in client code, source, chat or the model context:

- Account authorization: `RUMI_ACCESS_TOKENS`, a JSON mapping of SHA-256 access-token hashes to opaque account subjects. `tools/provision-companion-access.py` creates private provisioning files outside the repository; do not commit or share its token output. Enter only the individual account token in the phone's Account settings; it is stored in Keychain.
- Model: `ANTHROPIC_API_KEY` and optionally `RUMI_AGENT_MODEL` (otherwise the existing `RUMI_MODEL`). Confirm account access to the configured model; do not silently substitute another model.
- Voice/calls: `RUMI_ELEVENLABS_API_KEY`, `RUMI_ELEVENLABS_AGENT_ID`, `RUMI_ELEVENLABS_PHONE_NUMBER_ID`; optionally `RUMI_ELEVENLABS_PHONE_PROVIDER=sip` for SIP instead of Twilio. Native voice requires negotiated PCM input/output.
- Photon v2 Beta: `PHOTON_API_KEY`, `PHOTON_PROJECT_ID` (`pho_prj_…`), `PHOTON_AGENT_USER_ID`, `PHOTON_LINE_ADDRESS`, `PHOTON_WEBHOOK_SECRET`. Configure the signed webhook according to the companion handler, then link a verified direct iMessage space using the app's short-lived code.

Provider credentials and an authorized account token were not available for live acceptance. Secure environment-variable documentation is now available for future private provisioning; no credentials were requested in chat or copied from attachments. Keep the browser, source-grounded work, connected conversation and health-interaction acceptance goals open until they are exercised with authorized services and real inputs.

### Supplied Rumi API reuse — October 29 follow-up

Inspected the supplied `rumi_api-main.zip` source selectively outside the repository; no environment files, credentials, databases or attachment source trees were imported. It is a Python service with a persistent Photon **Spectrum** sidecar, not Photon v2 Beta. Its existing ElevenLabs custom-LLM phone calls and signed webchat use the same phone-keyed Rumi engine session. The archive supplies configuration contracts, not deployed secret values.

`functions/rumi-existing-api.ts` now provides an opt-in adapter to its actual `/chat/{token}/send` and `/eleven/initiation` routes. Set `RUMI_API_ORIGIN` to the existing HTTPS origin and `RUMI_API_CHAT_LINKS` to a private JSON mapping of companion subject to that verified owner's signed chat token. The operator must verify account/link ownership; signup alone is not authentication. `tools/provision-companion-access.py --existing-chat-link-file <private-file>` can prepare the mapping alongside a pilot account token without printing it. Existing links expire after 24 hours and require private renewal; this is a bridge, not durable production account federation.

In this mode ordinary chat uses the existing engine without replaying a second transcript or falling back to another model. Browser reasoning continues using the separately configured browser model. App-visible messages are a separate forward-only adapter cache; earlier app messages, existing iMessages and voice turns are **not** imported. The supplied API has no history enumeration endpoint. Edits cannot rewind its engine memory; send a new correction instead. Durable request markers prevent automatic resubmission of uncertain upstream turns. A timed-out request may still have reached the engine.

For shared-memory outbound calls, configure `RUMI_API_INIT_SECRET` with the existing service's `ELEVEN_INIT_SECRET` using private server settings, plus the **same existing** ElevenLabs agent/key/phone-number ID under the companion's namespaced settings. The existing service mints its own proof server-to-server; its LLM secret is neither duplicated nor sent to the phone. Calls are limited to the account's mapped phone and retain exact native approval/scheduling. Changing conversation mode cancels pending calls from the previous mode when the alarm runs.

While existing-API mode is enabled, the companion's competing Photon v2 reply handler/link flow and native microphone ticket flow are disabled explicitly. The existing Spectrum service remains the inbound messaging owner. Shared-memory microphone authorization needs a short-lived, conversation-scoped authorization extension in that service: exposing its current reusable HMAC proof to the phone would weaken its security design. Verified cross-channel transcript sync likewise needs a service extension. No migration to v2 or extension to the deployed Python service has been performed.

Account and channel screens distinguish chat from browser configuration and disclose these limits. No upstream credentials, approved account links or deployed-service access were supplied in the archive, so no authenticated service turn, call, voice or message exchange has been exercised. This follow-up passed the `ios-rumi` simulator build and deployed backend code `6b81a8eeab7a7080630b0c585ba9ad69`. Python syntax and source whitespace checks passed. The regenerated patch (168,213 bytes; SHA-256 `5d22219def1f49f5f8a71a843ec1763988386b1ee4c6e98696ff16b825ad6c57`) passed `git apply --check --whitespace=error`; the linked fork remains clean. No runtime interactions or automated tests were performed, and no GitHub push occurred. This follow-up does not satisfy the open connected-conversations acceptance goal.

## 1. Executive assessment

Rumi has a substantial native SwiftUI app and a React mobile-web experience, bundled art/music/video, fictional patient/care data, local logs and memory, autonomous sample workflows, and a real Anthropic/ElevenLabs backend. It is a good **product/design foundation**. It is not production-ready for real health records, payments, external submissions, or account-based continuity.

Keep the existing UI and interaction grammar. Replace fixtures and unsafe local-success assumptions behind typed boundaries. Do not reimplement the entire interface in a new design system as a shortcut to backend work.

### Evidence vocabulary

- **Implemented:** code exists and the behavior is within this repository's responsibility.
- **Validated narrowly:** a specific build/test/smoke result exists; not end-to-end acceptance of every related feature.
- **Demo:** fixed sample content, timer/reducer-driven progression, or local mutation without provider confirmation.
- **Partial:** real code path exists but lacks complete correctness, integration acceptance, security or lifecycle handling.
- **Not supplied:** external dependency, credential, infrastructure or product decision unavailable in this repository.

Previous implementation checkpoint: 55 web tests and 16 native tests passed; web/static and iOS simulator builds passed; backend deployed; a no-preview-code live streamed AI completion succeeded at the backend. This does not prove voice end-to-end, UI layout, safety, provider delivery, or signed Release readiness. This documentation pass does not implement the production gaps it identifies.

## 2. Assumptions and decisions to preserve or resolve

### Current owner decisions

1. Product name **Rumi**, assistant **Rumi AI**. Native target/module is `Nudge`; web historical implementation namespace is `sano`. Do not rename all identifiers casually.
2. Web and native iPhone must stay aligned. iOS 18 minimum, guarded iOS 26 materials. No native Android code currently exists.
3. Today / Care / You is the core IA; orb centered in persistent dock, quick-log + anchored outside Today scroll, Work/Review shortcut. Reference all interaction details in the design document.
4. Direct Anthropic is the default. Current model identifier is pinned in server code to `claude-sonnet-5-5`; a previous live smoke test worked. Verify account/model/API support on transfer. No silent provider/model substitution.
5. AI and lasting memory are on by default for new demo installs; preserve an existing explicit off choice. There is no AI preview-code gate. Clear external-processing disclosure remains required. This is a demo product decision, **not a legal conclusion that default-on sensitive processing is acceptable in production**.
6. Visitors using the same sample persona on different installations must not share memory. IP is never a memory identity. Returning to the same browser/app installation restores local state; accounts/cross-device sync are future work.
7. Consequential actions require review of the exact proposal. Chat cannot approve; changed proposal details require new review. Plans are not completed behaviors.
8. Sample data is not the visitor's medical history. User disclosures are separate. Provider tasks, source posts and sponsored offers must not be portrayed as clinically verified facts.

### Owner decisions needed before production

| Decision | Why it cannot be safely assumed |
|---|---|
| Launch regions, age limits, clinical scope and intended use | Determines privacy, medical-device/clinical obligations, crisis routing and disclosure requirements |
| Consumer-only vs clinician/organization tenancy | Changes account model, patient access, delegated caregiver/clinician permissions and contracting |
| Identity provider and account recovery | Local device UUID is not authentication; decide guest-to-account migration and shared-device behavior |
| Hosting/region, data retention, backup recovery and encryption ownership | Must fit health-data obligations and vendor agreements |
| Provider record integration partner and supported organizations | No actual provider OAuth/FHIR authorization or production data contracts are bundled |
| Permitted external actions and vendors | Ride/payment/pharmacy/portal work requires supported APIs, contracts and auditable confirmations |
| External portal backend ownership | Native client references a different deployed project; server source/access is not in this repo |
| Consent/default policy for real health data, voice and memory | Need consent versioning, withdrawal semantics, processing disclosures, and a visible onboarding surface |
| Monetization, billing limits and operating budget | Current rate counts are not dollar caps or customer entitlements |
| Asset licenses and distribution rights | Font/music/reference-media ownership cannot be inferred from bundled bytes |
| Android scope and desktop scope | Existing web-on-Android is not a native Android product; current desktop view is a phone-width column |

Do not block all engineering while waiting for decisions: implement adapter interfaces, tests and disabled/unavailable states. Do not replace missing approvals/credentials with fake success.

## 3. Current architecture and ownership

### Native iOS

Entry: `ios/Nudge/NudgeApp.swift`, `ios/Nudge/ContentView.swift`, `ios/Nudge/Views/RootView.swift`.

- `ios/Nudge/ViewModels/AppModel.swift`: large observable app model, fixture initialization, route/presentation flags, patient/pathway switch, logs, reports, care actions and local persistence. It owns `AIPrivacy`, `CompanionEngine`, `LiveSupportService`, sample runner and portal companion.
- `ios/Nudge/ViewModels/CompanionEngine.swift`: conversation turns, generation epoch/cancellation, prompt building, text/voice replies, tag parsing and quote-backed reflection. `configure`, `restore`, `reset`, `ask`, `voiceReply`, `reflect`, `systemPrompt` are central migration points.
- `ios/Nudge/Services/CompanionAI.swift`: URLSession text-only SSE client; private provider key is not on device.
- `ios/Nudge/Services/AIPrivacy.swift`: UserDefaults choices and Keychain install ID. Defaults apply only when no persisted Boolean exists.
- `ios/Nudge/Services/PersistenceService.swift`: one main JSON user-data file; not a multi-patient database.
- `ios/Nudge/Services/ProfileMemoryStore.swift`: separate local JSON memory/transcript per pathway, latest 40 finished turns. Native SavedTurn only stores role/text; rich cards and original IDs are not restored.
- `ios/Nudge/Services/LiveSupportService.swift`: local live-observation history/frequency limits, quiet hours, evidence validation.
- `ios/Nudge/ViewModels/BrowserDemoModel.swift`: sample task state/timer, not a real browser agent.
- `ios/Nudge/Services/CompanionModel.swift`, `AgentSession.swift`, `AgentBridge.swift`, `BrowserView.swift`, `BrowserProtocol.swift`, `PortalActionPolicy.swift`, `PortalOrigin.swift`, `PrivateAccessConnection.swift`, `PortalKeychainStore.swift`, `DeviceSignIn.swift`: separate connected browser/portal transport and local policy boundary.
- `ios/Nudge/Resources/agent-bridge.js`: injected observation/action implementation; security-sensitive, not decorative frontend script.

The project uses synchronized Xcode folders and default MainActor isolation, with a Swift language setting of 5.0 in the current project. Use explicit concurrency boundaries; do not confuse that language setting with the minimum SDK needed for iOS 26 APIs. Review Codable isolation when moving work off main actor.

### Web

Entry: `web/src/main.tsx`, `web/src/App.tsx`, product root `web/src/sano/SanoApp.tsx`.

- `web/src/sano/store.tsx`: large React provider, UI state, prompt construction, mutations, persistence, live support, and autonomous runner. Uses local state/context despite a React Query dependency elsewhere; installed packages do not mean server-state architecture already exists.
- `web/src/sano/types.ts`: frontend domain model; `fixtures.ts`, `careBundles.ts`, `demoPatient.ts`, `agentNetwork.ts`, `recipeCollection.ts`: sample content and local workflow helpers.
- `web/src/sano/ai.ts`: `/~api/ai/chat` SSE, holdback filter and rich tags. Exports some legacy toolkit config; primary AI is direct through the own backend.
- `web/src/sano/device.ts`: install UUID, profile-specific memory keys, restorable transcript filter.
- `web/src/sano/aiMemory.ts`: quote-backed candidate validation and usable-memory filtering.
- `web/src/sano/aiSupport.ts`: structured observation/evidence validation, quiet-hour and distress helpers.
- `web/src/sano/browserDemo.ts`: pure sample reducer. Root provider timers keep it moving while workspace UI is minimized. It is not durable after page close.
- `web/src/sano/screens/BrowserDemo.tsx`: task presentation, popup/pinned approval, followups and previews; `screens/AgentNetwork.tsx` retains additional legacy agent/tool surfaces.
- Product navigation is mostly view state, not a complete URL-router/deep-link contract.

### Backend

`functions/index.ts` is a Cloudflare worker entrypoint; `functions/rumi-ai.ts` exports `RumiBudget`, input validation, safety precheck, Anthropic stream transformation and model-status check. There is no patient database, authentication service, background task orchestration, provider ingestion, payment system, or production deployment IaC here.

```text
Web / native
  local sample context + entered text/logs + confirmed local memory
      → POST /ai/chat
          → input validation / narrow urgent phrase check
          → device → optional IP → global request reservations
          → Anthropic Messages stream
          → visible text SSE → client transcript

Microphone → POST /voice/stt → ElevenLabs → transcribed text
          → /ai/chat (voice purpose)
          → POST /voice/tts → ElevenLabs → audio playback

Sample workspace → local timer/reducer → local draft/proposal
          → exact-proposal review UI → local sample result

Connected native portal → separate external service + embedded WebKit bridge
          (not implemented by functions/)
```

## 4. Feature completion inventory

| Area | State and completed portion | Mock/partial/missing portion | Code to start with |
|---|---|---|---|
| Brand/UI/navigation | Implemented; web/native buildable | Visual/keyboard/accessibility acceptance incomplete, some parity differences | RootView, SanoApp and design reference |
| Artwork/audio/orb | Bundled media, fonts and native shader paths | Licensing not audited; generic art mappings remain; reduced-motion video lifecycle incomplete | asset audit, LifeModels, lifeLibrary, Orb components |
| Onboarding | Real intro and honest unavailable record-connection state | No production login, provider connection or import | native Onboarding views; web `screens/Onboarding.tsx` |
| Patient record/history | Rich navigable sample data for four pathways | No medical record backend or provenance pipeline | `PersonaFixtures.swift`, `MarcusFixtures.swift`, `CareHubFixtures.swift`; web fixtures/careBundles |
| Text AI | Real Anthropic path, Stop/errors, streamed text, history and system policy | Client supplies broad context; no account authorization, context provenance enforcement, formal clinical evals | CompanionEngine, CompanionAI; store, ai; rumi-ai |
| Voice | Recorder/transcription/reply/speech plumbing | End-to-end client acceptance, cancellation/permission races, temp-file cleanup, abuse protection missing | VoiceSession, web Conversation, functions/index |
| Memory | Quote validation, confirmation, edit/forget, aging filter, local profile separation | No identity-backed sync, full contradiction engine, comprehensive erasure, encrypted app-level store, tested backup semantics | ProfileMemoryStore, AIPrivacy, MemoryReviewView; device, aiMemory, store |
| Live nudges/insights | Dedicated panels, source IDs, limits, quiet hours, suppression, dismiss | Existing static insights remain fixtures; live cross-client/provider scenarios unverified | LiveSupportService and panels; aiSupport/store |
| Journeys/habits | Local interactive habit/garden flows | No complete durable server progress/event learning; no clinical validation of generated goals | Journeys views, AppModel/store |
| Visit prep/recaps/task explanations | General context conversation and prepared server purpose rules | Dedicated contextual orchestration largely unfinished; reports/recaps often deterministic/fixture-driven | purposeRules, buildReports, ReportsView, RecapPlayerView |
| Logs | Real local input for meals/movement/meds/symptoms | Not all state persists equally; no server sync, record reconciliation or sensor ingestion | QuickLog, AppModel/store |
| Recipe/activity agent | Web sample recipe selection, filters, week plans and image continuity; native sample activity plan | Fixed saved catalog/posts, not Instagram OAuth or autonomous web browsing; native breadth differs | recipeCollection, browserDemo, BrowserDemoModel, PlannedActivityView |
| Rides/appointments | Sample request/update/review/fare-change flows | No actual ride booking, live price, cancellation, reminders or provider appointment mutation | AppointmentsView, BrowserDemo, SampleRideCard, store |
| Portal-duplicative features (descoped Oct 6, 2026) | **Removed by owner decision.** Care-team messaging/inbox, requests tracker, medication refills/supply counts, bills/payments, wallet, copay/savings programs, documents vault, in-app appointment confirm/reschedule and direct report sending were deleted from both clients. Rumi complements the patient portal; Rumi Works (browser agent) performs these in the real portal/service after exact-proposal approval | Do **not** rebuild these as first-party features. Production work is the Rumi Works portal integration and its approval/receipt model | Care hub portal note; `shareThroughPortal` in web store and iOS AppModel; BrowserDemo/PortalWorkspace |
| Medications | Understanding and adherence only: purpose, schedule, guidance, watchlist, dose history, 30-day tide, symptom logging near a med | No refill state, supply counts or pharmacy actions by design | MedicationsView, MedDetailView; shared.tsx |
| Appointments | Read-only portal context for visit prep, trip plans and rides; telehealth join link | Confirm/reschedule route to Rumi Works in the portal | AppointmentsView; Care.tsx |
| Visit reports | Per-doctor drafted summary; “Send through my portal with Rumi Works” starts a portal task that requires approval | No direct delivery from Rumi | ReportsView; Care.tsx |
| Export | Native “Export everything” only toggles display state | Not a compliant export pipeline | PrivacyCenterView |
| Delete data/account | Some local file/key removal | No actual account; native deletion incomplete and in-memory state can repopulate files | PrivacyCenterView, PersistenceService, ProfileMemoryStore, AppModel |
| Hosted browser portal | Native client transport/bridge, allowlist and approval guards, policy tests | External backend/portal code absent; authenticated acceptance requires separate service and access | HostedEndpoints, AgentSession/Bridge, PortalWorkspaceView |
| Push/monitoring | Notification settings / in-app event-driven checks | No APNs entitlement/push service/closed-app monitoring guaranteed | Settings, LiveSupportService, store |
| Production operations | Rork build/deploy integration | No standalone deployment, migration/restore runbook, tenancy, alerting, SLOs, on-call or compliance evidence | rork.json, functions/package.json, Xcode project |

Do not label all rows “completed” because a UI exists. In particular, chat policy saying “demo only” does not automatically fix contradictory labels in care/agent-network views.

## 5. Current API contract and security limits

### Implemented routes

| Method/path | Input | Response/current notes |
|---|---|---|
| `GET /ping` | none | `{ok, now}` |
| `GET /ai/status` | none | `{available, model, reason}`; model metadata access cached about 5 minutes, not an inference completion test |
| `POST /ai/chat` | Header `X-Rumi-Device`; JSON consent/context/messages/purpose | Text-only SSE, no-store; validation/errors and request budgets |
| `POST /voice/stt` | Client multipart audio/model options | ElevenLabs proxy; currently no authentication/rate limit in this route |
| `POST /voice/tts` | JSON text, optional model_id/voice_settings | Fixed server voice, mp3 output; currently no authentication/rate limit or explicit text-size maximum |
| `OPTIONS` | CORS | Allows any origin, Content-Type/Authorization/X-Rumi-Device |

Web calls `/~api/...` on its own host; native uses `AppConfig.functionsURL`. Do not prepend `/~api` on a standalone backend unless its routing layer explicitly needs it.

Example chat request shape (not a credential):

```json
{
  "consent": true,
  "context": "Selected source-backed context; sample status explicit",
  "purpose": "conversation",
  "messages": [{"role": "user", "content": "Help me prepare a question for my visit."}]
}
```

Purposes: conversation, voice, reflection, nudge, insight, visit, task, recap. Default conversation. Server limits: context 22,000 JS characters; 1–16 messages; each 1–4,000; total message content 16,000; request text 40,000 characters; output 1,000 tokens; upstream timeout 55 seconds. These are mostly **post-read character checks**, not a streaming byte-size firewall. Clients send up to 14 recent messages; persisted history is longer. Account for Unicode, serialization overhead and oversize context before introducing real records.

Visible stream format is `data: {"choices":[{"delta":{"content":"..."}}]}` followed by `data: [DONE]`. Provider thinking/non-text deltas are not exposed. Interrupted/truncated output becomes an error. No error should be presented as successful provider action.

### Request reservations

Current limits: device **120/day, 8/min**; IP **400/day, 20/min** if `CF-Connecting-IP` is present; global **1,500/day, 40/min**. Counters reset by UTC day and fixed minute. A Durable Object instance stores counters for each scope. Sequential reservation is not an atomic multi-scope transaction; a later-scope denial can still consume an earlier reservation. Failed provider calls consume a reservation.

**Do not treat this as authentication or a hard spend cap.** The device header only matches a 20–64 character pattern. A caller can invent/rotate it; the validator cannot establish randomness or device ownership despite its comment. Client-side storage can be cleared. IP headers must be verified as platform-trusted; the code skips IP limits if absent. Raw IP is used in a budget object identifier: it is not a memory key, but is still privacy-relevant metadata. Decide minimization/hash/retention policy. The global count bounds chat requests, not vendor dollars or the unguarded voice routes.

### Safety policy: useful foundation, not clinical assurance

`rumiPolicy` constrains tone, sample provenance, action claims, clinical advice, prompt injection and allowed tags. `urgentReply` is a short English regex for some self-harm/emergency phrases and can miss indirect, multilingual, misspelled or context-dependent urgency, and can over-trigger on quoted/past events. It runs before ordinary coaching for chat/voice after basic validation. Never claim this is a validated triage system.

Reflection is restricted to quoted user evidence; inference hypotheses capped at .3. Ordinary facts capped at .8 until confirmation. Structured observation IDs must exist, but ID membership alone does not prove the generated claim follows from that evidence. Clinical/content evaluation and source linking are mandatory.

## 6. Memory, identity and persistence — exact boundaries

### What “per device” means today

- Web: `rumi.device.v1` in localStorage; memory key `rumi.profile.v1.<deviceId>.<pathway>`; general app state remains `sano.web.v1`. Origin/browser-profile isolation provides the boundary. Same browser profile on a shared device shares data. Private windows/clearing site data/new domains start new state. Guest memory does not sync across browsers.
- Native: Keychain `rumi-device-id` provides the request identifier; profile JSON files in this installation's private Documents container provide storage isolation. Filenames use pathway, **not the Keychain ID**. Backups/restore or cloned app containers are not covered by the simple “device-only” claim. Keychain IDs may outlive reinstall; JSON state typically does not. Verify actual backup and reinstall behavior before promising either.
- IP does not identify memory. Users behind the same NAT must not share personal content.
- “Profile” currently means a demo `CarePathway`: metabolic, oncology, procedure, cardiometabolic. It is not an authenticated patient ID; never use these four values as production ownership keys.

### Persisted vs transient

- Web profile state stores memory notes and up to 40 finished non-error turns, including web turn metadata. General localStorage holds many other logs/plans/threads/preferences. Only selected fields are persisted; do not infer total state restoration from the main provider.
- Native main JSON persists selected logs, entries, guides, memory, threads/requests/documents, paid bill keys and activity timestamp; per-profile memory JSON duplicates some memory notes and saves role/text transcript. Other UI state and derived fixtures are recreated.
- Existing native load code restores several arrays only if nonempty. An intentional empty array can be replaced with sample seed values on restart. The main JSON is for the active pathway, not a fully isolated per-patient ledger.
- Current memory-off behavior prevents reflection/use and transcript restoration/persistence as configured, **but does not erase all existing memory notes**. Disabling use and deleting storage are different operations. UI should explain this explicitly.
- A 45-day cutoff filters usability; it does not physically delete stored claims. Deletion must also cover transcripts, derived summaries and scheduled work in production.
- Best-effort storage silently ignores some decode/quota failures. Web type assertions are not runtime schema validation. No versioned migration/repair pipeline is implemented.

### Required invariants for production

Use principal/tenant/patient namespaces in every persisted key, SQL row, object key, task event and cache. Installation ID can be a guest namespace, never sufficient proof of account access. Authentication transitions must not automatically upload sample fiction as clinical history. Explicitly ask whether to migrate guest disclosures; record a merge/migration receipt.

Deleting/correcting memory must cancel generation/reflection, invalidate cached prompt/summary state, persist the new state, and block late responses from reinstating deleted content. Confirmed and inferred data must retain source/evidence IDs and revisions. Test switching profiles during text, voice, reflection and task completion; do not rely only on a stable-render unit test.

## 7. Priority defect and risk register

These are findings/required investigations, **not fixes made by this handoff**.

| Priority | Finding | Evidence / first fix |
|---|---|---|
| P0 before public paid endpoints | Voice routes have no route-level auth, budgets, strong size/type constraints or consistent timeout/cancellation policy | `functions/index.ts`; centralize request principal and usage reservation for every billable route |
| P0 before real data | No authenticated ownership/tenancy | AI device header is spoofable; all persisted personal data is local guest state; implement account/guest session service and authorization tests |
| P0 before privacy claims | Native export button does not produce a real export | `ios/Nudge/Views/Settings/PrivacyCenterView.swift`: `exported` changes UI only; implement versioned export artifact/share flow |
| P0 before erasure claims | Native delete removes files but not all in-memory state, UserDefaults, Keychain, live-support data, photos/audio/other derivatives | PrivacyCenterView and AppModel; implement one cancel→wipe→reset coordinator and test no resurrection after another write/relaunch |
| P0 before actions | Local methods still mark messages/requests/payments/reports/tasks sent/done without external service evidence | `web/src/sano/store.tsx` (`sendThreadMessage`, `sendReport`, `confirmAppointment`, `enroll`, `payBill`, agent actions); `ios/Nudge/ViewModels/AppModel.swift` equivalent methods; return explicit simulation results or provider receipt states |
| P0 before health deployment | Disclosure/permission copy conflicts with processing | Xcode microphone usage text says words go “nowhere else” despite external speech service; Settings says AI is on even after opt-out; fix truthfulness and review consent lifecycle |
| P0 before healthcare release | No documented clinical safety/regulatory/vendor agreement acceptance | Prompts/regex/tests are not compliance; require qualified review and appropriate vendor contracts |
| P1 | Memory persistence/deletion/switch behavior incomplete | Duplicate native stores, skipped save while streaming, persisted empty-array restoration, no schema migrations; integration tests needed |
| P1 | Voice cancel/permission/background lifecycle | Native permission-await can race Stop; temporary recording retention; web async listening/transcription/playback and cleanup paths require race tests |
| P1 | Native voice completion versus epoch changes | Ensure old voice work cannot append to the wrong patient or save after switch/opt-out; CompanionEngine/VoiceSession |
| P1 | Text/structured AI input/error robustness | Long typed input or context can exceed server bounds, JSON reflection parsing differs across platforms; retry UI/error categorization and validation needed |
| P1 | Local-only runner presented as durable work | Root-owned execution survives view dismissal, not app suspension/termination; migrate task truth to server jobs |
| P1 | Hosted portal dependencies absent | `HostedEndpoints.swift` has fixed external hosts; separate repository/contract access required; do not silently redirect to an arbitrary origin |
| P1 | Accessibility/visual gaps | Video Reduce Motion, sheet focus/Escape, smaller hit targets, chart keyboard/empty-state handling, dynamic type and keyboard approval reachability |
| P1 | Asset licensing/content mismatch | No supplied license inventory; vegetarian labels and activity images can be semantically wrong despite existing files |
| P1 | Platform portability | Generated ignored Config.swift, Rork-only `/~api`, nonstandard DO dispatch, no Wrangler deployment; implement reproducible setup |
| P2 | Sound consistency/performance | Native silent-mode/recap mute semantics, web refresh-rate-based fade and concurrent fade races, background media suspension |
| P2 | Historical source drift | UI names vs source names, old opt-in/code-gate plan checkboxes, old specs and misleading success strings; maintain a single current status inventory |

## 8. External integration and portability requirements

### Rork → standalone deployment

1. Keep frontend contracts while introducing a portable backend base/proxy. Local Vite must proxy `/~api` to a local worker (strip prefix) or use an explicit public API URL. Production web should prefer same-origin routing; CORS is not authentication.
2. `env.DO.fetch` with `X-Rork-DO-Class` / `X-Rork-DO-Id` is Rork's dispatcher. A standard Wrangler Worker does not automatically provide this binding. Port to a named `DurableObjectNamespace` (e.g., `RUMI_BUDGET`), deterministic IDs and `get(...).fetch(...)`, or implement an explicit adapter. Keep the budget class exported. Add config, compatibility date, bindings and SQLite class migration to the chosen deployment IaC.
3. `functions/package.json` has no standalone runtime/deploy toolchain. Add pinned tooling/types/test harness, local development, migrations and CI after selecting hosting. Merely copying functions/index.ts is insufficient.
4. Supply public native build config as described in README, secrets only in backend secret stores. Configure separate development/staging/production endpoints; remove hardcoded fallback reliance.
5. Review Xcode bundle ID, team, permission text, privacy manifest, capabilities, icon, export compliance and signing for the owner's organization. No native push/HealthKit/Sign in with Apple capability is implied by a settings switch.
6. Preserve all media and exact case-sensitive paths. `web/public` copies verbatim into dist; changing an existing asset requires a new versioned filename to avoid stale caches. No external generated-asset URL should be required for bundled UI artwork.
7. Separate service account ownership and observability for Anthropic and ElevenLabs. The currently fixed voice ID must be available/licensed in the deployment account. Test STT multipart headers (the proxy currently forwards the body without explicitly preserving the incoming multipart Content-Type boundary), payload caps and upstream errors.

### Connected portal / browser service

`ios/Nudge/Services/HostedEndpoints.swift` points at a separate Linden portal preview and `care-pilot-backend.rork.app`. These are dependencies, not code supplied in `functions/`. `PortalWorkspaceView` invitation code is separate from the removed AI preview code; store it in Keychain, not model context.

Obtain the external repository or documented protocol, deployment ownership, test credentials, allowed origins, sandbox behavior and authorization contract. Reuse `BrowserProtocol`, `PortalOrigin`, `PortalActionPolicy`, `AgentSession`, `AgentBridge`, `BrowserView` and `agent-bridge.js` as a client contract/security reference. Do not claim an authenticated flow has passed from local bridge tests alone. Prefer supported provider APIs where available; browser automation must respect user authorization and provider terms, and must never circumvent access controls.

### Not included in Git

Secrets, Apple signing assets, vendor accounts, deployment database/counters, production records, the external portal server, and runtime user data are not part of this code handoff. The historical plan mentions PDFs/Word-derived factor catalogs, but no tracked `.pdf`/`.docx` inputs were found in this audit. Obtain the original source material from the owner before implementing its exact taxonomy; do not reconstruct it from a plan summary.

## 9. Proposed production architecture — not yet implemented

Start with one deployable backend and a clearly separated domain layer rather than prematurely splitting into many services. A practical option is Cloudflare for API/streaming/queues and PostgreSQL for identity-linked relational data, with private object storage for documents. This is a recommendation, **not an existing approved vendor decision**; confirm tenancy, region and health-data requirements before provisioning.

### Modules

- **Identity/session:** account, guest session, trusted device session, OAuth/OIDC login, refresh/revocation, role/tenant/patient authorization, audit context.
- **Profile/care data:** normalized records with immutable source provenance; FHIR adapters if the selected partner supports them; patient-match review; observation units and timestamps preserved.
- **Personal memory:** evidence-backed claims, source turns, confidence/state, expiry, contradiction/supersession, corrections and erasure propagation. Separate from clinical record facts.
- **Conversation/AI gateway:** authenticated server-built minimal context, purpose templates, model policy/version, safety screening, stream session, cancellation, cost accounting, failure states. No universal tool authority granted by model text.
- **Task orchestrator:** durable task state, bounded tools, persisted events, proposal generation, approval binding, retry/idempotency, provider receipts and reconciliation. Client only renders/requests authorized transitions.
- **Integration adapters:** provider records, messaging, appointments, rides, payments, pharmacy, media import; explicit sandbox/live modes and credentials per environment. No fake success adapter in production mode.
- **Notifications:** user consent, quiet hours/timezones, categories, quotas, dedupe and distress suppression; APNs/web delivery with receipt/error handling. In-app support first, no assumed always-on monitoring.
- **Files/export/privacy:** signed uploads, MIME/size validation, malware checks, retention, access logging, export jobs, deletion jobs and verified completion.
- **Operations:** secrets, migrations, structured redacted telemetry, cost controls, audit events, alerting, backups/restore, rollback and provider outage playbooks.

### Proposed data model

All tables below need stable opaque IDs, timestamps, schema migrations and explicit ownership. Never use display name, IP or demo pathway as an authorization boundary.

| Entity | Key fields / invariants |
|---|---|
| principals / memberships / patient_access | user, tenant, role, patient relation, status; query-time authorization |
| sessions / installations | revocable session, user or guest namespace, expiration; install ID is metadata, not bearer authorization |
| patients / profiles | source linkage, demo/live marker, timezone, version; demo data cannot masquerade as imported clinical history |
| consents | purpose, scope, policy version, granted/withdrawn time, source; processing checked server-side |
| source_connections | provider, scopes, status, sync cursor; encrypted credential reference, never raw tokens in model context |
| clinical_records / observations | patient, source ID, code/system, value/unit, observed time, received time, provenance, version |
| life_entries / symptom_logs | patient/principal, user-entered vs imported origin, event time, revisions; planned and completed separate |
| conversations / turns | ownership, purpose, role, content, stream status, retention, model/policy version; redacted audit metadata separate |
| memory_claims / evidence_links | text, fact/hypothesis, confidence, pending/confirmed/rejected/deleted/expired, source quote/turn, expiry, supersedes |
| journeys / habits / completions | accepted goal, source care constraint, schedule/timezone, idempotent completion event; no score from fixture assumptions |
| insights / interventions / feedback | evidence snapshot, generation version, shown/dismissed/snoozed/accepted/completed events, limits |
| tasks / task_events | actor, patient, tool, state/version, durable event sequence, cancellation, retry history |
| proposals / approvals | canonical payload, version/hash, recipient/cost/time constraints, expiry, authorized actor, one-use status |
| executions / provider_receipts | proposal hash, idempotency key, provider transaction ID, pending/confirmed/failed/unknown status |
| documents / exports / deletion_jobs | private object key, access policy, checksum, scan status, retention, job receipt |
| usage_reservations / audit_events | principal/tool/model cost metadata; no sensitive transcript in ordinary logs |

### Proposed API families

Design an OpenAPI/typed schema and generate/test TS/Swift DTO parity. Preserve existing streaming clients through a compatibility adapter while migrating.

- `/v1/session`, `/v1/me`, `/v1/patients`, `/v1/consents`
- `/v1/conversations`, `/v1/conversations/{id}/turns`, cancel/stream routes
- `/v1/memories` with confirm, correct, forget and deletion-status operations
- `/v1/logs`, `/v1/journeys`, `/v1/insights`, feedback events
- `/v1/connections` and provider OAuth callbacks with state/PKCE where supported
- `/v1/tasks`, event stream, `/proposals/{id}/approve`, decline, cancel
- `/v1/documents`, `/v1/exports`, `/v1/deletion-jobs`
- Private provider webhooks: signature/replay verification, idempotent intake, trusted event mapping

Do not accept arbitrary client patient IDs/context blobs as proof of authorization. Use actor context from a verified session and enforce object ownership on every request, including streams/files/tasks and cross-tenant lookup failure paths.

### Consequential action state machine

```text
draft → gathering → proposal_ready → awaiting_approval
  → authorized → executing → confirmed
                         ↘ failed / unknown_requires_reconciliation
awaiting_approval → declined / expired / superseded
active task → paused / cancelled (as supported by provider)
```

Canonical proposal binds action type, target/recipient/provider, patient, payload, price/currency/fees, schedule/timezone, destination and relevant page/form fingerprint. Approval records actor, hash/version and expiry. Server atomically consumes approval once and issues a deterministic idempotency key. Rebooking/cancellation and changed prices are new proposals. Timeouts after submission are **unknown**, not automatically safe to retry. Reconcile with provider receipts before another charge/send. Model output is a draft suggestion, never execution authority.

## 10. Implementation milestones and definition of done

### M0 — reproducible baseline and design freeze

- [ ] Clone with all media; pass asset audit; verify connected GitHub mirror separately if used.
- [ ] Make standalone web/native configuration and backend development runnable without secret source edits.
- [ ] Re-run baseline tests/builds, record toolchain versions and actual failures.
- [ ] Capture visual fixtures for the design checklist, lock source asset mappings, obtain licensing evidence.
- [ ] Add a single real/demo mode boundary; retain clearly labeled demo for development.

**Done when:** clean checkout runs with documented setup, missing services fail honestly, assets render, tests are reproducible, and screenshots provide a before-refactor baseline.

### M1 — close immediate security/privacy defects

- [ ] Authenticate/rate-limit all billable routes; enforce streamed upload/body/type limits and upstream timeout/cancellation.
- [ ] Implement honest export/deletion, correct permission/disclosure strings, remove false delivery/payment copy.
- [ ] Add memory/privacy race tests, fix storage migrations/empty-state restoration, define retention/backup policy.
- [ ] Add provider spend alerts/caps and kill switches; do not rely only on request count.

**Done when:** no unauthenticated/unbounded paid route, no fake export/delete receipt, and no post-delete/switch response can restore private data.

### M2 — identity and durable user data

- [ ] Account/guest sessions, authorization, patient access model, revocation and recovery.
- [ ] Database migrations, tenant isolation tests, secure object storage.
- [ ] Guest-to-account migration with explicit consent and separation of fictional records.
- [ ] Offline/cache/sync conflict policy and correct account-switch cleanup on both clients.

**Done when:** two users on same IP/device/account-switch sequence cannot read or mutate each other's records, and own authorized cross-device state returns with complete audit history.

### M3 — production AI and voice

- [ ] Server-owned minimal context assembly, source/age filters, model and policy versions, structured-output validation.
- [ ] Fully wired purposes: chat, voice, memory, live support, visit prep, recap, task explanation.
- [ ] Stream errors/retry/cancel, voice capture/transcription/playback interruption and temp-data cleanup.
- [ ] Clinician/content-reviewed safety and prompt-injection evaluation suite, multilingual/location-appropriate escalation as scoped.
- [ ] Accurate consent withdrawal and per-user budget/latency telemetry without sensitive logging.

**Done when:** live tests pass on both clients, responses are grounded, unsafe/unsupported claims are caught, withdrawal stops processing, and outage behavior is honest.

### M4 — real care integrations

- [ ] Approved provider authorization, record sync/provenance, revoked/expired token recovery and reconciliation.
- [ ] Messaging, appointment changes, refills, bills and payments are performed only by Rumi Works inside the patient's own portal/service, with exact-proposal approval and a verifiable receipt. Rumi does not host these features itself (descoped Oct 6, 2026).
- [ ] Documents and provider evidence connected to care views and AI context.
- [ ] Replace local “sent/paid/connected” flags with backend status/receipts.

**Done when:** provider sandbox acceptance then controlled live acceptance proves real integration outcomes and idempotent webhook processing. Unsupported vendors remain unavailable, not simulated under a live badge.

### M5 — durable assisted tasks

- [ ] Server task execution/events, resumable UI, constrained tools and provider adapters.
- [ ] Exact proposal hash/version approval, expiry/supersession, replay prevention and atomic consumption.
- [ ] Cancel/retry/unknown-outcome reconciliation, cost changes, provider errors, audit timeline.
- [ ] Connected portal service contract validated or replaced through an approved migration.

**Done when:** duplicate taps/retries/reconnects cannot duplicate a charge/send, and every consequential result has an authorized proposal plus verifiable receipt.

### M6 — product completeness, QA and release

- [ ] Durable logs/journeys/feedback, production nudges and optional notifications with timezone/quiet-hour rules.
- [ ] Full design and accessibility matrix, reduced-motion/media lifecycle, artwork correctness, responsive/keyboard reliability.
- [ ] Real-device and signed Release checks, privacy disclosures/manifests, store metadata/screenshots.
- [ ] Restore drills, alerts/runbooks, support escalation, rollback and environment isolation.
- [ ] Owner, security and relevant clinical/legal acceptance documented.

**Done when:** production readiness checklist is evidenced, not inferred from successful compilation. Enable live services gradually behind flags with rollback.

## 11. Test strategy and acceptance scenarios

### Handoff validation run (October 2, 2026)

- `python3 tools/audit-handoff.py`: passed; 345 tracked asset/reference files, 294,750,585 bytes, no audit failures.
- `bun run test` from web: 55 tests across eight files passed. Existing React `act(...)` warnings appeared in autonomous-workspace tests; no fixes to application/test behavior were made in this documentation task.
- Rork web static checks and build: passed.
- Native tests/build, live AI smoke and backend deployment: prior implementation evidence only, not rerun here because application behavior was unchanged. Do not present those as fresh end-to-end results.

### Existing suites to preserve

- `web/src/test/aiPrivacy.test.ts`: AI disabled behavior, SSE, unsafe action tags, memory provenance and support rules.
- `web/src/test/autonomousWorkspace.test.tsx`: root-runner flows, local plans and memory separation/defaults.
- `web/src/test/browserDemo.test.ts`: reducer progression/approval.
- `web/src/test/companionNavigation.test.tsx`: navigation and approval visibility.
- `web/src/test/nativeBrowserBridge.test.ts`: bridge-side policy behavior in a JS test environment, not authenticated provider acceptance.
- `web/src/test/onboarding.test.tsx`, `web/src/test/calendar.test.tsx`: scoped UI behavior.
- `ios/NudgeTests/NudgeTests.swift`: native sample states, no chat authorization, memory usability/profile store/defaults.
- `ios/NudgeTests/PortalIntegrationTests.swift`: local portal policy/integration boundaries.
- `ios/NudgeUITests/NudgeUITests.swift`, `ios/NudgeUITests/NudgeUITestsLaunchTests.swift`: separate UI targets; don't imply execution from a NudgeTests-only run.

Do not import prior test counts as a new run result. Some test helpers mutate global UserDefaults/localStorage; isolate tests and avoid order dependence. Add backend tests with an appropriate Cloudflare/DO harness; none of the above proves budget atomicity or deployed HTTP security.

### Required negative and lifecycle scenarios

1. Two guest browsers using Marcus on same Wi-Fi; different users on same device after logout; same account on different devices; denied cross-patient/tenant access.
2. Memory candidate from assistant text rejected; invented quote rejected; conflicting claims require resolution; stale claim excluded; no sensitive demographic inference.
3. Forget/correct/off during reflection, streaming, voice and profile switch; then reload, background, restore and sync. No resurrection from old transcript or derived summary.
4. AI/body timeout before stream, partial SSE, malformed event, token truncation, long Unicode input, network loss, rate-limit day/minute error and provider outage.
5. Voice permission pending→Stop, denied permission, long silence, route interruption, STT invalid multipart, oversize audio, playback cancellation and object-URL/temp-file cleanup.
6. Prompt injection in page/post/document/history demanding credentials, policy override or “approve now”; cannot bypass authorization or expose secret context.
7. Urgent symptoms/self-harm language variants, ambiguity/past events, multilingual cases in scope, refusal/no coaching, distress suppression and appropriate human escalation.
8. Exact proposal visible outside scroll; Review later blocked; fare/recipient/form/time changes supersede; duplicate Approve or replay rejected; price not silently changed.
9. Provider timeout after possible side effect: reconcile, do not submit twice; webhooks duplicated/out of order; cancellation of existing task distinguished from cancelling a booking.
10. Export includes all entitled data/provenance; delete cancels jobs, erases retained data per policy and produces receipt; logs/backups follow documented retention limits.
11. Empty lists stay empty; persistence corruption/quota reports recovery; sample seeds never repopulate a live patient.
12. Every app state in the visual checklist, static bundled media offline, fonts loaded, no unexpected third-party image requests.

## 12. Historical references and precedence

- `LEGACY_REQUIREMENTS.md`: original broad product/design requirements; not a completion ledger.
- `Nudge_iOS_Build_Spec_v4.md`: native design/build specification; predates current Rumi branding and recent changes.
- `tmp/Nudge_v3_spec.md`, `tmp/v5_spec.md`: historical versions, not independent implementations.
- `.rork/plans/rumi-s-live-ai-companion-memory-and-calm_1790790019362.plan.md`: current feature-plan history and unfinished goals. Earlier default-off/preview-code checkboxes document superseded work. Current defaults and limitations in this handoff take precedence for implementation status.
- `.rork/plans/rumi-a-calmer-companion-that-helps-you-a_1790777698682.plan.md` and `.rork/plans/rumi-polish-wave-per-doctor-reports-agen_1781635178188.plan.md`: preceding product iterations.
- `tmp/assets/` and `tmp/ref2/`: visual/media references, not evidence of functional integration or licensed redistribution rights.

Keep `.rork/history/` untouched and tracked; Rork owns that state. Do not clean it away in a portability pass. Do not include private history in a public export without owner review.

## 13. Copy/paste brief for Codex

```text
You are taking over the Rumi repository to build a production native iPhone app,
mobile web app and backend. Read README.md, PRODUCTION_HANDOFF.md,
DESIGN_REFERENCE.md and ASSET_AUDIT.md in that order, then inspect the actual
source files they reference. Do not assume historical completion claims are
production acceptance.

Preserve Rumi's current design: Today/Care/You, centered orb dock, root-owned
log button, readable frosting, typography, clay assets, living gradients,
orb video/shaders, gentle motion/audio, and exact-proposal review outside chat.
Do not replace this with a generic dashboard or rewrite the whole UI.

Start with M0 and M1: make a fresh checkout reproducible, capture a visual
baseline, close unprotected paid voice routes, fix truthful export/deletion
and action status, and test privacy/cancellation/profile isolation. Then
implement identity, durable data, server-built AI context and voice, approved
provider integrations and durable task execution in validated milestones.
Use typed adapters so demo and live implementations cannot be confused.

Keep Anthropic server-side by default and use Rumi AI product branding. Verify
the configured model/API in the deployment account; never silently switch
models. Keep secrets out of source, client bundles, logs and model context.
Honor owner-approved demo defaults while obtaining review of production
health-data consent, retention, licensing and provider agreements.

Do not use IP or demo persona as user identity. Implement principal/tenant/
patient authorization, guest migration and cross-device continuity deliberately.
Chat/model/page text never authorizes external actions. Approvals must bind
exact proposal versions, expire, be single-use and have idempotent provider
execution plus receipts/reconciliation.

Work incrementally, keep both clients aligned, run unit/integration/UI and
security tests at the appropriate layers, and update this handoff with actual
commands/results. A passing build is not end-to-end proof. Do not invent
credentials, vendor access, clinical approval or missing external portal code.
Ask the owner for decisions/access when necessary and keep unsupported live
features visibly unavailable. Preserve all bundled assets and Rork state.

For each milestone report: implemented code paths, remaining demo paths,
validation evidence, visual parity impact, security/privacy implications and
owner dependencies. Ship only after the documented acceptance gates pass.
```

The brief is model-agnostic: it can be given to the user's chosen Codex model without relying on a particular model name or claiming capabilities of that model.
