from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from backend.app.config import Settings
from backend.app.core.errors import ValidationError


TIMESTAMP_DIR_PATTERN = re.compile(r"^\d{8}T\d{6}Z$")
TEST_RESULT_FILES = (
    "summary.txt",
    "rbac-tests.txt",
    "resource-tests.txt",
    "network-tests.txt",
    "cluster-state.txt",
)


@dataclass(frozen=True)
class TestRunSummary:
    run_id: str
    path: Path
    summary_text: str | None
    passed: int | None
    failed: int | None
    present_files: tuple[str, ...]
    missing_files: tuple[str, ...]
    present_file_count: int
    total_expected_files: int
    is_mostly_complete: bool


class ArtifactService:
    """Reads test evidence and GUI-run artifacts from the repository."""

    MOSTLY_COMPLETE_THRESHOLD = 4

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def list_test_runs(self) -> list[TestRunSummary]:
        root = self.settings.artifacts_root / "test-results"
        if not root.exists():
            return []

        results: list[TestRunSummary] = []
        for path in sorted(root.iterdir(), key=lambda item: item.name, reverse=True):
            if not path.is_dir() or not TIMESTAMP_DIR_PATTERN.fullmatch(path.name):
                continue

            results.append(self._build_test_run_summary(path))
        return results

    def get_latest_test_run(self) -> TestRunSummary | None:
        runs = self.list_test_runs()
        if not runs:
            return None

        for run in runs:
            if run.is_mostly_complete:
                return run
        return runs[0]

    def read_test_result_section(self, run_id: str, section: str) -> str:
        if section not in TEST_RESULT_FILES:
            raise ValidationError(f"unsupported test-result section: {section}")

        run_dir = self.settings.artifacts_root / "test-results" / run_id
        if not run_dir.is_dir() or not TIMESTAMP_DIR_PATTERN.fullmatch(run_id):
            raise ValidationError(f"unknown test-results run: {run_id}")

        content = self._read_text_file(run_dir / section)
        if content is None:
            raise ValidationError(f"missing test-results section: {section}")
        return content

    def _parse_summary_counts(self, text: str | None) -> tuple[int | None, int | None]:
        if not text:
            return None, None

        passed = None
        failed = None
        for line in text.splitlines():
            if line.startswith("Passed:"):
                passed = int(line.split(":", 1)[1].strip())
            if line.startswith("Failed:"):
                failed = int(line.split(":", 1)[1].strip())
        return passed, failed

    def _build_test_run_summary(self, path: Path) -> TestRunSummary:
        present_files = tuple(name for name in TEST_RESULT_FILES if path.joinpath(name).is_file())
        missing_files = tuple(name for name in TEST_RESULT_FILES if name not in present_files)
        summary_text = self._read_text_file(path / "summary.txt")
        passed, failed = self._parse_summary_counts(summary_text)
        present_file_count = len(present_files)

        return TestRunSummary(
            run_id=path.name,
            path=path,
            summary_text=summary_text,
            passed=passed,
            failed=failed,
            present_files=present_files,
            missing_files=missing_files,
            present_file_count=present_file_count,
            total_expected_files=len(TEST_RESULT_FILES),
            is_mostly_complete=present_file_count >= self.MOSTLY_COMPLETE_THRESHOLD,
        )

    def _read_text_file(self, path: Path) -> str | None:
        try:
            return path.read_text(encoding="utf-8")
        except FileNotFoundError:
            return None
