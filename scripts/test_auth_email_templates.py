"""Guard the code-only email contract for new and existing Tavli accounts."""
from html.parser import HTMLParser
import json
from pathlib import Path
import tomllib
import unittest
from unittest.mock import patch

from deploy_auth_email_templates import (
    LOCAL_PUBLIC_STORAGE,
    deploy_templates,
    request_auth_config,
)

ROOT = Path(__file__).resolve().parents[1]


class EmailMarkup(HTMLParser):
    def __init__(self):
        super().__init__()
        self.body = False
        self.body_text = []
        self.links = []
        self.images = []

    def handle_starttag(self, tag, attrs):
        if tag == "body":
            self.body = True
        if tag == "a":
            self.links.append(dict(attrs).get("href"))
        if tag == "img":
            self.images.append(dict(attrs).get("src"))

    def handle_endtag(self, tag):
        if tag == "body":
            self.body = False

    def handle_data(self, data):
        if self.body:
            self.body_text.append(data)


def email_config():
    return tomllib.loads((ROOT / "supabase/config.toml").read_text())["auth"]["email"]


def parse(name):
    html = (ROOT / email_config()["template"][name]["content_path"]).read_text()
    markup = EmailMarkup()
    markup.feed(html)
    return html, markup, " ".join(" ".join(markup.body_text).split())


class AuthEmailTemplatesTest(unittest.TestCase):
    def test_signup_email_offers_the_confirm_button_and_the_same_code(self):
        html, markup, text = parse("confirmation")
        self.assertEqual(markup.links, ["{{ .ConfirmationURL }}"])
        self.assertIn("Potvrdi adresu", text)
        self.assertIn("{{ .Token }}", text)
        self.assertIn("Tavli ti je na drugom uređaju? Upiši ovaj kod tamo", text)
        self.assertIn("važe 10 minuta", text)
        # The link is built by GoTrue (PKCE); no hand-made auth links.
        for placeholder in ("TokenHash", "SiteURL", "RedirectTo"):
            self.assertNotIn(placeholder, html)

    def test_sign_in_email_offers_only_a_code(self):
        html, markup, text = parse("magic_link")
        self.assertEqual(markup.links, [])
        self.assertIn("{{ .Token }}", text)
        self.assertIn("Upiši ovaj kod u aplikaciju Tavli", text)
        self.assertIn("Kod važi 10 minuta", text)
        for placeholder in ("ConfirmationURL", "TokenHash", "RedirectTo", "SiteURL"):
            self.assertNotIn(placeholder, html)

    def test_email_images_come_only_from_our_storage_bucket(self):
        email = email_config()
        for name in ("confirmation", "magic_link"):
            with self.subTest(template=name):
                _, markup, _ = parse(name)
                self.assertTrue(markup.images)
                for src in markup.images:
                    self.assertTrue(
                        src.startswith(LOCAL_PUBLIC_STORAGE + "email-assets/"), src
                    )
                    asset = src.removeprefix(LOCAL_PUBLIC_STORAGE + "email-assets/")
                    self.assertTrue((ROOT / "supabase/email-assets" / asset).is_file())
        bucket = tomllib.loads((ROOT / "supabase/config.toml").read_text())[
            "storage"
        ]["buckets"]["email-assets"]
        self.assertTrue(bucket["public"])
        self.assertEqual(bucket["allowed_mime_types"], ["image/png"])
        self.assertEqual(email["template"]["confirmation"]["content_path"],
                         "./supabase/templates/confirmation.html")

    def test_sending_a_code_does_not_disable_email_verification(self):
        email = email_config()
        self.assertTrue(email["enable_confirmations"])
        self.assertEqual(email["otp_length"], 6)
        self.assertEqual(email["otp_expiry"], 600)
        self.assertEqual(email["max_frequency"], "30s")
        self.assertEqual(
            email["template"]["confirmation"]["subject"], "Potvrdi adresu za Tavli"
        )
        self.assertEqual(email["template"]["magic_link"]["subject"], "Tvoj Tavli kod")

    def test_confirm_link_returns_to_the_app(self):
        auth = tomllib.loads((ROOT / "supabase/config.toml").read_text())["auth"]
        self.assertIn("tavli://auth-callback", auth["additional_redirect_urls"])


