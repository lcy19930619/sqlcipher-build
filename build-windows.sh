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

# Detect or install OpenSSL (assuming MSYS2)
OPENSSL_INSTALLED=false
if [ -d "/mingw64/include/openssl" ] && [ -f "/mingw64/lib/libcrypto.dll.a" ]; then
    echo "OpenSSL found in /mingw64"
    export CFLAGS="${CFLAGS} -I/mingw64/include"
    export LDFLAGS="${LDFLAGS} -L/mingw64/lib -lcrypto"
    OPENSSL_INSTALLED=true
elif [ -d "/usr/include/openssl" ] && [ -f "/usr/lib/libcrypto.dll.a" ]; then
    echo "OpenSSL found in /usr"
    export CFLAGS="${CFLAGS} -I/usr/include"
    export LDFLAGS="${LDFLAGS} -L/usr/lib -lcrypto"
    OPENSSL_INSTALLED=true
fi

if [ "$OPENSSL_INSTALLED" = false ]; then
    echo "OpenSSL not found, installing via pacman..."
    pacman -S --noconfirm mingw-w64-x86_64-openssl
    # Re-check
    if [ -d "/mingw64/include/openssl" ]; then
        export CFLAGS="${CFLAGS} -I/mingw64/include"
        export LDFLAGS="${LDFLAGS} -L/mingw64/lib -lcrypto"
    fi
fi

# Configure for specific architecture
export CFLAGS="${CFLAGS} -DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL"

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