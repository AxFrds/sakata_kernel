#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE="/root/sakata-kleaf"
ENV_FILE="${WORKSPACE}/build/kernel/_setup_env.sh"
LOG_FILE="${WORKSPACE}/build-sakata.log"

cd "${WORKSPACE}"

BUILD_TIMESTAMP="$(TZ=Asia/Jakarta date '+%Y-%m-%d %H:%M:%S')"

echo "=========================================="
echo "Sakata Kernel Kleaf Build"
echo "User      : axfrds"
echo "Host      : sakataprjkt.xyz"
echo "Timestamp : ${BUILD_TIMESTAMP}"
echo "=========================================="

python3 - "${ENV_FILE}" "${BUILD_TIMESTAMP}" <<'PY'
from pathlib import Path
import re
import sys

env_file = Path(sys.argv[1])
timestamp = sys.argv[2]

text = env_file.read_text()

replacement = f'export KBUILD_BUILD_TIMESTAMP="{timestamp}"'

text, count = re.subn(
    r'^export KBUILD_BUILD_TIMESTAMP=.*$',
    replacement,
    text,
    count=1,
    flags=re.MULTILINE,
)

if count == 0:
    text = text.rstrip() + "\n" + replacement + "\n"

env_file.write_text(text)
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
