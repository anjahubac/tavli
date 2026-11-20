"""Guard the code-only email contract for new and existing Tavli accounts."""
from html.parser import HTMLParser
import json
from pathlib import Path
import tomllib
import unittest
from unittest.mock import patch

from deploy_auth_email_templates import deploy_templates, request_auth_config

ROOT = Path(__file__).resolve().parents[1]


class EmailMarkup(HTMLParser):
    def __init__(self):
        super().__init__()
        self.body = False
        self.body_text = []
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == "body":
            self.body = True
        if tag == "a":
            self.links.append(dict(attrs).get("href"))

    def handle_endtag(self, tag):
        if tag == "body":
            self.body = False

    def handle_data(self, data):
        if self.body:
            self.body_text.append(data)


class AuthEmailTemplatesTest(unittest.TestCase):
    def test_first_and_returning_account_emails_offer_a_code_without_auth_links(self):
        config = tomllib.loads((ROOT / "supabase/config.toml").read_text())
        email = config["auth"]["email"]
        self.assertEqual(
            email["template"]["confirmation"]["content_path"],
            email["template"]["magic_link"]["content_path"],
        )
        for name in ("confirmation",):
            with self.subTest(template=name):
                template = email["template"][name]
                html = (ROOT / template["content_path"]).read_text()
                markup = EmailMarkup()
                markup.feed(html)
                text = " ".join(" ".join(markup.body_text).split())
                self.assertIn("{{ .Token }}", text)
                self.assertIn("Upiši ovaj kod u aplikaciju Tavli", text)
                self.assertIn("Kod važi 10 minuta", text)
                self.assertEqual(markup.links, [])
                for placeholder in ("ConfirmationURL", "TokenHash", "RedirectTo", "SiteURL"):
                    self.assertNotIn(placeholder, html)
                self.assertNotIn("Već sam potvrdio/la", text)

    def test_sending_a_code_does_not_disable_email_verification(self):
        config = tomllib.loads((ROOT / "supabase/config.toml").read_text())
        email = config["auth"]["email"]
        self.assertTrue(email["enable_confirmations"])
        self.assertEqual(email["otp_length"], 6)
        self.assertEqual(email["otp_expiry"], 600)
        self.assertEqual(email["max_frequency"], "30s")
        self.assertEqual(email["template"]["confirmation"]["subject"], "Tvoj Tavli kod")
        self.assertEqual(email["template"]["magic_link"]["subject"], "Tvoj Tavli kod")


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
        html = (ROOT / "supabase/templates/magic_link.html").read_text(encoding="utf-8")
        templates = {
            "mailer_subjects_confirmation": "Tvoj Tavli kod",
            "mailer_templates_confirmation_content": html,
            "mailer_subjects_magic_link": "Tvoj Tavli kod",
            "mailer_templates_magic_link_content": html,
        }
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