class DeployAuthEmailTemplatesTest(unittest.TestCase):
    project = "abcdefghijklmnopqrst"
    token = "fake-management-token"
    hosted_settings = {
        "mailer_autoconfirm": False,
        "mailer_otp_length": 6,
        "mailer_otp_exp": 600,
        "smtp_max_frequency": 30,
        "smtp_pass": "fake-existing-smtp-value",
    }

    def test_publishes_only_both_template_subjects_and_bodies_then_reads_them_back(self):
        hosted_storage = f"https://{self.project}.supabase.co/storage/v1/object/public/"

        def hosted(name):
            html = (ROOT / f"supabase/templates/{name}.html").read_text(encoding="utf-8")
            return html.replace(LOCAL_PUBLIC_STORAGE, hosted_storage)

        templates = {
            "mailer_subjects_confirmation": "Potvrdi adresu za Tavli",
            "mailer_templates_confirmation_content": hosted("confirmation"),
            "mailer_subjects_magic_link": "Tvoj Tavli kod",
            "mailer_templates_magic_link_content": hosted("magic_link"),
        }
        for value in templates.values():
            self.assertNotIn("127.0.0.1", value)
        self.assertIn(hosted_storage + "email-assets/tavli-logo-krem.png",
                      templates["mailer_templates_confirmation_content"])
        original = self.hosted_settings | {"mailer_subjects_confirmation": "Old subject"}
        updated = self.hosted_settings | templates

        with patch("deploy_auth_email_templates.HTTPSConnection") as connect:
            connection = connect.return_value
            response = connection.getresponse.return_value.__enter__.return_value
            response.status = 200
            response.read.side_effect = [
                json.dumps(original), json.dumps(updated), json.dumps(updated)
            ]

            deploy_templates(self.project, self.token)
            deploy_templates(self.project, self.token)

            calls = connection.request.call_args_list
            self.assertEqual([call.args[0] for call in calls], ["GET", "PATCH", "GET", "GET"])
            for call in calls:
                self.assertEqual(call.args[1], f"/v1/projects/{self.project}/config/auth")
                self.assertEqual(call.args[3]["Authorization"], f"Bearer {self.token}")
            self.assertEqual(json.loads(calls[1].args[2]), templates)
            self.assertEqual(calls[1].args[3]["Content-Type"], "application/json")
            connect.assert_called_with("api.supabase.com", timeout=30)

    def test_stops_before_publishing_when_hosted_otp_settings_differ(self):
        hosted = self.hosted_settings | {"mailer_autoconfirm": True, "mailer_otp_exp": 3600}
        with patch("deploy_auth_email_templates.request_auth_config", return_value=hosted) as request:
            with self.assertRaisesRegex(SystemExit, "mailer_autoconfirm, mailer_otp_exp"):
                deploy_templates(self.project, self.token)
            request.assert_called_once_with("GET", self.project, self.token)

    def test_fails_when_the_published_templates_do_not_match_on_readback(self):
        with patch("deploy_auth_email_templates.request_auth_config") as request:
            request.side_effect = [self.hosted_settings, None, self.hosted_settings]
            with self.assertRaisesRegex(SystemExit, "verification failed for mailer_subjects_confirmation"):
                deploy_templates(self.project, self.token)

    def test_reports_http_failure_without_reading_sensitive_response_body(self):
        with patch("deploy_auth_email_templates.HTTPSConnection") as connect:
            response = connect.return_value.getresponse.return_value.__enter__.return_value
            response.status = 403
            with self.assertRaisesRegex(SystemExit, r"GET failed \(HTTP 403\)"):
                request_auth_config("GET", self.project, self.token)
            response.read.assert_not_called()


if __name__ == "__main__":
    unittest.main()
