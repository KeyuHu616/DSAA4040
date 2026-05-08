from pathlib import Path
import tempfile
import unittest

from backend.app.config import Settings
from backend.app.services.kubeconfig_service import KubeconfigService
from backend.app.services.validation_service import ValidationService


class KubeconfigServiceTests(unittest.TestCase):
    def test_list_safe_kubeconfigs_filters_sensitive_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            kubeconfig_dir = tmp_path / "artifacts" / "kubeconfigs"
            kubeconfig_dir.mkdir(parents=True)

            kubeconfig_dir.joinpath("team-a-developer.kubeconfig").write_text(
                """
apiVersion: v1
current-context: team-a-developer@cluster
contexts:
  - name: team-a-developer@cluster
    context:
      namespace: team-a
users:
  - name: team-a-developer
""".strip(),
                encoding="utf-8",
            )
            kubeconfig_dir.joinpath("team-a-developer.key").write_text("secret", encoding="utf-8")

            service = KubeconfigService(Settings(repo_root=tmp_path), ValidationService())
            results = service.list_safe_kubeconfigs()

            self.assertEqual(len(results), 1)
            self.assertEqual(results[0].filename, "team-a-developer.kubeconfig")
            self.assertEqual(results[0].username, "team-a-developer")
            self.assertEqual(results[0].namespace, "team-a")


if __name__ == "__main__":
    unittest.main()
