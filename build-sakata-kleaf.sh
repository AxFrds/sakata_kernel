#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE="/root/sakata-kleaf"
ENV_FILE="${WORKSPACE}/build/kernel/_setup_env.sh"
LOG_FILE="${WORKSPACE}/build-sakata.log"

cd "${WORKSPACE}"

# Internal timestamp harus parseable oleh hermetic date Kleaf.
BUILD_TIMESTAMP_PARSE="$(LC_ALL=C TZ=Asia/Jakarta date '+%Y-%m-%d %H:%M:%S')"

# Tampilan manusia tetap full format WIB.
BUILD_TIMESTAMP_LABEL="$(LC_ALL=C TZ=Asia/Jakarta date '+%a %b %d %H:%M:%S WIB %Y')"

echo "=========================================="
echo "Sakata Kernel Kleaf Build"
echo "User      : axfrds"
echo "Host      : sakataprjkt.xyz"
echo "Timestamp : ${BUILD_TIMESTAMP_LABEL}"
echo "=========================================="

python3 - "${ENV_FILE}" "${BUILD_TIMESTAMP_PARSE}" <<'PY'
from pathlib import Path
import re
import sys

env_file = Path(sys.argv[1])
timestamp = sys.argv[2]

text = env_file.read_text()

def upsert_export(text, key, value):
    line = f'export {key}="{value}"'
    text, count = re.subn(
        rf'^export {key}=.*$',
        line,
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if count == 0:
        text = text.rstrip() + "\n" + line + "\n"
    return text

text = upsert_export(text, "TZ", "Asia/Jakarta")
text = upsert_export(text, "KBUILD_BUILD_TIMESTAMP", timestamp)

env_file.write_text(text)

print(f"Kbuild timestamp internal: {timestamp}")
print("Kbuild timezone display  : Asia/Jakarta / WIB")
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
