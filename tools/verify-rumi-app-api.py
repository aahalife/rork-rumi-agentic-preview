#!/usr/bin/env python3
"""Public, read-only contract checks. Never sends login challenges or user writes.

The Swagger's preauthorized AppId is public integration metadata, not a user token.
Live acceptance still needs an owner-confirmed origin/AppId and a verified test account.
"""
import hashlib
import json
from pathlib import Path
import re
import unittest
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
SWAGGER = "https://rumi-api-amber.vercel.app/"
SPEC = SWAGGER + "openapi.json"
SUPABASE_SPEC = "https://egoicdonmuudwvbsockm.supabase.co/functions/v1/rumi-app-api/openapi.json"


def get(url, headers=None):
    request = Request(url, headers={"Accept": "application/json", **(headers or {})})
    try:
        with urlopen(request, timeout=30) as response:
            return response.status, response.read(2_000_000)
    except HTTPError as error:
        return error.code, error.read(100_000)


class ContractChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        status, raw = get(SPEC)
        if status != 200:
            raise RuntimeError(f"Published Swagger OpenAPI unavailable: HTTP {status}")
        cls.spec = json.loads(raw)
        status, page = get(SWAGGER)
        if status != 200:
            raise RuntimeError(f"Swagger unavailable: HTTP {status}")
        match = re.search(r'preauthorizeApiKey\("AppId","([a-f0-9-]+)"\)', page.decode())
        if not match:
            raise RuntimeError("Swagger public AppId not found; no credential was guessed")
        cls.public_app_id = match.group(1)
        cls.base = cls.spec["servers"][0]["url"].rstrip("/")
        if urlsplit(cls.base).scheme != "https":
            raise RuntimeError("Swagger server is not HTTPS; refusing to send requests")
        cls.observations = {"spec_sha256": hashlib.sha256(raw).hexdigest(), "tested_documented_origin": cls.base, "checks": [], "authenticated_acceptance": "not performed", "mutations_sent": False}
        folder = ROOT / "integrations/rumi-app-api"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "openapi.json").write_bytes(raw)

    def check_status(self, path, expected, headers=None):
        status, raw = get(self.base + path, headers)
        self.observations["checks"].append({"path": path, "expected_status": expected, "actual_status": status})
        self.assertEqual(status, expected)
        return json.loads(raw)

    def test_01_health_is_public(self):
        result = self.check_status("/health", 200)
        self.assertEqual(result["service"], "rumi-app-api")
        self.assertEqual(result["status"], "ok")

    def test_02_config_accepts_public_app_id(self):
        config = self.check_status("/v1/config", 200, {"x-rumi-app-id": self.public_app_id})
        self.assertIn(config["records_mode"], ["test", "live"])

    def test_03_app_id_does_not_authorize_user_data(self):
        for path in ["me", "context", "memory", "goals", "records", "conversations"]:
            with self.subTest(path=path):
                response = self.check_status("/v1/" + path, 401, {"x-rumi-app-id": self.public_app_id})
                self.assertIn("code", response["error"])

    def test_04_invalid_app_id_fails(self):
        response = self.check_status("/v1/me", 401)
        self.assertEqual(response["error"]["code"], "invalid_app_id")

    def test_05_authentication_and_rotation_contract(self):
        security = self.spec["components"]["securitySchemes"]
        self.assertEqual(security["AppId"]["name"], "x-rumi-app-id")
        self.assertEqual(security["Bearer"]["scheme"], "bearer")
        self.assertIn("ServerKey", security)
        self.assertEqual(self.spec["paths"]["/v1/auth/exchange"]["post"]["security"], [{"AppId": [], "ServerKey": []}])
        self.assertIn("refresh_token", self.spec["components"]["schemas"]["Session"]["required"])
        self.assertIn("committed", self.spec["components"]["schemas"]["Receipt"]["properties"])

    def test_06_no_assumed_insight_transport(self):
        self.assertFalse(any("insight" in path.lower() for path in self.spec["paths"]))
        conversation = self.spec["components"]["schemas"]["Conversation"]["properties"]
        self.assertIn("sdk_options", conversation)
        self.assertIn("signedUrl", conversation["sdk_options"]["properties"])

    def test_07_supabase_and_swagger_contracts_match_except_server(self):
        status, raw = get(SUPABASE_SPEC)
        self.assertEqual(status, 200)
        other = json.loads(raw)
        self.assertEqual(other["paths"], self.spec["paths"])
        self.assertEqual(other["components"], self.spec["components"])
        self.observations["supabase_servers"] = other.get("servers")

    @classmethod
    def tearDownClass(cls):
        (ROOT / "integrations/rumi-app-api/public-checks.json").write_text(json.dumps(cls.observations, indent=2) + "\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
