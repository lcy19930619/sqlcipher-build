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

# Detect OpenSSL installation
OPENSSL_PATH=""
if [ -d "/opt/homebrew/opt/openssl@3" ]; then
    # Apple Silicon
    OPENSSL_PATH="/opt/homebrew/opt/openssl@3"
elif [ -d "/usr/local/opt/openssl@3" ]; then
    # Intel Mac
    OPENSSL_PATH="/usr/local/opt/openssl@3"
elif [ -d "/opt/homebrew/opt/openssl@1.1" ]; then
    OPENSSL_PATH="/opt/homebrew/opt/openssl@1.1"
elif [ -d "/usr/local/opt/openssl@1.1" ]; then
    OPENSSL_PATH="/usr/local/opt/openssl@1.1"
fi

# Configure for specific architecture
export CFLAGS="-arch ${ARCH} -DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL"
export LDFLAGS="-arch ${ARCH} -framework Security -framework Foundation"

if [ -n "$OPENSSL_PATH" ]; then
    echo "Using OpenSSL from: ${OPENSSL_PATH}"
    export CFLAGS="${CFLAGS} -I${OPENSSL_PATH}/include"
    export LDFLAGS="${LDFLAGS} -L${OPENSSL_PATH}/lib"
    export PKG_CONFIG_PATH="${OPENSSL_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH}"
fi

if [ "$ARCH" = "arm64" ]; then
    export CFLAGS="$CFLAGS -target arm64-apple-macos12"  # Updated to macOS 12 for better compatibility
    export LDFLAGS="$LDFLAGS -target arm64-apple-macos12"
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

echo "Build completed successfully!"
echo "Output: ${BUILD_DIR}"