#!/bin/bash
set -e

SQLCIPHER_VERSION="4.5.6"
ARCH=${ARCH:-$(uname -m)}
BUILD_DIR="build/linux-${ARCH}"
SRC_DIR="sqlcipher-src"

echo "Building SQLCipher ${SQLCIPHER_VERSION} for Linux ${ARCH}"

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
export CFLAGS="${CFLAGS} -DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL"
export CC="${CC:-gcc}"

HOST_FLAG=""
if [ "$ARCH" = "arm64" ]; then
    HOST_FLAG="--host=aarch64-linux-gnu"
elif [ "$ARCH" = "armv7" ]; then
    HOST_FLAG="--host=arm-linux-gnueabihf"
fi

./configure \
    $HOST_FLAG \
    --enable-tempstore=yes \
    --enable-fts5 \
    --enable-json1 \
    --disable-shared \
    --enable-static \
    --prefix="$(pwd)/../${BUILD_DIR}" \
    CC="$CC" \
    CFLAGS="$CFLAGS"

make clean
make -j$(nproc)
make install

cd ..

echo "Build completed successfully!"
echo "Output: ${BUILD_DIR}"