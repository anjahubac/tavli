"""Guard the code-only email contract for new and existing Tavli accounts."""
from html.parser import HTMLParser
from pathlib import Path
import tomllib
import unittest

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


if __name__ == "__main__":
    unittest.main()
