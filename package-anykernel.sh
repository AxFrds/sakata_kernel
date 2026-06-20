#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# Sakata Kernel AnyKernel Packager
# ==========================================

WORKSPACE="${WORKSPACE:-/root/sakata-kleaf}"
KERNEL_DIR="${KERNEL_DIR:-${WORKSPACE}/msm-kernel}"
ANYKERNEL_DIR="${ANYKERNEL_DIR:-${KERNEL_DIR}/anykernel}"
SOURCE_IMAGE="${SOURCE_IMAGE:-${WORKSPACE}/bazel-bin/msm-kernel/kernel_aarch64/Image.gz}"
OUTPUT_DIR="${OUTPUT_DIR:-${KERNEL_DIR}}"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

for tool in gzip zip unzip sha256sum cmp; do
    command -v "${tool}" >/dev/null 2>&1 ||
        die "Program '${tool}' tidak ditemukan."
done

[[ -f "${SOURCE_IMAGE}" ]] ||
    die "Image.gz tidak ditemukan: ${SOURCE_IMAGE}"

[[ -d "${ANYKERNEL_DIR}" ]] ||
    die "Folder AnyKernel tidak ditemukan: ${ANYKERNEL_DIR}"

[[ -f "${ANYKERNEL_DIR}/anykernel.sh" ]] ||
    die "anykernel.sh tidak ditemukan."

echo "Memeriksa Image.gz..."
gzip -t "${SOURCE_IMAGE}" ||
    die "Image.gz rusak atau bukan gzip yang valid."

mkdir -p "${OUTPUT_DIR}"

echo "Membersihkan kernel image lama..."
rm -f \
    "${ANYKERNEL_DIR}/Image" \
    "${ANYKERNEL_DIR}/Image.gz" \
    "${ANYKERNEL_DIR}/Image.lz4" \
    "${ANYKERNEL_DIR}/Image.gz-dtb"

echo "Menyalin Image.gz hasil Bazel..."
cp -f "${SOURCE_IMAGE}" "${ANYKERNEL_DIR}/Image.gz"
chmod 0644 "${ANYKERNEL_DIR}/Image.gz"

cmp -s \
    "${SOURCE_IMAGE}" \
    "${ANYKERNEL_DIR}/Image.gz" ||
    die "Image.gz hasil salinan tidak identik."

TIMESTAMP="$(TZ=Asia/Jakarta date '+%Y%m%d-%H%M')"
ZIP_NAME="Sakata-Kernel-${TIMESTAMP}.zip"
ZIP_PATH="${OUTPUT_DIR}/${ZIP_NAME}"

rm -f "${ZIP_PATH}"

echo "Membuat ${ZIP_NAME}..."

(
    cd "${ANYKERNEL_DIR}"

    zip -r9 "${ZIP_PATH}" . \
        -x '.git/*' \
           '.github/*' \
           '*.zip' \
           '*.backup*' \
           '*~'
)

echo "Memeriksa integritas ZIP..."
unzip -tq "${ZIP_PATH}" >/dev/null ||
    die "ZIP gagal dalam pemeriksaan integritas."

KERNEL_FILES="$(
    unzip -Z1 "${ZIP_PATH}" |
    sed 's#^\./##' |
    grep -E '(^|/)Image(\.gz|\.lz4|\.gz-dtb)?$' || true
)"

if [[ "${KERNEL_FILES}" != "Image.gz" ]]; then
    echo "Kernel image di dalam ZIP:"
    printf '%s\n' "${KERNEL_FILES}"
    die "ZIP harus hanya berisi Image.gz sebagai kernel image."
fi

echo
echo "=========================================="
echo "ANYKERNEL BERHASIL DIBUAT"
echo "=========================================="
echo "Output : ${ZIP_PATH}"
echo "Kernel : Image.gz"
echo
ls -lh "${ZIP_PATH}"
sha256sum "${ZIP_PATH}"
echo "=========================================="
