from __future__ import annotations

import os
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import streamlit as st
import yaml


APP_TITLE = "DSAA4040 Multi-Tenant Kubernetes Lab Platform"
REPO_ROOT = Path(__file__).resolve().parent.parent
EXPECTED_MARKERS = [
    REPO_ROOT / "scripts",
    REPO_ROOT / "manifests",
    REPO_ROOT / "artifacts",
    REPO_ROOT / "environment.yml",
]
TENANTS = ["team-a", "team-b"]
TEST_RESULT_FILES = [
    "summary.txt",
    "rbac-tests.txt",
    "resource-tests.txt",
    "network-tests.txt",
    "cluster-state.txt",
]
TIMESTAMP_DIR_PATTERN = re.compile(r"^\d{8}T\d{6}Z$")


@dataclass
class CommandResult:
    command: str
    returncode: int
    output: str
    timed_out: bool = False

    @property
    def ok(self) -> bool:
        return self.returncode == 0 and not self.timed_out


def repo_is_valid() -> bool:
    return all(path.exists() for path in EXPECTED_MARKERS)


def repo_warning() -> str | None:
    cwd = Path.cwd().resolve()
    if cwd != REPO_ROOT:
        return (
            f"This app was started from `{cwd}` instead of the repository root "
            f"`{REPO_ROOT}`. The dashboard will still use repository-root paths, "
            "but it is best to start Streamlit from the repository root."
        )
    return None


