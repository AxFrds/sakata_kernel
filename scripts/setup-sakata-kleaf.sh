#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE="${1:-/root/sakata-kleaf}"

ENV_FILE="${WORKSPACE}/build/kernel/_setup_env.sh"
STAMP_FILE="${WORKSPACE}/build/kernel/kleaf/impl/stamp.bzl"
KERNEL_ENV_FILE="${WORKSPACE}/build/kernel/kleaf/impl/kernel_env.bzl"

for file in \
    "${ENV_FILE}" \
    "${STAMP_FILE}" \
    "${KERNEL_ENV_FILE}"
do
    if [[ ! -f "${file}" ]]; then
        echo "Error: file tidak ditemukan: ${file}" >&2
        exit 1
    fi
done

python3 - "${ENV_FILE}" "${STAMP_FILE}" "${KERNEL_ENV_FILE}" <<'PY'
from pathlib import Path
import re
import sys

env_file = Path(sys.argv[1])
stamp_file = Path(sys.argv[2])
kernel_env_file = Path(sys.argv[3])

# Identitas dan zona waktu.
text = env_file.read_text()

rules = [
    (r"^export TZ=.*$", "export TZ=Asia/Jakarta"),
    (
        r"^export KBUILD_BUILD_HOST=.*$",
        "export KBUILD_BUILD_HOST=sakataprjkt.xyz",
    ),
    (
        r"^export KBUILD_BUILD_USER=.*$",
        "export KBUILD_BUILD_USER=axfrds",
    ),
]

for pattern, replacement in rules:
    text, count = re.subn(
        pattern,
        replacement,
        text,
        count=1,
        flags=re.MULTILINE,
    )

    if count != 1:
        raise SystemExit(f"Pola tidak ditemukan: {pattern}")

env_file.write_text(text)

# Hilangkan android15-8-maybe-dirty dari localversion Kleaf.
stamp = stamp_file.read_text()

stamp, count = re.subn(
    r"^(\s*)echo \$scmversion\s*$",
    r"\1echo",
    stamp,
    count=1,
    flags=re.MULTILINE,
)

if count == 0 and not re.search(r"^\s*echo\s*$", stamp, re.MULTILINE):
    raise SystemExit("Baris localversion pada stamp.bzl tidak ditemukan")

stamp_file.write_text(stamp)

# Override user terakhir yang sebelumnya dipaksa menjadi kleaf.
kernel_env = kernel_env_file.read_text()

kernel_env, count = re.subn(
    r"export KBUILD_BUILD_USER=(?:kleaf|axfrds)",
    "export KBUILD_BUILD_USER=axfrds",
    kernel_env,
    count=1,
)

if count != 1:
    raise SystemExit("KBUILD_BUILD_USER di kernel_env.bzl tidak ditemukan")

kernel_env_file.write_text(kernel_env)

print("Konfigurasi Kleaf Sakata berhasil diterapkan.")
PY

echo
echo "===== HASIL KONFIGURASI ====="

grep -nE \
  '^export TZ=|KBUILD_BUILD_USER=|KBUILD_BUILD_HOST=' \
  "${ENV_FILE}" \
  "${KERNEL_ENV_FILE}"

echo
echo "Workspace: ${WORKSPACE}"
