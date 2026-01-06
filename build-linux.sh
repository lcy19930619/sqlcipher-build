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
    
    # Determine the correct library path
    LIB_PATH="${OPENSSL_PATH}/lib"
    
    # Handle different library directory names (lib, lib64, lib/<multiarch>, etc.)
    # Check for multiarch directory first (e.g., lib/x86_64-linux-gnu, lib/aarch64-linux-gnu)
    if [ -d "${OPENSSL_PATH}/lib" ]; then
        for dir in "${OPENSSL_PATH}"/lib/*-linux-gnu* "${OPENSSL_PATH}"/lib/*-linux-*; do
            if [ -d "$dir" ] && [ -f "$dir/libcrypto.so" -o -f "$dir/libcrypto.a" ]; then
                LIB_PATH="$dir"
                break
            fi
        done
    fi
    
    # Fall back to lib64 if it exists and we haven't found a better match
    if [ "$LIB_PATH" = "${OPENSSL_PATH}/lib" ] && [ -d "${OPENSSL_PATH}/lib64" ]; then
        if [ -f "${OPENSSL_PATH}/lib64/libcrypto.so" -o -f "${OPENSSL_PATH}/lib64/libcrypto.a" ]; then
            LIB_PATH="${OPENSSL_PATH}/lib64"
        fi
    fi
    
    export LDFLAGS="${LDFLAGS} -L${LIB_PATH} -lcrypto"
    
    # Set PKG_CONFIG_PATH if pkgconfig exists
    if [ -d "${OPENSSL_PATH}/lib/pkgconfig" ]; then
        export PKG_CONFIG_PATH="${OPENSSL_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH}"
    else
        # Check for multiarch pkgconfig directories
        for dir in "${OPENSSL_PATH}"/lib/*-linux-gnu*/pkgconfig "${OPENSSL_PATH}"/lib/*-linux-*/pkgconfig; do
            if [ -d "$dir" ]; then
                export PKG_CONFIG_PATH="${dir}:${PKG_CONFIG_PATH}"
                break
            fi
        done
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