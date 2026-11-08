"""Keep Python installs in CI reviewable: every direct requirement needs ==.

This gate intentionally covers pip/pip3 and python -m pip in workflow run
steps and Justfile recipes. It is a static check, not a general shell parser;
new installer forms should extend this gate and its fixtures together.
"""

from __future__ import annotations

import re
import shlex
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
PIN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*(?:\[[A-Za-z0-9,._-]+\])?==[A-Za-z0-9][A-Za-z0-9.!+_-]*")
INSTALL = re.compile(
    r"(?:^|[;&|]\s*)\s*(?:sudo\s+)?"
    r"(?:pip3?|python(?:3(?:\.\d+)?)?\s+-m\s+pip)\s+"
    r"(?:(?:--disable-pip-version-check|--no-input)\s+)*install\s+"
)
FLAGS = {"-q", "--quiet", "-U", "--upgrade", "--user", "--no-deps",
         "--no-cache-dir", "--require-hashes", "--break-system-packages",
         "--disable-pip-version-check", "--no-input"}


def logical_lines(text):
    """Join shell/requirements continuations without swallowing comments."""
    pending = ""
    start = 1
    for number, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("#"):
            continue
        if not pending:
            start = number
        pending += line.strip()
        if pending.endswith("\\"):
            pending = pending[:-1] + " "
            continue
        yield start, pending
        pending = ""
    if pending:
        yield start, pending


def requirement_errors(root, name, seen=()):
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()):
        return [f"requirements file outside repository: {name}"]
    if path in seen:
        return [f"recursive requirements file: {name}"]
    try:
        text = path.read_text()
    except OSError:
        return [f"missing requirements file: {name}"]
    errors = []
    for line, entry in logical_lines(text):
        entry = entry.split(" #", 1)[0].strip()
        if not entry:
            continue
        if entry.startswith(("-r ", "--requirement ", "--requirement=")):
            nested = entry.replace("=", " ", 1).split(maxsplit=1)[1]
            errors += requirement_errors(root, str(path.parent / nested), (*seen, path))
            continue
        # Hashes and environment markers do not change an exact version pin.
        package = entry.split(";", 1)[0].split(" --hash=", 1)[0].strip()
        if not PIN.fullmatch(package):
            errors.append(f"{name}:{line}: requirement must use an exact == version: {entry}")
    return errors


def install_errors(root, text, source):
    errors = []
    for line, command in logical_lines(text):
        for match in INSTALL.finditer(command):
            lexer = shlex.shlex(command[match.end():], posix=True, punctuation_chars=";&|<>")
            lexer.whitespace_split = True
            try:
                args = list(lexer)
            except ValueError as error:
                errors.append(f"{source}:{line}: cannot inspect pip install: {error}")
                continue
            i = 0
            while i < len(args):
                arg = args[i]
                i += 1
                if not arg:
                    errors.append(f"{source}:{line}: empty pip argument")
                    continue
                if arg.isdigit() and i < len(args) and args[i][0] in "<>":
                    arg = args[i]
                    i += 1
                if arg[0] in "<>":
                    i += 1  # redirection destination is not a package
                    continue
                if arg[0] in ";&|":
                    break
                if arg in FLAGS:
                    continue
                name = None
                if arg in ("-r", "--requirement"):
                    if i == len(args):
                        errors.append(f"{source}:{line}: missing requirements filename")
                        break
                    name = args[i]
                    i += 1
                elif arg.startswith("--requirement="):
                    name = arg.split("=", 1)[1]
                elif arg.startswith("-r"):
                    name = arg[2:]
                if name is not None:
                    errors += [f"{source}:{line}: {error}" for error in requirement_errors(root, name)]
                elif not PIN.fullmatch(arg):
                    errors.append(f"{source}:{line}: pip argument must use an exact == version: {arg}")
    return errors


