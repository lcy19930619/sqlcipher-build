#!/bin/bash
set -e

SQLCIPHER_VERSION="4.5.6"
ARCH=${ARCH:-x64}
BUILD_DIR="build/windows-${ARCH}"
SRC_DIR="sqlcipher-src"

echo "Building SQLCipher ${SQLCIPHER_VERSION} for Windows ${ARCH}"

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

# Detect OpenSSL installation (MSYS2/MinGW)
OPENSSL_PATH=""
MSYS_SYSTEM="${MSYSTEM:-MINGW64}"

# Detect based on MSYS2 system type
if [ "$MSYS_SYSTEM" = "MINGW64" ]; then
    if [ -d "/mingw64/include/openssl" ] && [ -d "/mingw64/lib" ]; then
        OPENSSL_PATH="/mingw64"
    fi
elif [ "$MSYS_SYSTEM" = "MINGW32" ]; then
    if [ -d "/mingw32/include/openssl" ] && [ -d "/mingw32/lib" ]; then
        OPENSSL_PATH="/mingw32"
    fi
elif [ "$MSYS_SYSTEM" = "MSYS" ]; then
    # Fallback for MSYS environment
    if [ -d "/usr/include/openssl" ] && [ -d "/usr/lib" ]; then
        OPENSSL_PATH="/usr"
    fi
fi

# Configure for specific architecture
export CFLAGS="-DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL"

if [ -n "$OPENSSL_PATH" ]; then
    echo "Using OpenSSL from: ${OPENSSL_PATH}"
    export CFLAGS="${CFLAGS} -I${OPENSSL_PATH}/include"
    export LDFLAGS="${LDFLAGS} -L${OPENSSL_PATH}/lib -lcrypto"
    
    # Set PKG_CONFIG_PATH if pkgconfig exists
    if [ -d "${OPENSSL_PATH}/lib/pkgconfig" ]; then
        export PKG_CONFIG_PATH="${OPENSSL_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH}"
    fi
else
    echo "Warning: OpenSSL not found in standard MSYS2/MinGW locations, trying system defaults"
    export LDFLAGS="${LDFLAGS} -lcrypto"
fi

if [ "$ARCH" = "x86" ]; then
    export CFLAGS="$CFLAGS -m32"
    export LDFLAGS="$LDFLAGS -m32"
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
make -j$(nproc)
make install

cd ..

echo "Build completed successfully!"
echo "Output: ${BUILD_DIR}"