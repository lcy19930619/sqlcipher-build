#!/bin/bash
set -e

SQLCIPHER_VERSION="4.5.6"
ARCH=${ARCH:-$(uname -m)}
BUILD_DIR="build/macos-${ARCH}"
SRC_DIR="sqlcipher-src"

echo "Building SQLCipher ${SQLCIPHER_VERSION} for macOS ${ARCH}"

# Download SQLCipher source
if [ ! -d "$SRC_DIR" ]; then
    echo "Downloading SQLCipher source..."
    curl -L "https://github.com/sqlcipher/sqlcipher/archive/v${SQLCIPHER_VERSION}.tar.gz" -o sqlcipher.tar.gz
    tar -xzf sqlcipher.tar.gz
    mv "sqlcipher-${SQLCIPHER_VERSION}" "$SRC_DIR"
    rm sqlcipher.tar.gz
fi

# Create build directory
mkdir -p "${BUILD_DIR}/lib" "${BUILD_DIR}/include"

# Build
cd "$SRC_DIR"

# Configure for specific architecture
export CFLAGS="-arch ${ARCH} -DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL"
export LDFLAGS="-arch ${ARCH} -framework Security -framework Foundation"

if [ "$ARCH" = "arm64" ]; then
    export CFLAGS="$CFLAGS -target arm64-apple-macos11"
    export LDFLAGS="$LDFLAGS -target arm64-apple-macos11"
fi

./configure \
    --enable-tempstore=yes \
    --enable-fts5 \
    --enable-json1 \
    --disable-shared \
    --enable-static \
    --prefix="$(pwd)/../${BUILD_DIR}" \
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS"

make clean
make -j$(sysctl -n hw.ncpu)
make install

cd ..

# Copy files to final location
cp "${BUILD_DIR}/lib/libsqlcipher.a" "${BUILD_DIR}/lib/"
cp "${BUILD_DIR}/include/sqlite3.h" "${BUILD_DIR}/include/"

echo "Build completed successfully!"
echo "Output:  ${BUILD_DIR}"