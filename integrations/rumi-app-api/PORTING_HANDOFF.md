# Rumi insights and existing App API: collaborator handoff

Prepared October 29, 2026. Primary scope: the simplified native `ios-rumi` app, not the larger `ios` UI. A simplified web port now exists as described below; native validation evidence does not transfer to it. Preserve the designer's chat-first navigation, menu, Health screens and mint/forest-green styling. This is a portable implementation, not a claim of production activation or complete backend-PR parity.

### Web port checkpoint

- `web/src/App.tsx` serves `web/src/rumi/RumiWeb.tsx` at `/`; the older `Index` remains at `/original/*`. No backend changes or native changes were required.
- `model.ts` ports the three isolated fixtures, strict query validation/calculations and exact sample pantry/cart arithmetic; `ai.ts` uses the identical prompt and exact Sonnet model with consent, no fallback and host-calculated insight facts. `InsightCard.tsx` exposes SVG charts plus keyboard-accessible date/value rows. `rumi.css` scopes the native-inspired atmosphere and responsive controls.
- `Account.tsx` implements the published owner-confirmed API directly with browser fetch, memory-only tokens, coalesced identity-checked refresh, verified challenge flow, read-only inspection and exact reviewed goal writes. It never uses server/provider credentials. Browser access needs existing-service CORS authorization. Dismissal clears local access but is not remote logout. Requests already dispatched may complete upstream even if aborted locally. Unknown goal outcomes require checking goals, never automatic replay.
- Web voice is explicitly browser dictation, not realtime AI. Real-source recipe extraction/cart review and model-proposed reader navigation remain native-only; web supports public-source questions subject to CORS and separate seeded mock cart journeys. No cross-device/demo/account synchronization is implied.
- Web static checks/build passed and one phone-sized welcome render was inspected. No web functional tests, live AI, microphone, authenticated API or comprehensive accessibility acceptance was performed. The portable native patch below has not been regenerated to contain web files; it remains a pre-web artifact.

## 1. Sources and provenance

- PR attachment: https://r2-pub.rork.com/attachments/7ccpbnhcs83uypksx8wno.pdf — 23-page summary/review of `amalgam-rx/aiservice_chat_server` PR #62, **AIAS-45 Clinical insights, care follow-ups and coaching after a data answer**, `insights-tools` into `master`, 43 commits. It describes 73 changed files but does not contain that full source diff. The behavior was implemented natively; no unseen Python implementation was copied or claimed merged.
- Swagger UI: https://rumi-api-amber.vercel.app/
- Snapshotted specification: https://rumi-api-amber.vercel.app/openapi.json
- Alternate specification: https://egoicdonmuudwvbsockm.supabase.co/functions/v1/rumi-app-api/openapi.json
- `openapi.json` in this directory is the published Swagger variant. SHA-256: `05393d3a2d03dee6bf3812edafb435abf235cde07cb95b9f9a1b820cf5096dea`.
- Important discrepancy: Swagger advertises HTTPS `https://egoicdonmuudwvbsockm.supabase.co/functions/v1/rumi-app-api`; the Supabase-hosted spec advertises HTTP and omits `/functions/v1`. Their paths/components matched in the public checks. Never adopt the HTTP URL. The owner has now confirmed the full HTTPS URL above and public AppId `50594005-ee06-4087-abdf-733596f001e6`. They are bundled as defaults when no valid saved settings exist; saved custom settings/sessions are not overwritten. No network request or login is triggered by initialization. A documentation origin is not automatically an API base URL.
- Requested source tree: https://github.com/aahalife/rumi/tree/main/backend/app-api. Its new contents were unavailable to this workspace; raw README lookup returned 404. The local `linked/rumi` snapshot remains `da7fdc4dca5f1913a35bd17deedff12824f0fc1d`, not a verified copy of that new API source. Do not infer its internals from the contract.
- Existing portable destination: https://github.com/aahalife/rork-rumi-research-preview at unchanged baseline `2a6a5e0`. This is distinct from the production backend repository.

## 2. Product behavior delivered

From onboarding, select the **Primary demo member**, Maria or Tom, then Start demo. From an empty demo chat, open **Insights walkthrough**. It offers real Sonnet request buttons plus an explicitly separate **Calculated preview · No AI request**. Preview is a deterministic chart, never a prerecorded model reply. Existing messages can retain chart cards after relaunch.

Example live requests:

- Primary: “Show my A1c and eGFR side by side, and also my latest LDL.”
- Maria: “Show my A1c and weight side by side.”
- Tom: “Show my steps and sleep side by side over the last 14 days.”
- “Show my last 4 A1c results. If fewer exist, show only those available.”
- “Compare my A1c with people like me and show my CGM time in range.” This must disclose missing data, not fabricate a comparison or CGM result.

