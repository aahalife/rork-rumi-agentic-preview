# Rumi asset and repository portability audit

**October 2, 2026.** Related: [README](README.md), [design reference](DESIGN_REFERENCE.md), [production handoff](PRODUCTION_HANDOFF.md).

## 1. What is included

All of the following asset roots were already tracked in the local repository when this handoff began. `git ls-files --others --ignored --exclude-standard` reported no ignored files in these roots. The assets are ordinary Git files; do not assume they are remotely downloaded at runtime.

| Root | Purpose |
|---|---|
| `ios/Nudge/Assets.xcassets` | Native named images, app icon, Contents.json catalogs, clay art, editorial images, mobility/source art |
| `ios/Nudge/Fonts` | Fraunces 400/500/600/700, 400 italic, HermioneFREE |
| `ios/Nudge/Resources` | Five orb MP4s, music/effects/ta audio, bundled agent-bridge.js |
| `web/public/img` | Branded editorial/clay images, source images, versioned 36-recipe image set, mobility/source pair |
| `web/public/fonts` | Web copies of the six bundled fonts |
| `web/public/audio` | Music, effects, five ta clips |
| `web/public/orb` | Five orb MP4s |
| `web/public` | App/favicon images, placeholder.svg, robots.txt in addition to media directories |
| `tmp/assets` | Tracked original/media processing references, orb variations, audio sources, extracted contact sheets, processing script |
| `tmp/ref2` | Tracked chat/life/privacy/ripple reference movies, extracted frames and font reference |

Reference material under `tmp` is intentional historical handoff material, not disposable build output. Do not remove it blindly. Runtime code should continue using the platform's bundled/public assets, not files from tmp.

## 2. Reproduce the integrity audit

### Verified snapshot

The audit completed successfully during this handoff with **zero failures**:

| Audited root | Files | Bytes |
|---|---:|---:|
| web/public | 113 | 60,524,500 |
| ios/Nudge/Assets.xcassets | 154 | 99,853,729 |
| ios/Nudge/Fonts | 6 | 223,324 |
| ios/Nudge/Resources | 19 | 7,284,695 |
| tmp/assets | 32 | 75,830,124 |
| tmp/ref2 | 21 | 51,034,213 |
| **Total** | **345** | **294,750,585** |

This includes catalog metadata and the bridge/reference-processing scripts as well as binary media. Runtime roots total 292 files; reference roots total 53. All 345 are tracked. The audit also verified **23 matching cross-platform copies** and **58 web asset paths**; documentation path counts vary as this handoff evolves.

Aggregate asset SHA-256 (path + size + content hashes, sorted by the script):

```text
78c45bb1c4537ccdd6ce852b9956e3a995cec5e05aa51486253c7edbe529dba6
```


From repository root:

```sh
python3 tools/audit-handoff.py
python3 tools/audit-handoff.py --manifest
```

The standard-library-only script is read-only and prints JSON. `--manifest` additionally prints **every asset path, byte size, SHA-256 and tracked status** in the six audited roots. It does not print environment values or contact any provider.

Checks:

1. Every discovered file in the audited asset roots is Git tracked, nonempty and not an unhydrated Git LFS pointer.
2. Each Xcode image entry with a filename has that actual image beside Contents.json.
3. Literal web `/img`, `/audio`, `/orb`, `/fonts` references with known extensions exist, plus dynamically selected ta clips and recipe images 0–35.
4. Same-named cross-platform font/orb/audio files have identical bytes.
5. Local Markdown links and explicit root-relative code paths in the four handoff documents resolve.
6. Per-folder byte counts and an aggregate SHA-256 over sorted path/size/file-hash entries are printed for clone comparison.

**Audit limitations:** this is not an exhaustive runtime crawler. Arbitrarily computed image names, indirect library mappings, viewport-specific screens, decode/playback support, shader compilation and external URLs still need runtime testing. An existing image can still be the wrong subject. Hash equality proves equal bytes, not usage rights or visual quality. This does not scan all repository history for secrets.

## 3. Important media mappings

