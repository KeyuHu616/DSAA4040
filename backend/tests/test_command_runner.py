from pathlib import Path
import tempfile
import unittest

from backend.app.config import Settings
from backend.app.core.errors import ValidationError
from backend.app.services.command_runner import CommandRunner


class CommandRunnerTests(unittest.TestCase):
    def test_build_action_argv_rejects_unknown_action(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            runner = CommandRunner(Settings(repo_root=Path(tmp_dir)))

            with self.assertRaises(ValidationError):
                runner.build_action_argv("rm -rf /")

    def test_run_action_writes_json_log_for_whitelisted_script(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            scripts_dir = tmp_path / "scripts"
            scripts_dir.mkdir(parents=True)

            check_script = scripts_dir / "check-environment.sh"
            check_script.write_text("#!/usr/bin/env bash\nprintf 'ok\\n'\n", encoding="utf-8")
            check_script.chmod(0o755)

            run_tests = scripts_dir / "run-tests.sh"
            run_tests.write_text("#!/usr/bin/env bash\nprintf 'tests\\n'\n", encoding="utf-8")
            run_tests.chmod(0o755)

            settings = Settings(repo_root=tmp_path, command_timeout_seconds=5)
            runner = CommandRunner(settings)

            result = runner.run_action("check-environment")

            self.assertTrue(result.ok)
            self.assertEqual(result.stdout, "ok\n")
            self.assertEqual(result.stderr, "")
            self.assertTrue(result.log_path.exists())
            self.assertIn('"action": "check-environment"', result.log_path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
