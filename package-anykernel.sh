#!/usr/bin/env bash
set -Eeuo pipefail

==========================================

Sakata Kernel AnyKernel Packager

==========================================

WORKSPACE="${WORKSPACE:-/root/sakata-kleaf}"
KERNEL_DIR="${KERNEL_DIR:-${WORKSPACE}/msm-kernel}"
ANYKERNEL_DIR="${ANYKERNEL_DIR:-${KERNEL_DIR}/anykernel}"
IMAGE_GZ="${IMAGE_GZ:-${WORKSPACE}/bazel-bin/msm-kernel/kernel_aarch64/Image.gz}"
OUTPUT_DIR="${OUTPUT_DIR:-${KERNEL_DIR}}"

die() {
echo "ERROR: $*" >&2
exit 1
}

for tool in gzip zip unzip sha256sum; do
command -v "${tool}" >/dev/null 2>&1 ||
die "Program '${tool}' tidak ditemukan."
done

[[ -f "${IMAGE_GZ}" ]] ||
die "Image.gz tidak ditemukan: ${IMAGE_GZ}"

[[ -d "${ANYKERNEL_DIR}" ]] ||
die "Folder AnyKernel tidak ditemukan: ${ANYKERNEL_DIR}"

[[ -f "${ANYKERNEL_DIR}/anykernel.sh" ]] ||
die "anykernel.sh tidak ditemukan."

echo "Memeriksa Image.gz..."
gzip -t "${IMAGE_GZ}" ||
die "Image.gz rusak atau bukan file gzip yang valid."

mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(realpath -m "${OUTPUT_DIR}")"

echo "Membersihkan kernel lama dari AnyKernel..."
rm -f 
"${ANYKERNEL_DIR}/Image" 
"${ANYKERNEL_DIR}/Image.gz" 
"${ANYKERNEL_DIR}/Image.lz4" 
"${ANYKERNEL_DIR}/Image.gz-dtb"

echo "Menyalin Image.gz..."
install -m 0644 
"${IMAGE_GZ}" 
"${ANYKERNEL_DIR}/Image.gz"

SOURCE_HASH="$(sha256sum "${IMAGE_GZ}" | awk '{print $1}')"
COPIED_HASH="$(sha256sum "${ANYKERNEL_DIR}/Image.gz" | awk '{print $1}')"

[[ "${SOURCE_HASH}" == "${COPIED_HASH}" ]] ||
die "Checksum Image.gz hasil salinan tidak cocok."

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

KERNEL_ENTRIES="$(
unzip -Z1 "${ZIP_PATH}" |
grep -E '(^|/)Image(..*)?$' || true
)"

if [[ "${KERNEL_ENTRIES}" != "Image.gz" ]]; then
echo "Kernel entries yang ditemukan:"
printf '%s\n' "${KERNEL_ENTRIES}"
die "ZIP harus hanya memiliki Image.gz sebagai kernel image."
fi

echo
echo "=========================================="
echo "ANYKERNEL BERHASIL DIBUAT"
echo "=========================================="
echo "File    : ${ZIP_PATH}"
echo "Kernel  : Image.gz"
echo "Tanggal : ${TIMESTAMP}"
echo
ls -lh "${ZIP_PATH}"
echo
sha256sum "${ZIP_PATH}"
echo "=========================================="