A data reply contains app-calculated dated facts and inline charts, then one invitation to discuss a goal. Accepting with Yes/Yes please/Sure/Okay/Ok generates the labelled host question, “What would you like to work toward, in your own words?” Subsequent free-form conversation uses Sonnet. Plain number mentions and device trouble are not automatically data requests. No unsolicited advice is authorized by accepting an invitation.

Care follow-ups are **seeded local rehearsals**, not active orders imported from the API. Refill, referral and lab questions open an exact-question/selected-answer review. Confirmation writes a local unsent receipt only; Cancel writes none. No drug is discontinued, provider searched, referral created, lab ordered/booked, calendar accessed or message sent. Reviews are bound to member and revision.

## 3. Dependency and ownership map

- `ios-rumi/Rumi/DemoInsights.swift`: metric/query/observation/series/card contracts, deterministic `DemoInsightEngine`, native Swift Charts, walkthrough and care rehearsals. Depends on the existing demo session/member, theme and receipt interfaces. Uses platform SwiftUI/Charts only.
- `ios-rumi/Rumi/DemoMode.swift`: isolated member session and persisted demo turns, supplied-prompt overrides, exact model request, tool registration/validation, host facts/coaching, inline card placement and walkthrough routing. Existing trends now consume the same observations as insight cards.
- `ios-rumi/Rumi/DemoServices.swift`: previously implemented profile summaries and local service mock journeys; remains the profile/member dependency. Do not replace these with production records implicitly.
- `ios-rumi/Rumi/RumiAppAPI.swift`: independent verified-user API adapter. No demo observations, legacy Companion tokens or provider keys are used by it.
- `ios-rumi/Rumi/RumiAppAPIView.swift`: confirmed settings, health/config checks, verified phone challenge, read-only resource inspection, memory and exact real-goal review.
- `ios-rumi/Rumi/CompanionService.swift`: adds Account → “Rumi App API · Verified account”. The older Companion connection remains a distinct integration path, not silently migrated.
- `ios-rumi/RumiTests/RumiInsightsTests.swift`: deterministic facts, query bounds, intent and contract tests.
- `ios-rumi/RumiTests/RumiAPITransportTests.swift`: injected URLProtocol HTTP transport, coalesced refresh, rotated token use, error redaction and token validation tests. No real account requests.
- `ios-rumi/RumiUITests/RumiInsightsUITests.swift`: actual simulator interactions for primary preview/accessibility values and care cancellation.
- `tools/verify-rumi-app-api.py`: reproducible public read-only checks and specification/report refresh; no login challenge, personal session or write operation.
- `tools/export-rumi-works.py`: explicit allowlist portable patch exporter. It does not commit, push, merge or deploy.

The synchronized Xcode target folders automatically include Swift files. Current app deployment target is iOS 26; build service reports Xcode 27.1, Swift 5 language setting, default MainActor isolation. Do not assume the larger app's deployment settings apply. Preserve the destination's own supported availability guards if porting lower.

## 4. Query contract and calculation boundary

`DemoInsightQuery` has `operation`, `metrics`, optional `days`, optional `count`. Operations: `latest`, `trend`, `lastN`, `sideBySide`, `cohort`, `timeInRange`. Metric raw values: `HbA1c`, `LDL-C`, `eGFR`, `Weight`, `Sleep`, `Activity`, `BMI`, `CGM glucose`, `Time in range`.

Tool name: `read_demo_insights`. Arguments are exactly `{"requests":[{"operation":"trend","metrics":["HbA1c"]}]}`. Up to four queries; one metric except exactly two for sideBySide; unique metrics; days 1–3650, count 1–20; lastN requires count; timeInRange requires the Time in range metric. Unknown keys including patient IDs, model-supplied values and dates are rejected. Unknown metric names and empty envelopes fail closed. All queries validate before any card is appended.

The recognized explicit-data intent gate forces this tool using `tool_choice`; a missing tool call fails instead of displaying unverified numbers. Unexpected lookup calls outside the gate also fail. Sonnet chooses queries only. Model narration accompanying insight calls is discarded; the host computes and publishes numerical sentences and chart points. Multiple cards preserve independent dates and units, without causal/correlation claims. Nonvoice history includes calculated facts and guided coaching so subsequent turns can retain continuity. This is non-streaming tool selection with local progress labels, **not** implementation of the PR's backend `Insight`/`Status` event transport.

Clinical policy: **describe, never assess**. No good/bad, normal/abnormal, better/worse, inferred causes, invented reference ranges, targets, demographic percentiles or model-calculated numbers. A1c first-to-last change uses percentage points, not relative percent. Ordinary chat/voice policy is prompt-enforced rather than a proof of universal clinical safety; live-model safety evaluation remains required. The deterministic boundary protects the specific data-card path, not all possible natural-language model output.

## 5. Data, state and accessibility invariants

