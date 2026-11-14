"""Verify SDK commands escape hook Git context without weakening failure gates."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

WRAPPER = Path(__file__).with_name("with-sdk-env.sh").resolve()


class SdkEnvironmentTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name) / "app"
        self.sdk = Path(self.tmp.name) / "sdk"
        for path in (self.repo, self.sdk):
            subprocess.run(["git", "-c", "init.templateDir=", "init", "-q", str(path)],
                           check=True, capture_output=True)
        self.env = dict(os.environ, GIT_DIR=str(self.repo / ".git"),
                        GIT_WORK_TREE=str(self.repo), GIT_INDEX_FILE=str(self.repo / ".git/custom-index"))

    def invoke(self, *args):
        return subprocess.run(["bash", str(WRAPPER), *args], cwd=self.repo,
                              env=self.env, text=True, capture_output=True)

    def test_foreign_git_checkout_is_detected(self):
        before = subprocess.run(["git", "-C", str(self.sdk), "rev-parse", "--show-toplevel"],
                                env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(Path(before.stdout.strip()).resolve(), self.repo.resolve())
        result = self.invoke("git", "-C", str(self.sdk), "rev-parse", "--show-toplevel")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.strip()).resolve(), self.sdk.resolve())
        # The parent still has the exact custom index for staged-file selection.
        self.assertEqual(self.env["GIT_INDEX_FILE"], str(self.repo / ".git/custom-index"))

    def test_failure_exit_code_is_preserved(self):
        self.assertEqual(self.invoke("bash", "-c", "exit 7").returncode, 7)

    def test_argument_boundaries_are_preserved(self):
        result = self.invoke("printf", "%s\n", "two words", "literal $(not-a-command)")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["two words", "literal $(not-a-command)"])

    def test_missing_command_is_an_error(self):
        self.assertEqual(self.invoke().returncode, 64)


if __name__ == "__main__":
    unittest.main()
