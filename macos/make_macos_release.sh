#!/bin/sh -e

VERSION=$(grep '^[Vv]ersion:' pandoc.cabal | awk '{print $2;}')
ARTIFACTS=macos-release-candidate
RESOURCES=${ARTIFACTS}/Resources
ROOT=${ARTIFACTS}/pandoc
DEST=${ROOT}/usr/local
ME=$(whoami)

# Build the pandoc binary and put it in .
cabal update
cabal install pandoc-cli -fembed_data_files -fserver -flua --installdir=. \
    --install-method=copy --overwrite-policy=always
echo "Built executable..."

# Create directories
echo "Creating ${ARTIFACTS} directory..."
mkdir -p ${ARTIFACTS}
mkdir -p ${RESOURCES}
mkdir -p ${DEST}/bin
mkdir -p ${DEST}/share/man/man1

# Copy binary and strip it
echo "Copying executable..."
cp ./pandoc ${DEST}/bin/
strip ${DEST}/bin/pandoc

# Copy man pages and license
echo "Copying manuals and license..."
cp man/pandoc.1 ${DEST}/share/man/man1/pandoc.1
cp man/pandoc-server.1 ${DEST}/share/man/man1/pandoc-server.1
cp man/pandoc-lua.1 ${DEST}/share/man/man1/pandoc-lua.1
./pandoc -s COPYING.md -Vpagetitle=License -o ${RESOURCES}/license.html

# Prepare distribution directory; after downloading, run 'make' to notarize
echo "Preparing distribution directory..."
chown -R "$ME:staff" "${ROOT}"
sed -e "s/PANDOCVERSION/${VERSION}/" macos/distribution.xml.in > ${ARTIFACTS}/distribution.xml
cp macos/Makefile ${ARTIFACTS}/
echo "${VERSION}" > "${ARTIFACTS}/version.txt"

ls -R ${ARTIFACTS}
echo "Finished..."
