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

# Detect OpenSSL installation
OPENSSL_PATH=""
if [ -d "/usr/include/openssl" ] && [ -d "/usr/lib" ]; then
    # System OpenSSL (typical for apt-installed libssl-dev)
    OPENSSL_PATH="/usr"
elif [ -d "/usr/local/include/openssl" ] && [ -d "/usr/local/lib" ]; then
    # Custom OpenSSL in /usr/local
    OPENSSL_PATH="/usr/local"
fi

# Configure for specific architecture
export CFLAGS="${CFLAGS} -DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL"
export CC="${CC:-gcc}"

if [ -n "$OPENSSL_PATH" ]; then
    echo "Using OpenSSL from: ${OPENSSL_PATH}"
    export CFLAGS="${CFLAGS} -I${OPENSSL_PATH}/include"
    export LDFLAGS="${LDFLAGS} -L${OPENSSL_PATH}/lib -lcrypto"
    
    # Handle different library directory names (lib, lib64, lib/x86_64-linux-gnu, etc.)
    if [ -d "${OPENSSL_PATH}/lib/x86_64-linux-gnu" ]; then
        export LDFLAGS="${LDFLAGS} -L${OPENSSL_PATH}/lib/x86_64-linux-gnu"
    elif [ -d "${OPENSSL_PATH}/lib64" ]; then
        export LDFLAGS="${LDFLAGS} -L${OPENSSL_PATH}/lib64"
    fi
    
    # Set PKG_CONFIG_PATH if pkgconfig exists
    if [ -d "${OPENSSL_PATH}/lib/pkgconfig" ]; then
        export PKG_CONFIG_PATH="${OPENSSL_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH}"
    elif [ -d "${OPENSSL_PATH}/lib/x86_64-linux-gnu/pkgconfig" ]; then
        export PKG_CONFIG_PATH="${OPENSSL_PATH}/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
    fi
else
    echo "Warning: OpenSSL not found in standard locations, trying system defaults"
    export LDFLAGS="${LDFLAGS} -lcrypto"
fi

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
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS"

make clean
make -j$(nproc)
make install

cd ..

echo "Build completed successfully!"
echo "Output: ${BUILD_DIR}"