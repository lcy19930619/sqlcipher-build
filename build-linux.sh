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

# Detect or install OpenSSL
OPENSSL_INSTALLED=false
if pkg-config --exists openssl; then
    echo "OpenSSL already available via pkg-config"
    export CFLAGS="${CFLAGS} $(pkg-config --cflags openssl)"
    export LDFLAGS="${LDFLAGS} $(pkg-config --libs openssl)"
    OPENSSL_INSTALLED=true
elif [ -d "/usr/include/openssl" ] && [ -f "/usr/lib/libcrypto.so" ]; then
    echo "OpenSSL found in /usr"
    export CFLAGS="${CFLAGS} -I/usr/include"
    export LDFLAGS="${LDFLAGS} -L/usr/lib -lcrypto"
    OPENSSL_INSTALLED=true
elif [ -d "/usr/local/include/openssl" ] && [ -f "/usr/local/lib/libcrypto.so" ]; then
    echo "OpenSSL found in /usr/local"
    export CFLAGS="${CFLAGS} -I/usr/local/include"
    export LDFLAGS="${LDFLAGS} -L/usr/local/lib -lcrypto"
    OPENSSL_INSTALLED=true
fi

if [ "$OPENSSL_INSTALLED" = false ]; then
    echo "OpenSSL not found, installing libssl-dev..."
    sudo apt-get update
    sudo apt-get install -y libssl-dev
    # Re-check after install
    if pkg-config --exists openssl; then
        export CFLAGS="${CFLAGS} $(pkg-config --cflags openssl)"
        export LDFLAGS="${LDFLAGS} $(pkg-config --libs openssl)"
    else
        export CFLAGS="${CFLAGS} -I/usr/include"
        export LDFLAGS="${LDFLAGS} -L/usr/lib -lcrypto"
    fi
fi

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
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS"

make clean
make -j$(nproc)
make install

cd ..

echo "Build completed successfully!"
echo "Output: ${BUILD_DIR}"