def check_tree(root):
    errors = []
    paths = sorted((root / ".github/workflows").glob("*.yml"))
    paths += sorted((root / ".github/workflows").glob("*.yaml"))

    def inspect(node, source):
        if isinstance(node, yaml.MappingNode):
            for key, value in node.value:
                if key.value == "run" and isinstance(value, yaml.ScalarNode):
                    errors.extend(install_errors(root, value.value, f"{source}:{value.start_mark.line + 1}"))
                else:
                    inspect(value, source)
        elif isinstance(node, yaml.SequenceNode):
            for child in node.value:
                inspect(child, source)

    for path in paths:
        inspect(yaml.compose(path.read_text()), path.relative_to(root))
    justfile = root / "Justfile"
    if justfile.exists():
        errors.extend(install_errors(root, justfile.read_text(), "Justfile"))
    return errors


class PythonInstallPinTests(unittest.TestCase):
    def test_repository_installs_are_pinned(self):
        self.assertEqual(check_tree(ROOT), [])

    def test_install_forms(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "requirements.txt").write_text("# helpers\npyyaml==6.0.3\njsonschema==4.26.0\n")
            for command in (
                "pip install pyyaml==6.0.3 jsonschema==4.26.0",
                "pip3 install -q 'pyyaml==6.0.3' # comment",
                "python3 -m pip install --quiet -r requirements.txt",
                "pip install --requirement=requirements.txt",
                "pip install -rrequirements.txt",
                "pip install pyyaml==6.0.3 2>/dev/null || true",
                "# pip install unpinned",
                "echo 'pip install unpinned'",
            ):
                with self.subTest(command=command):
                    self.assertEqual(install_errors(root, command, "fixture"), [])
            for command in (
                "pip install pyyaml", "pip3 install pyyaml>=6",
                "python -m pip install pyyaml==6.*", "pip install -r missing.txt",
                "pip install pyyaml==6.0.3 jsonschema",
                "echo start && python3 -m pip install jsonschema",
                "pip install \\\n jsonschema", "pip install -r requirements.txt jsonschema",
                "pip install --requirement", "pip install git+https://example.com/pkg",
                "pip install ${PACKAGE}", "pip install pyyaml===6.0.3",
            ):
                with self.subTest(command=command):
                    self.assertTrue(install_errors(root, command, "fixture"))

    def test_requirements_reject_loose_nested_missing_and_cyclic_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for entry in ("pyyaml", "pyyaml>=6", "pyyaml==6.*", "-r missing.txt",
                          "-r requirements.txt", "pyyaml==6.0.3\njsonschema"):
                with self.subTest(entry=entry):
                    (root / "requirements.txt").write_text(entry)
                    self.assertTrue(requirement_errors(root, "requirements.txt"))
            (root / "nested.txt").write_text('pyyaml==6.0.3 ; python_version >= "3.10"\n')
            (root / "requirements.txt").write_text("-r nested.txt\njsonschema==4.26.0 \\\n --hash=sha256:abc\n")
            self.assertEqual(requirement_errors(root, "requirements.txt"), [])

    def test_workflow_requirements_regression(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            workflows = root / ".github/workflows"
            workflows.mkdir(parents=True)
            (workflows / "build.yml").write_text(
                "jobs:\n  check:\n    steps:\n"
                "      - run: python3 -m pip install -q -r tests/requirements.txt\n")
            (root / "tests").mkdir()
            requirements = root / "tests/requirements.txt"
            requirements.write_text("pyyaml\njsonschema\n")
            self.assertEqual(len(check_tree(root)), 2)
            requirements.write_text("pyyaml==6.0.3\njsonschema==4.26.0\n")
            self.assertEqual(check_tree(root), [])

    def test_workflow_and_justfile_discovery(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            workflows = root / ".github/workflows"
            workflows.mkdir(parents=True)
            for suffix in ("yml", "yaml"):
                (workflows / f"ci.{suffix}").write_text(
                    "jobs:\n  check:\n    steps:\n      - name: pip install harmless\n"
                    "        run: |\n          python3 -m pip install \\\n"
                    "            jsonschema\n")
            (root / "Justfile").write_text("check:\n    pip install --quiet jsonschema 2>/dev/null || true\n")
            errors = check_tree(root)
            self.assertEqual(len(errors), 3, errors)
            self.assertTrue(any("Justfile:2:" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
