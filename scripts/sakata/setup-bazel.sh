#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DEPS=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --install-deps)
      INSTALL_DEPS=1
      ;;
    --force)
      FORCE=1
      ;;
    -h|--help)
      cat <<'HELP'
Sakata Bazel setup helper

Usage:
  ./scripts/sakata/setup-bazel.sh [--install-deps] [--force]

Options:
  --install-deps   Install common build dependencies with apt-get
  --force          Recreate tools/bazel wrapper even if it already exists

This script prepares the Bazel/Bazelisk wrapper for Sakata Kleaf builds.
It should be run from inside the msm-kernel source tree, or directly via
scripts/sakata/setup-bazel.sh.
HELP
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

log() {
  echo "[Sakata Bazel Setup] $*"
}

die() {
  echo "[Sakata Bazel Setup] ERROR: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
WORKSPACE="${KLEAF_WORKSPACE:-$(cd "${REPO_DIR}/.." && pwd -P)}"

TOOLS_DIR="${WORKSPACE}/tools"
BAZEL_WRAPPER="${TOOLS_DIR}/bazel"
BAZELISK_BIN="${TOOLS_DIR}/bazelisk"

log "Repo      : ${REPO_DIR}"
log "Workspace : ${WORKSPACE}"

[ -f "${REPO_DIR}/BUILD.bazel" ] || die "BUILD.bazel tidak ditemukan di ${REPO_DIR}"
mkdir -p "${TOOLS_DIR}"

if [ "${INSTALL_DEPS}" -eq 1 ]; then
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing common build dependencies..."
    if [ "$(id -u)" -eq 0 ]; then
      APT="apt-get"
    elif command -v sudo >/dev/null 2>&1; then
      APT="sudo apt-get"
    else
      die "Butuh root atau sudo untuk --install-deps"
    fi

    ${APT} update
    ${APT} install -y \
      ca-certificates \
      curl \
      git \
      unzip \
      zip \
      python3 \
      openjdk-17-jdk \
      rsync \
      bc \
      bison \
      flex \
      libssl-dev \
      libelf-dev \
      lz4 \
      zstd
  else
    log "apt-get tidak ditemukan, skip install dependencies."
  fi
fi

if [ -x "${BAZEL_WRAPPER}" ] && [ "${FORCE}" -eq 0 ]; then
  log "tools/bazel sudah ada, hanya memastikan executable."
  chmod +x "${BAZEL_WRAPPER}"
else
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64|amd64)
      BAZELISK_ARCH="amd64"
      ;;
    aarch64|arm64)
      BAZELISK_ARCH="arm64"
      ;;
    *)
      die "Arsitektur tidak didukung otomatis: ${ARCH}"
      ;;
  esac

  BAZELISK_URL="https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-${BAZELISK_ARCH}"

  log "Downloading Bazelisk: ${BAZELISK_URL}"
  curl -L --fail --retry 3 --connect-timeout 20 \
    -o "${BAZELISK_BIN}" \
    "${BAZELISK_URL}"

  chmod +x "${BAZELISK_BIN}"

  cat > "${BAZEL_WRAPPER}" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [ -x "${SCRIPT_DIR}/bazelisk" ]; then
  exec "${SCRIPT_DIR}/bazelisk" "$@"
fi

if command -v bazelisk >/dev/null 2>&1; then
  exec bazelisk "$@"
fi

if command -v bazel >/dev/null 2>&1; then
  exec bazel "$@"
fi

echo "ERROR: bazel/bazelisk tidak ditemukan." >&2
exit 127
WRAPPER

  chmod +x "${BAZEL_WRAPPER}"
fi

if [ ! -d "${WORKSPACE}/build/kernel" ]; then
  log "WARNING: ${WORKSPACE}/build/kernel tidak ditemukan."
  log "Pastikan workspace Kleaf lengkap sebelum build."
fi

log "Checking Bazel wrapper..."
"${BAZEL_WRAPPER}" version >/dev/null || die "tools/bazel gagal dijalankan"

log "Bazel setup selesai."
log "Gunakan:"
log "  cd ${WORKSPACE}"
log "  tools/bazel build //msm-kernel:kernel_aarch64"
