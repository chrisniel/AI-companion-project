"""Generate/verify the Windows CPython 3.11 wheel lock with pinned pip's parser.

Resolution is performed by pip 26.1.2, not by this script. Generation validates
the resolved wheel closure against both project declarations before hashing it.
"""

import argparse
from email.parser import BytesParser
import hashlib
import importlib.metadata as metadata
import json
from pathlib import Path
import platform
import struct
import sys
import tomllib
import zipfile

from pip._vendor.packaging.requirements import Requirement
from pip._vendor.packaging.tags import sys_tags
from pip._vendor.packaging.utils import canonicalize_name, parse_wheel_filename


ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "backend/requirements.lock"
TARGET = 'python_version == "3.11" and sys_platform == "win32" and platform_machine == "AMD64" and platform_python_implementation == "CPython"'
RESOLVER = "26.1.2"


def require_target():
    if not (sys.implementation.name == "cpython" and sys.version_info[:2] == (3, 11)
            and sys.platform == "win32" and struct.calcsize("P") == 8
            and platform.machine() == "AMD64"):
        raise ValueError("Lock requires Windows x64 / CPython 3.11")
    if metadata.version("pip") != RESOLVER:
        raise ValueError("Lock tooling requires pip " + RESOLVER)


def project_roots():
    project = tomllib.loads((ROOT / "backend/pyproject.toml").read_text(encoding="utf-8"))["project"]
    roots = [Requirement(line.strip()) for line in (ROOT / "backend/requirements.txt").read_text().splitlines()
             if line.strip() and not line.lstrip().startswith("#")]
    declared = [Requirement(item) for item in project["dependencies"] + project["optional-dependencies"]["dev"]]
    if sorted(map(str, roots)) != sorted(map(str, declared)):
        raise ValueError("requirements.txt and pyproject runtime/dev declarations differ")
    return roots + [Requirement("pip==" + RESOLVER)]


def declaration_digest(roots):
    return hashlib.sha256(json.dumps(sorted(map(str, roots))).encode()).hexdigest()


def closure(packages, roots):
    """Check actual dependency metadata, including recursively requested extras."""
    pending = list(roots)
    active = {}
    while pending:
        req = pending.pop()
        name = canonicalize_name(req.name)
        if name not in packages or packages[name]["version"] not in req.specifier:
            raise ValueError("Missing or incompatible dependency: " + str(req))
        wanted = set(req.extras)
        if name in active and wanted <= active[name]:
            continue
        active.setdefault(name, set()).update(wanted)
        for value in packages[name]["requires"]:
            dependency = Requirement(value)
            if dependency.marker is None or any(dependency.marker.evaluate({"extra": extra})
                                                for extra in ["", *active[name]]):
                pending.append(dependency)
    if set(packages) != set(active):
        raise ValueError("Unexpected distributions outside declared dependency closure")
    return active


def generate(wheelhouse, roots):
    packages = {}
    compatible = set(sys_tags())
    for wheel in sorted(wheelhouse.glob("*.whl")):
        name, version, _, tags = parse_wheel_filename(wheel.name)
        if name in packages or not compatible.intersection(tags):
            raise ValueError("Duplicate or incompatible wheel: " + wheel.name)
        with zipfile.ZipFile(wheel) as archive:
            entries = [entry for entry in archive.namelist() if entry.endswith(".dist-info/METADATA")]
            if len(entries) != 1:
                raise ValueError("Ambiguous wheel metadata")
            info = BytesParser().parsebytes(archive.read(entries[0]))
        if canonicalize_name(info["Name"]) != name or info["Version"] != str(version):
            raise ValueError("Wheel filename/metadata mismatch")
        packages[name] = {"version": str(version), "requires": info.get_all("Requires-Dist", []),
                          "hash": hashlib.sha256(wheel.read_bytes()).hexdigest(), "wheel": wheel.name}
    extras = closure(packages, roots)
    lines = ["# Windows x64 / CPython 3.11 runtime + tests + pinned installer.",
             "# Generated on CPython " + platform.python_version() + " with pip " + RESOLVER + ".",
             "# One compatible wheel SHA256 per distribution; no source-build or other-platform claim.",
             "# declarations-sha256: " + declaration_digest(roots)]
    for name, package in sorted(packages.items()):
        suffix = "[" + ",".join(sorted(extras[name])) + "]" if extras[name] else ""
        lines += ["# " + package["wheel"],
                  f'{name}{suffix}=={package["version"]} ; {TARGET} --hash=sha256:{package["hash"]}']
    return "\n".join(lines) + "\n"


def read_lock(text, roots):
    if "# declarations-sha256: " + declaration_digest(roots) not in text.splitlines():
        raise ValueError("Lock declaration fingerprint differs")
    result = {}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        value, separator, digest = line.partition(" --hash=sha256:")
        req = Requirement(value)
        pins = list(req.specifier)
        name = canonicalize_name(req.name)
        if (not separator or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest)
                or str(req.marker) != TARGET or len(pins) != 1 or pins[0].operator != "==" or name in result):
            raise ValueError("Malformed or duplicate locked input")
        result[name] = {"version": pins[0].version, "requires": [], "extras": req.extras}
    return result


def verify(text, roots):
    expected = read_lock(text, roots)
    actual = {canonicalize_name(item.metadata["Name"]): {"version": item.version, "requires": item.requires or []}
              for item in metadata.distributions()}
    if {name: item["version"] for name, item in actual.items()} != {name: item["version"] for name, item in expected.items()}:
        raise ValueError("Installed distribution set/versions differ from the lock")
    extras = closure(actual, roots)
    if any(extras[name] != set(expected[name]["extras"]) for name in extras):
        raise ValueError("Required extras differ from locked input")
    print(json.dumps({name: item["version"] for name, item in sorted(actual.items())}, sort_keys=True))
    print("LOCK_VERIFIED", len(actual), "distributions; complete target closure and exact installed versions")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["generate", "verify"])
    parser.add_argument("--wheelhouse", type=Path)
    parser.add_argument("--lock", type=Path, default=LOCK)
    args = parser.parse_args()
    require_target()
    roots = project_roots()
    if args.operation == "generate":
        if args.wheelhouse is None:
            parser.error("generate requires --wheelhouse")
        args.lock.write_text(generate(args.wheelhouse, roots), encoding="utf-8")
        print("LOCK_GENERATED", args.lock)
    else:
        verify(args.lock.read_text(encoding="utf-8"), roots)


if __name__ == "__main__":
    main()