def run_command(args: list[str], timeout: int = 30) -> CommandResult:
    command_str = " ".join(args)
    env = os.environ.copy()
    try:
        completed = subprocess.run(
            args,
            cwd=REPO_ROOT,
            env=env,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        output = (completed.stdout or "") + (completed.stderr or "")
        return CommandResult(command=command_str, returncode=completed.returncode, output=output.strip())
    except FileNotFoundError as exc:
        return CommandResult(command=command_str, returncode=127, output=str(exc))
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout.decode() if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        stderr = exc.stderr.decode() if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        output = (stdout + stderr).strip()
        if not output:
            output = f"Command timed out after {timeout} seconds."
        return CommandResult(command=command_str, returncode=124, output=output, timed_out=True)


def render_command_result(title: str, result: CommandResult, height: int = 180) -> None:
    st.markdown(f"**{title}**")
    message = f"`{result.command}`"
    if result.timed_out:
        st.warning(f"{message} timed out.")
    elif result.ok:
        st.success(message)
    else:
        st.error(message)
    st.text_area(
        label=f"{title} output",
        value=result.output or "(no output)",
        height=height,
        key=f"{title}-{result.command}",
        disabled=True,
    )


def list_kubeconfigs() -> list[dict[str, str]]:
    kubeconfig_dir = REPO_ROOT / "artifacts" / "kubeconfigs"
    results: list[dict[str, str]] = []
    if not kubeconfig_dir.exists():
        return results

    for path in sorted(kubeconfig_dir.glob("*.kubeconfig")):
        username = path.stem
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            users = data.get("users", [])
            if users and isinstance(users[0], dict):
                username = users[0].get("name", username)
        except Exception:
            pass
        results.append({"filename": path.name, "username": username})
    return results


def latest_test_result_dir() -> Path | None:
    result_root = REPO_ROOT / "artifacts" / "test-results"
    if not result_root.exists():
        return None

    candidates = [
        path
        for path in result_root.iterdir()
        if path.is_dir() and TIMESTAMP_DIR_PATTERN.match(path.name)
    ]
    if not candidates:
        return None
    return sorted(candidates, key=lambda item: item.name, reverse=True)[0]


def read_text_file(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    except Exception as exc:
        return f"Failed to read {path.name}: {exc}"


def parse_namespaces(namespace_output: str) -> set[str]:
    namespaces: set[str] = set()
    for line in namespace_output.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("NAME "):
            continue
        namespaces.add(stripped.split()[0])
    return namespaces


def checklist_value(content: str | None, must_contain: Iterable[str]) -> bool:
    if not content:
        return False
    if "FAIL:" in content:
        return False
    return all(marker in content for marker in must_contain)


def render_demo_checklist(namespace_output: str | None, kubeconfigs: list[dict[str, str]], latest_dir: Path | None) -> None:
    namespace_set = parse_namespaces(namespace_output or "")
    kubeconfig_files = {item["filename"] for item in kubeconfigs}

    rbac_text = read_text_file(latest_dir / "rbac-tests.txt") if latest_dir else None
    resource_text = read_text_file(latest_dir / "resource-tests.txt") if latest_dir else None
    network_text = read_text_file(latest_dir / "network-tests.txt") if latest_dir else None
    summary_text = read_text_file(latest_dir / "summary.txt") if latest_dir else None

    checks = [
        (
            "team-a/team-b namespaces created",
            {"team-a", "team-b"}.issubset(namespace_set),
        ),
        (
            "developer/viewer kubeconfigs generated",
            {
                "team-a-developer.kubeconfig",
                "team-a-viewer.kubeconfig",
                "team-b-developer.kubeconfig",
                "team-b-viewer.kubeconfig",
            }.issubset(kubeconfig_files),
        ),
        (
            "RBAC negative tests passed",
            checklist_value(
                rbac_text,
                [
                    "Developer A cannot get pods in team-b",
                    "Viewer A cannot create deployments in team-a",
                ],
            ),
        ),
        (
            "ResourceQuota and LimitRange tests passed",
            checklist_value(
                resource_text,
                [
                    "Normal workload succeeds inside quota and limits",
                    "Oversized workload is rejected by LimitRange",
                    "Quota-exceeding workload is rejected by ResourceQuota",
                ],
            ),
        ),
        (
            "NetworkPolicy same-namespace success and cross-namespace failure passed",
            checklist_value(
                network_text,
                [
                    "Pod in team-a can reach service in team-a over TCP",
                    "Pod in team-a cannot reach service in team-b over TCP",
                    "Pod in team-b cannot reach service in team-a over TCP",
                ],
            ),
        ),
        (
            "timestamped artifacts generated",
            latest_dir is not None and summary_text is not None,
        ),
    ]

    for label, value in checks:
        st.checkbox(label, value=value, disabled=True)


def main() -> None:
    st.set_page_config(page_title=APP_TITLE, layout="wide")
    st.title(APP_TITLE)
    st.caption("Local demo dashboard only. This is not a production portal and should be bound only to 127.0.0.1.")

    if not repo_is_valid():
        st.error(
            "This app could not confirm the repository structure. Start it from inside the DSAA4040 repository and ensure `scripts/`, `manifests/`, `artifacts/`, and `environment.yml` exist."
        )
        st.stop()

    warning = repo_warning()
    if warning:
        st.warning(warning)

    st.info(
        f"Repository root: `{REPO_ROOT}`\n\n"
        "Recommended start command:\n"
        "`streamlit run gui/app.py --server.address 127.0.0.1 --server.port 8501`"
    )

    if "action_output" not in st.session_state:
        st.session_state["action_output"] = "No automation action has been run from the dashboard yet."
    if "action_label" not in st.session_state:
        st.session_state["action_label"] = "Last action"

    st.header("Section A: Cluster Overview")
    nodes_result = run_command(["kubectl", "get", "nodes", "-o", "wide"], timeout=20)
    namespaces_result = run_command(["kubectl", "get", "ns"], timeout=20)

    col_a, col_b = st.columns(2)
    with col_a:
        render_command_result("kubectl get nodes -o wide", nodes_result)
    with col_b:
        render_command_result("kubectl get ns", namespaces_result)

    namespace_set = parse_namespaces(namespaces_result.output)
    existence_cols = st.columns(len(TENANTS))
    for idx, tenant in enumerate(TENANTS):
        with existence_cols[idx]:
            if tenant in namespace_set:
                st.success(f"{tenant} exists")
            else:
                st.warning(f"{tenant} not found")

    st.header("Section B: Tenant Overview")
    for tenant in TENANTS:
        with st.expander(f"{tenant} resources", expanded=(tenant == "team-a")):
            command_specs = [
                (f"kubectl get resourcequota -n {tenant}", ["kubectl", "get", "resourcequota", "-n", tenant]),
                (f"kubectl get limitrange -n {tenant}", ["kubectl", "get", "limitrange", "-n", tenant]),
                (f"kubectl get networkpolicy -n {tenant}", ["kubectl", "get", "networkpolicy", "-n", tenant]),
                (f"kubectl get rolebinding -n {tenant}", ["kubectl", "get", "rolebinding", "-n", tenant]),
            ]
            cols = st.columns(2)
            for index, (title, command) in enumerate(command_specs):
                with cols[index % 2]:
                    render_command_result(title, run_command(command, timeout=20), height=140)

    st.header("Section C: Generated Kubeconfigs")
    kubeconfigs = list_kubeconfigs()
    if kubeconfigs:
        st.table(kubeconfigs)
    else:
        st.warning("No kubeconfig files were found under `artifacts/kubeconfigs/` yet.")
    st.caption("Private keys are intentionally excluded. This dashboard never prints `.key` contents.")

    st.header("Section D: Automation Actions")
    st.caption("These buttons run the existing project scripts from the repository root with subprocess timeouts.")

    action_specs = [
        ("Run check-environment", ["bash", "scripts/check-environment.sh"], 120),
        ("Bootstrap cluster", ["bash", "scripts/bootstrap-cluster.sh"], 900),
        ("Onboard team-a", ["bash", "scripts/onboard-team.sh", "team-a"], 300),
        ("Onboard team-b", ["bash", "scripts/onboard-team.sh", "team-b"], 300),
        ("Run tests", ["bash", "scripts/run-tests.sh"], 1200),
    ]

    action_columns = st.columns(len(action_specs))
    for col, (label, command, timeout) in zip(action_columns, action_specs):
        with col:
            if st.button(label, use_container_width=True):
                result = run_command(command, timeout=timeout)
                timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
                st.session_state["action_label"] = f"{label} at {timestamp}"
                st.session_state["action_output"] = (
                    f"Command: {' '.join(command)}\n"
                    f"Return code: {result.returncode}\n"
                    f"Timed out: {result.timed_out}\n\n"
                    f"{result.output or '(no output)'}"
                )

    st.text_area(
        st.session_state["action_label"],
        value=st.session_state["action_output"],
        height=300,
        key="action-output-viewer",
        disabled=True,
    )

    st.header("Section E: Test Results Viewer")
    if st.button("Refresh test results", key="refresh-test-results"):
        st.rerun()

    latest_dir = latest_test_result_dir()
    if latest_dir is None:
        st.warning("No timestamped live test-results directory was found under `artifacts/test-results/` yet.")
    else:
        st.success(f"Latest test-results directory: `{latest_dir.relative_to(REPO_ROOT)}`")
        for filename in TEST_RESULT_FILES:
            path = latest_dir / filename
            content = read_text_file(path)
            if content is None:
                st.warning(f"`{filename}` is missing from the latest test-results directory.")
            else:
                st.text_area(
                    filename,
                    value=content,
                    height=220,
                    key=f"test-result-{filename}",
                    disabled=True,
                )

    st.header("Section F: Demo Checklist")
    render_demo_checklist(namespaces_result.output if namespaces_result.ok else None, kubeconfigs, latest_dir)


if __name__ == "__main__":
    main()
