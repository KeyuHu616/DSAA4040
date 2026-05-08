from pathlib import Path
import tempfile
import unittest

from backend.app.config import Settings
from backend.app.core.errors import ValidationError
from backend.app.services.artifact_service import ArtifactService


class ArtifactServiceTests(unittest.TestCase):
    def test_list_test_runs_parses_summary_counts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            run_dir = tmp_path / "artifacts" / "test-results" / "20260508T120000Z"
            run_dir.mkdir(parents=True)
            run_dir.joinpath("summary.txt").write_text(
                "Result directory: artifacts/test-results/20260508T120000Z\nPassed: 11\nFailed: 0\n",
                encoding="utf-8",
            )

            service = ArtifactService(Settings(repo_root=tmp_path))
            runs = service.list_test_runs()

            self.assertEqual(len(runs), 1)
            self.assertEqual(runs[0].run_id, "20260508T120000Z")
            self.assertEqual(runs[0].passed, 11)
            self.assertEqual(runs[0].failed, 0)
            self.assertIn("summary.txt", runs[0].present_files)
            self.assertIn("rbac-tests.txt", runs[0].missing_files)
            self.assertEqual(runs[0].present_file_count, 1)
            self.assertFalse(runs[0].is_mostly_complete)

    def test_get_latest_test_run_prefers_newer_mostly_complete_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            root = tmp_path / "artifacts" / "test-results"

            older_complete = root / "20260508T120000Z"
            older_complete.mkdir(parents=True)
            for name in ("summary.txt", "rbac-tests.txt", "resource-tests.txt", "network-tests.txt"):
                older_complete.joinpath(name).write_text("ok\n", encoding="utf-8")

            newer_incomplete = root / "20260508T120100Z"
            newer_incomplete.mkdir(parents=True)
            newer_incomplete.joinpath("summary.txt").write_text("Passed: 1\nFailed: 0\n", encoding="utf-8")

            service = ArtifactService(Settings(repo_root=tmp_path))
            latest = service.get_latest_test_run()

            self.assertIsNotNone(latest)
            self.assertEqual(latest.run_id, "20260508T120000Z")
            self.assertTrue(latest.is_mostly_complete)
            self.assertEqual(latest.present_file_count, 4)
            self.assertEqual(latest.missing_files, ("cluster-state.txt",))

    def test_get_latest_test_run_falls_back_to_newest_when_no_mostly_complete_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            root = tmp_path / "artifacts" / "test-results"

            older_run = root / "20260508T120000Z"
            older_run.mkdir(parents=True)
            older_run.joinpath("summary.txt").write_text("Passed: 1\nFailed: 0\n", encoding="utf-8")
            older_run.joinpath("rbac-tests.txt").write_text("ok\n", encoding="utf-8")

            newer_run = root / "20260508T120100Z"
            newer_run.mkdir(parents=True)
            newer_run.joinpath("summary.txt").write_text("Passed: 2\nFailed: 0\n", encoding="utf-8")

            service = ArtifactService(Settings(repo_root=tmp_path))
            latest = service.get_latest_test_run()

            self.assertIsNotNone(latest)
            self.assertEqual(latest.run_id, "20260508T120100Z")
            self.assertFalse(latest.is_mostly_complete)
            self.assertEqual(latest.present_files, ("summary.txt",))

    def test_read_test_result_section_rejects_unknown_section(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            service = ArtifactService(Settings(repo_root=Path(tmp_dir)))

            with self.assertRaises(ValidationError):
                service.read_test_result_section("20260508T120000Z", "secrets.txt")


if __name__ == "__main__":
    unittest.main()