- Primary: supplied fictional A1c 9 → 8.8%, LDL 130 → 130 mg/dL, eGFR 60 → 55 mL/min/1.73 m². No name, age, weight, height or adherence invented. Chart offsets 270/70 days are explicitly illustrative, not actual lab dates.
- Maria: A1c 8.6 → synthetic intermediate 8.2 → 7.8%; weights 216.7 → synthetic intermediates 214.2/211.4 → 208.7 lb. Her independent fictional insulin/semaglutide orders remain separate from calculations and never derive from them.
- Tom: A1c 5.8%, sample weights 228 → 226.5 → 225.8 → 224 lb, 14 days of sleep/activity around 6.4 hours/4,800 steps. No Maria diabetes/insulin/GLP-1 context.
- No installed BMI, CGM, TIR or cohort dataset. Missing observations are not zeros. Requesting more results than available reports the shortfall. No height, threshold or synthetic comparison is substituted.
- Saved per-member anchor dates prevent fixtures moving every reopen. 30d/90d/All chart filters act on the returned query observations; All means all observations returned by that query, not an implicit new query. A query already constrained to 30 days may remain empty; submit an unconstrained query to widen it.
- Drag selects nearest returned point; independent side-by-side charts keep their units/axes. Large values, source/limitation text and expandable date/value rows support nonvisual access. Explicit accessibility containment keeps chart focus values reachable inside native List rows. Values honor device locale, including decimal commas.
- `DemoTurn.insights` and `invitesGoal` are optional Codable additions; old stored turns decode. The existing `rumi.isolated-demo.v1` per-member persistence remains, not a production database.
- Member/revision guards suppress late demo replies; switching/resetting ends pending work and invalidates care review. Never populate these stores from verified live account data. Do not promise encryption of UserDefaults demo fixtures.

## 6. Existing App API integration

### Supported now

Settings require confirmed full HTTPS base path and UUID public AppId. Requests preserve `/functions/v1/rumi-app-api`, add `x-rumi-app-id`, use per-user Bearer after verification and attach `Idempotency-Key` for reviewed goal saves. No `x-rumi-server-key` is ever sent from the app. The trusted-backend `/v1/auth/exchange` route is intentionally not exposed.

- Public `GET /health`, app-scoped `GET /v1/config`.
- Phone `POST /v1/auth/challenges`, resend and six-digit verify. `imessage_connection_needed` is disclosed; requesting a challenge does not prove ownership. Resending does not extend its original expiry. No phone challenge was sent during public checks.
- Keychain access/refresh session, `WhenUnlockedThisDeviceOnly`; nonsecret configuration in UserDefaults. No session token output in logs or handoff. Strict 64-character lowercase hex token validation.
- Expiring sessions use one coalesced refresh task; concurrent readers use the rotated token. Identity/version guards reject results after configuration/account changes; local disconnect cancels refresh. Failed refresh disconnects rather than silently using stale credentials. No blind replay of writes after 401.
- Ephemeral, no-cache/no-cookie production URLSession; redirects denied to protect authorization headers. Raw server error bodies are not displayed.
- Read profile, context, records, memory, goals, actions, visit-questions, call-preferences, connections, messaging/status and conversations. Loosely specified payloads use `RumiJSON`, preserving fields without interpreting medical meaning. This is a response inspector, not a completed records-to-charts adapter.
- Read memory and allow exact goal review only when returned permission is `granted`. `POST /v1/goals` sends text/quote with a per-review UUID. Success requires `committed == true`; HTTP 200/status ok/null committed is not proof. An uncertain result warns to inspect saved goals before retrying. Local cancellation cannot roll back a request already accepted upstream.
- Logout through the service or clearly separate local Keychain removal. Local removal does not revoke remote sessions or pause calls.

### Explicitly not connected

New App API ElevenLabs signed-session playback/text chat; PR event streaming; live care/referral/lab actions; provider searches/bookings; consent-change/record import/action-completion/call-preference writes; historical transcript synchronization; server-only credential exchange. The existing demo voice is GPT-Realtime 2, not new App API ElevenLabs acceptance. The published contract has no Insight/Status schema to map directly.

The demo blocks new App API requests/configuration and checks the guard again after transport completes. This does not undo a real write already dispatched before demo entry. UI identity/disappearance cleanup prevents stale response presentation; broader lifecycle/hostile-race acceptance remains open. Response-size checks occur after URLSession receives the body, not as a streaming memory ceiling. Goal uncertainty is UI state, not a durable cross-install transaction ledger; production retry/reconciliation deserves backend-supported receipt lookup.

No new backend, migration, provider change or infrastructure deployment was performed for this integration. Earlier `/companion/*` routes and migration tooling are historical/optional; **do not deploy or apply them merely to use the published App API**.

## 7. Validation evidence and limits

