from pathlib import Path
import unittest

from backend.app.core.errors import ValidationError
from backend.app.services.validation_service import ValidationService


class ValidationServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = ValidationService()

    def test_validate_tenant_name_accepts_dns1123_label(self) -> None:
        self.assertEqual(self.service.validate_tenant_name("team-a"), "team-a")

    def test_validate_tenant_name_rejects_invalid_label(self) -> None:
        for tenant in ["Team-A", "team_a", "-team", "team-"]:
            with self.subTest(tenant=tenant):
                with self.assertRaises(ValidationError):
                    self.service.validate_tenant_name(tenant)

    def test_validate_confirmed_tenant_requires_exact_match(self) -> None:
        with self.assertRaises(ValidationError):
            self.service.validate_confirmed_tenant("team-a", "team-b")

    def test_is_safe_kubeconfig_path_accepts_top_level_kubeconfig(self) -> None:
        self.assertTrue(self.service.is_safe_kubeconfig_path(Path("team-a-developer.kubeconfig")))

    def test_is_safe_kubeconfig_path_rejects_sensitive_or_hidden_paths(self) -> None:
        for path in [
            Path("team-a.key"),
            Path("team-a.crt"),
            Path("team-a.csr"),
            Path(".generated/team-a-developer.kubeconfig"),
        ]:
            with self.subTest(path=str(path)):
                self.assertFalse(self.service.is_safe_kubeconfig_path(path))


if __name__ == "__main__":
    unittest.main()
