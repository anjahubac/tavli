"""Publish Tavli's signup and sign-in emails from the Supabase deploy workflow."""

from contextlib import closing
from http.client import HTTPSConnection, HTTPException
import json
import os
from pathlib import Path
import re
import tomllib

ROOT = Path(__file__).resolve().parents[1]


def request_auth_config(method, project, token, templates=None):
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    body = None
    if templates is not None:
        headers["Content-Type"] = "application/json"
        body = json.dumps(templates)

    with closing(HTTPSConnection("api.supabase.com", timeout=30)) as connection:
        connection.request(method, f"/v1/projects/{project}/config/auth", body, headers)
        with connection.getresponse() as response:
            if not 200 <= response.status < 300:
                raise SystemExit(f"Supabase Auth config {method} failed (HTTP {response.status}).")
            if method == "GET":
                config = json.load(response)
                if not isinstance(config, dict):
                    raise SystemExit("Supabase Auth config GET returned an invalid response.")
                return config


def deploy_templates(project, token):
    with (ROOT / "supabase/config.toml").open("rb") as config:
        email = tomllib.load(config)["auth"]["email"]

    templates = {}
    for name in ("confirmation", "magic_link"):
        template = email["template"][name]
        templates[f"mailer_subjects_{name}"] = template["subject"]
        templates[f"mailer_templates_{name}_content"] = (
            ROOT / template["content_path"]
        ).read_text(encoding="utf-8")

    expected_settings = {
        "mailer_autoconfirm": not email["enable_confirmations"],
        "mailer_otp_length": email["otp_length"],
        "mailer_otp_exp": email["otp_expiry"],
        "smtp_max_frequency": int(email["max_frequency"].removesuffix("s")),
    }
    hosted = request_auth_config("GET", project, token)
    mismatches = [key for key, value in expected_settings.items() if hosted.get(key) != value]
    if mismatches:
        raise SystemExit(f"Hosted Auth settings differ from config.toml: {', '.join(mismatches)}.")

    if any(hosted.get(key) != value for key, value in templates.items()):
        request_auth_config("PATCH", project, token, templates)
        hosted = request_auth_config("GET", project, token)
        for key, value in (expected_settings | templates).items():
            if hosted.get(key) != value:
                raise SystemExit(f"Supabase Auth config verification failed for {key}.")


def main():
    project = os.environ.get("SUPABASE_PROJECT_REF", "")
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    if not re.fullmatch(r"[a-z0-9]{20}", project) or not token:
        raise SystemExit("Set SUPABASE_PROJECT_REF and SUPABASE_ACCESS_TOKEN for this environment.")

    try:
        deploy_templates(project, token)
    except (OSError, HTTPException, ValueError, KeyError, TypeError):
        # Auth config responses may include credentials. Keep error details out of CI logs.
        raise SystemExit(
            "Could not read template files or communicate with the Supabase Management API."
        ) from None
    print("Supabase Auth email templates and OTP settings verified.")


if __name__ == "__main__":
    main()