- Latest native automated run: **25 passed, 0 failed** via supported `swiftTest`, including existing tests, deterministic/query safety tests, mocked HTTP tests and two native UI tests. It exercised primary walkthrough navigation, 8.8% focus value and expanded earlier 9% values, plus exact care review and cancellation. The initial UI assertion exposed inaccessible List grouping, fixed with explicit containment; a later assertion was corrected to honor device decimal-comma formatting.
- API mocked transport verified concurrent reads refresh only once and use the rotated token, non-2xx response bodies do not leak into user errors, and malformed session tokens do not authenticate. This is not live token rotation proof.
- Public contract run: **7 checks passed** (`python3 tools/verify-rumi-app-api.py`). Health and config returned 200 with the Swagger-published public app ID; me/context/memory/goals/records/conversations all returned 401 without a user token; missing app ID returned invalid_app_id. Published paths/components matched between specification hosts. See `public-checks.json`. Public AppId is integration metadata, not a user credential. These checks prove only public reachability and unauthenticated enforcement, not per-user authorization or cross-account isolation.
- Simulator builds passed during implementation; final build/patch evidence is recorded in `PRODUCTION_HANDOFF.md`. A build is not interaction acceptance.
- Not exercised: live Sonnet query/tool selection, free-form coaching safety, live authenticated login/read/goal/refresh/logout, ElevenLabs sessions, microphone lifecycle, full three-member reset/isolation journeys, real-source recipe journey, chart drag/range UI automation, comprehensive VoiceOver/Dynamic Type/contrast audit, device/App Store Release. Do not mark those accepted from unit tests or one chart disclosure interaction.

## 8. Porting into the collaborator's redesigned app

1. Inspect the destination's navigation, state owner, styling and deployment target first. Preserve its designer-authored layout; do not overwrite an entire screen tree or project file with the portable patch. Use the patch as a reference diff on a separate feature branch.
2. Port the deterministic engine/query/observation contracts first. Adapt `DemoMember` and baseline ownership to the destination, keeping all three member datasets and explicit provenance. Add query tests before changing semantic behavior.
3. Embed `DemoInsightCard` within the destination's existing chat message rows. Retain source/limitations, independent units, empty recovery and accessible date/value disclosure. Map theme tokens rather than transplanting navigation.
4. Add optional persisted insights/invitation fields to the destination message type, preserving old decoding. Connect validated Sonnet tool routing and history serialization. Do not let the model provide points, patient IDs, ranges or clinical narration for cards. Keep exact requested model `anthropic/claude-sonnet-5.5`, no fallback.
5. Add the walkthrough through the existing menu/chat discovery. Preserve separate live-request versus no-network preview labels. Port local follow-up review with member/revision binding; do not wire a mock confirmation to a real mutation.
6. Port `RumiAppAPI` as a separate verified-account dependency and map its settings/review views into the destination's Account flow. Never reuse demo IDs or legacy Companion tokens as existing-Rumi authorization. Ensure Keychain service namespaces do not collide unintentionally between products; define app/user ownership for production multi-account support.
7. Use the owner-confirmed defaults above for this deployment; reconfirm settings for any different deployment. Use only an authorized test account; explicitly approve any challenge delivery and goal write. Keep server/provider keys out of the phone and source. Do not deploy old migrations as setup for this API.
8. Run deterministic, mocked-transport and UI tests in the destination, adapting the stable accessibility identifiers rather than exact English hierarchy assumptions. Then exercise the live checklist below. Do not infer parity from a clean patch application.

The portable patch also includes older browser/voice/Companion work for the baseline fork. Selectively port only needed dependencies. Review `functions/` and the SQL migration as **deferred legacy work**, not mandatory deployment instructions. The linked source repositories remain untouched; the patch does not assert a GitHub push/PR/merge.

## 9. Owner-assisted acceptance next

- HTTPS baseURL and public appID are now owner-confirmed and configured as app defaults. Next, identify a verified test user through the existing service. No provider/server keys should be pasted into chat.
- With consent, verify challenge delivery/status, code expiry/resend behavior, login, records mode and user-bound reads; test two authorized users for isolation and revoked/expired sessions.
- Review one exact goal, submit once with stable idempotency key, verify committed receipt and returned saved goals. Intentionally exercise uncertain network outcomes without duplicating writes.
- Exercise each live Sonnet example, missing-data/failure states, a worried number mention, accepting/declining the invitation, stopping/swapping member midrequest, relaunch/reset, and confirm no model-generated numerical narration bypasses the card boundary.
- Verify chart filters/drag and accessible values on large text/VoiceOver, including empty windows and side-by-side units.
- Scope and implement new App API ElevenLabs transport only after reviewing its permitted SDK/session options. Keep messaging/call ownership with the deployed backend; no competing provider cutover.
