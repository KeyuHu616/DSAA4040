from pathlib import Path
import tempfile
import time
import unittest

from backend.app.config import Settings
from backend.app.services.audit_service import AuditService
from backend.app.services.command_runner import CommandRunner
from backend.app.services.task_service import TaskService


class TaskServiceTests(unittest.TestCase):
    def test_start_background_action_persists_completed_task(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            scripts_dir = tmp_path / "scripts"
            scripts_dir.mkdir(parents=True)

            scripts_dir.joinpath("check-environment.sh").write_text(
                "#!/usr/bin/env bash\nprintf 'ready\\n'\n",
                encoding="utf-8",
            )
            scripts_dir.joinpath("check-environment.sh").chmod(0o755)
            scripts_dir.joinpath("run-tests.sh").write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            scripts_dir.joinpath("run-tests.sh").chmod(0o755)
            scripts_dir.joinpath("bootstrap-cluster.sh").write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            scripts_dir.joinpath("bootstrap-cluster.sh").chmod(0o755)
            scripts_dir.joinpath("onboard-team.sh").write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            scripts_dir.joinpath("onboard-team.sh").chmod(0o755)
            scripts_dir.joinpath("offboard-team.sh").write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            scripts_dir.joinpath("offboard-team.sh").chmod(0o755)

            settings = Settings(repo_root=tmp_path, command_timeout_seconds=5)
            service = TaskService(settings, CommandRunner(settings), AuditService(settings))

            record = service.start_background_action("check-environment", timeout_seconds=5)
            deadline = time.time() + 2
            latest = record
            while time.time() < deadline:
                latest = service.get_task(record.run_id)
                if latest.status != "running":
                    break
                time.sleep(0.05)

            self.assertEqual(latest.status, "succeeded")
            self.assertEqual(latest.exit_code, 0)
            self.assertIsNotNone(latest.log_path)


if __name__ == "__main__":
    unittest.main()