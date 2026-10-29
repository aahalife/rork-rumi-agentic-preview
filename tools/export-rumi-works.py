#!/usr/bin/env python3
"""Export just the simplified app integration as an applyable patch; never commits or pushes."""
from pathlib import Path
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "linked/rumi-research-preview"
FILES = (
    "ios-rumi/Rumi/HomeView.swift",
    "ios-rumi/Rumi/ContentView.swift",
    "ios-rumi/Rumi/DemoMode.swift",
    "ios-rumi/Rumi/DemoInsights.swift",
    "ios-rumi/Rumi/RumiAppAPI.swift",
    "ios-rumi/Rumi/RumiAppAPIView.swift",
    "ios-rumi/RumiTests/RumiInsightsTests.swift",
    "ios-rumi/RumiTests/RumiAPITransportTests.swift",
    "ios-rumi/RumiUITests/RumiInsightsUITests.swift",
    "integrations/rumi-app-api/openapi.json",
    "integrations/rumi-app-api/public-checks.json",
    "integrations/rumi-app-api/PORTING_HANDOFF.md",
    "tools/verify-rumi-app-api.py",
    "ios-rumi/Rumi/DemoServices.swift",
    "ios-rumi/Rumi/DemoBrowser.swift",
    "ios-rumi/Rumi/DemoRecipeResearch.swift",
    "ios-rumi/Rumi/DemoRealtimeBridge.swift",
    "ios-rumi/Rumi/DemoRealtimeCodec.js",
    "ios-rumi/Rumi/DemoAgentPrompt.txt",
    "tools/prepare-rumi-demo-prompt.py",
    "tools/rumi-demo-codec/codec.ts",
    "tools/rumi-demo-codec/package.json",
    "tools/rumi-demo-codec/bun.lock",
    "ios-rumi/Rumi/ChatModels.swift",
    "ios-rumi/Rumi/WorksModel.swift",
    "ios-rumi/Rumi/WorksBridge.swift",
    "ios-rumi/Rumi/WorksBrowser.swift",
    "ios-rumi/Rumi/WorksView.swift",
    "ios-rumi/Rumi/VoiceModeView.swift",
    "ios-rumi/Rumi/CompanionService.swift",
    "ios-rumi/Rumi/CompanionChannelsView.swift",
    "ios-rumi/Rumi/SharedContextView.swift",
    "ios-rumi/Rumi/HealthView.swift",
    "ios-rumi/Rumi/HealthTrendsView.swift",
    "ios-rumi/Rumi.xcodeproj/project.pbxproj",
    "functions/rumi-companion.ts",
    "functions/rumi-existing-api.ts",
    "functions/rumi-pilot.ts",
    "functions/tsconfig.json",
    "functions/bun.lock",
    "integrations/rumi-pilot/202610290001_app_accounts.sql",
    "functions/rumi-ai.ts",
    "functions/package.json",
    "tools/provision-companion-access.py",
)
DEST = ROOT / "deliveries/rumi-works-interactive-browser.patch"


def main():
    if not (BASE / "ios-rumi/Rumi/HomeView.swift").is_file():
        raise SystemExit("Initialize the linked source repository before exporting.")
    fork_config = json.loads((BASE / "rork.json").read_text())
    fork_config["apps"].append({"name": "Functions", "path": "functions", "framework": "cloudflare"})
    # Export only the isolated new routes, not the larger apps' legacy public voice endpoints.
    standalone_index = '''import { handleCompanion, type CompanionEnv } from "./rumi-companion";
export { RumiCompanionHub } from "./rumi-companion";
export { RumiPilotVoice } from "./rumi-pilot";
export { RumiBudget } from "./rumi-ai";
export default {
  async fetch(request: Request, env: CompanionEnv): Promise<Response> {
    if (new URL(request.url).pathname.startsWith("/companion/")) return handleCompanion(request, env);
    return Response.json({ error: "Not found" }, { status: 404 });
  },
};
'''
    generated = {"rork.json": json.dumps(fork_config, indent=2) + "\n", "functions/index.ts": standalone_index}
    changes = []
    for name in (*FILES, *generated):
        before = BASE / name
        after = ROOT / name
        if name not in generated and not after.is_file():
            raise SystemExit(f"Missing implementation: {after}")
        old = before.read_text().splitlines(keepends=True) if before.exists() else []
        new = (generated[name] if name in generated else after.read_text()).splitlines(keepends=True)
        if old == new:
            continue
        path = name
        changes.append(f"diff --git a/{path} b/{path}\n")
        if not before.exists():
            changes.append("new file mode 100644\n")
        changes.extend(difflib.unified_diff(old, new, fromfile=f"a/{path}" if before.exists() else "/dev/null", tofile=f"b/{path}"))
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text("".join(changes))
    print(f"Exported {DEST.relative_to(ROOT)} ({DEST.stat().st_size:,} bytes)")
    print(f"SHA-256: {hashlib.sha256(DEST.read_bytes()).hexdigest()}")
    print("Target repository: https://github.com/aahalife/rork-rumi-research-preview")
    print("Source checkpoint: 2a6a5e0 (connected fork's main at inspection)")
    print("Suggested branch: feature/rumi-works-interactive-browser")
    print("Apply this patch from the target repository root on a separate feature branch.")
    print("This export does not publish, modify main, include credentials, or copy Rork history.")


if __name__ == "__main__":
    main()