| Product role | Native location/name | Web location/name |
|---|---|---|
| Idle orb day/night | Resources: `orb_day.mp4`, `orb_night.mp4` | public/orb: same names |
| Thinking/speaking/celebration | Resources: `orb_think.mp4`, `orb_speak.mp4`, `orb_bloom.mp4` | public/orb: same names |
| Onboarding soundtrack | Resources: `music_barley_thunder.m4a` | public/audio: same name |
| Ambient soundtrack | Resources: `music_stone_kintsugi.m4a` | public/audio: same name |
| Tap phrase | Resources: `tap_ta_1.mp3` through `tap_ta_5.mp3` | public/audio: same names |
| Other effects | Resources: sfx_bloom, sfx_glass, sfx_tick, sfx_whoosh MP3s | public/audio: same names |
| Recap soundtrack | Resources: `music_recap.mp3` | No identical dedicated public copy; do not assume audio parity |
| Mobility source | Assets catalog: `wellness_routine_figures` | public/img: `rumi-mobility-source-v1.webp` |
| Mobility saved illustration | Assets catalog: `mobility_stretch_walk` | public/img: `rumi-mobility-clay-v1.webp` |
| Chickpea source/art | Native clay food catalogs; review exact caller mapping | public/img: `rumi-chickpea-source-v1.webp`, `rumi-chickpea-clay-v1.webp` |
| Saved recipe samples | Native implementation is not the full web recipe catalog | public/img: `rumi-recipe-0-v1.webp` through `rumi-recipe-35-v1.webp` |
| Core type | Fonts: Fraunces and HermioneFREE TTFs | public/fonts: same files |
| Native browser bridge | `ios/Nudge/Resources/agent-bridge.js` | Tested from web test harness; not a web portal backend |

Inspect `ios/Nudge/Utilities/NudgeType.swift`, `ios/Nudge/Models/LifeModels.swift`, `web/src/sano/lifeLibrary.ts`, `web/src/sano/recipeCollection.ts`, the Orb components and SoundEngine files for runtime selection rules. Do not rename image sets, resources or public paths without updating every caller.

Native shaders are source assets too: `ios/Nudge/Shaders/Orb.metal`, `ios/Nudge/Shaders/LivingGradient.metal`, `ios/Nudge/Shaders/Effects.metal`. They are compiled by Xcode, not copied web media.

Web public media is served at stable URLs. Create a new versioned filename when replacing an existing referenced public asset, then change callers. Native image catalogs require case-correct names and Contents.json references; source folder inclusion is not proof an incorrectly referenced image will load.

## 4. Git and remote verification boundary

Before documentation changes:

- Local `main` HEAD: `0b9226efbe11d9b539d912c80c23dfbb30aca90e`.
- `git ls-remote origin refs/heads/main` returned the identical commit.
- No application source/asset changes were pending at the start; managed history files were the preexisting modified files.
- Runtime media, fonts, reference media and historical specs were already tracked at that commit.

Therefore the pre-handoff asset/source commit was present on the **configured origin remote**. This is stronger than merely seeing files on disk. It is **not independent proof that an additional GitHub mirror/export has finished**. Remote credentials/URLs are not reproduced here. Rork manages commit/push/synchronization; this handoff did not manually commit or push.

The newly written documents/audit script and ignore-rule correction enter Rork's managed sync after this change. They cannot be asserted as already present in a downstream GitHub repository merely because they were written locally. Before starting Codex, verify in the connected GitHub repository that `README.md`, `PRODUCTION_HANDOFF.md`, `DESIGN_REFERENCE.md`, `ASSET_AUDIT.md`, `tools/audit-handoff.py`, and the media directories appear on the intended branch. Run the audit from that checkout and compare asset digest/counts.

The root `.gitignore` previously contained a blanket `.rork` entry. This handoff removes it so new managed state/plans are not accidentally excluded. Existing tracked history remains intact. Do not delete/untrack history or introduce ignore hooks for it.

## 5. Not included, by design or dependency

- `.env`, private provider keys, portal invitation codes, runtime account/session credentials, signing certificates and provisioning profiles.
- Injected/ignored native `Config.swift`; see README for public-only local replacement.
- node_modules, web dist, DerivedData, caches, generated build artifacts. Reproduce them from source, not by committing them.
- Runtime visitor localStorage, app sandbox memory/logs, Keychain data and deployed budget counters.
- Source for the external connected native portal and browser-agent backend named in `ios/Nudge/Services/HostedEndpoints.swift`.
- Historical PDF/Word reference attachments: no tracked PDF/DOCX inputs were found by this audit. Obtain originals separately before relying on exact behavioral taxonomies.
- Evidence of licensed commercial rights for fonts, soundtrack, reference recordings and any imported art. Existing files and generated/source naming do not establish distribution rights.

## 6. Owner checks before external distribution

- [ ] Confirm the connected GitHub repository/branch includes this handoff and all asset roots, using a fresh clone and audit.
- [ ] Keep the repository private while reviewing historical content and references; do not expose secrets or user disclosures through a public export.
- [ ] Obtain music/font/art licensing records and record source/author/license/allowed use/checksum for production assets.
- [ ] Confirm third-party reference videos may be shared with contractors and are not shipped as user-facing app media without permission.
- [ ] Set vendor credentials in deployment secret stores and configure public endpoints separately.
- [ ] Verify production media decodes/plays on physical target devices and offline static screens; review semantic artwork mismatches.
