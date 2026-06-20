#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE="/root/sakata-kleaf"
ENV_FILE="${WORKSPACE}/build/kernel/_setup_env.sh"
LOG_FILE="${WORKSPACE}/build-sakata.log"

cd "${WORKSPACE}"

BUILD_TIMESTAMP="$(TZ=Asia/Jakarta date '+%a, %d %b %Y %H:%M:%S WIB')"

echo "=========================================="
echo "Sakata Kernel Kleaf Build"
echo "User      : axfrds"
echo "Host      : sakataprjkt.xyz"
echo "Timestamp : ${BUILD_TIMESTAMP}"
echo "=========================================="

python3 - "${BUILD_TIMESTAMP}" <<'PY'
from pathlib import Path
import re
import sys

timestamp = sys.argv[1]
path = Path("build/kernel/_setup_env.sh")
text = path.read_text()

replacement = (
    'export KBUILD_BUILD_TIMESTAMP="'
    + timestamp.replace('"', '\\"')
    + '"'
)

text, count = re.subn(
    r"^export KBUILD_BUILD_TIMESTAMP=.*$",
    replacement,
    text,
    count=1,
    flags=re.MULTILINE,
)

if count != 1:
    raise SystemExit(
        "Baris KBUILD_BUILD_TIMESTAMP tidak ditemukan"
    )

path.write_text(text)
print(f"Timestamp Kleaf: {timestamp}")
PY

tools/bazel shutdown
rm -f "${LOG_FILE}"

set -o pipefail

tools/bazel \
  --host_jvm_args=-Xmx1536m \
  build \
  --jobs=2 \
  --local_resources=memory=3072 \
  --verbose_failures \
  //msm-kernel:kernel_aarch64 \
  2>&1 | tee "${LOG_FILE}"

BUILD_RC=${PIPESTATUS[0]}
echo "Bazel exit code: ${BUILD_RC}"
exit "${BUILD_RC}"
