#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_DIR}"

VERSION=$(grep -m1 "version:" "${PROJECT_DIR}/meson.build" | sed -E "s/.*'([^']+)'.*/\1/")
RPM_ROOT="${PROJECT_DIR}/rpmbuild"

echo "=== Building RPM package for imladris v${VERSION} ==="

rm -rf "${RPM_ROOT}"
mkdir -p "${RPM_ROOT}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

cp "${PROJECT_DIR}/packaging/imladris.spec" "${RPM_ROOT}/SPECS/imladris.spec"

# Package source tarball with root directory imladris-${VERSION}
TAR_TMP=$(mktemp -d)
mkdir -p "${TAR_TMP}/imladris-${VERSION}"

tar --exclude-vcs \
    --exclude='./build*' \
    --exclude='./rpmbuild' \
    --exclude='./deb-root' \
    --exclude='*.deb' \
    --exclude='*.rpm' \
    --exclude='*.flatpak' \
    --exclude='repo' \
    -cf - . | tar -xf - -C "${TAR_TMP}/imladris-${VERSION}"

tar -czf "${RPM_ROOT}/SOURCES/imladris-${VERSION}.tar.gz" -C "${TAR_TMP}" "imladris-${VERSION}"
rm -rf "${TAR_TMP}"

echo "--> Running rpmbuild..."
rpmbuild --define "_topdir ${RPM_ROOT}" -ba "${RPM_ROOT}/SPECS/imladris.spec"

# Copy resulting RPM packages to project root
find "${RPM_ROOT}/RPMS" -type f -name "*.rpm" -exec cp {} "${PROJECT_DIR}/" \;
find "${RPM_ROOT}/SRPMS" -type f -name "*.rpm" -exec cp {} "${PROJECT_DIR}/" \;

echo "=== RPM Build Complete ==="
ls -lh "${PROJECT_DIR}"/*.rpm
