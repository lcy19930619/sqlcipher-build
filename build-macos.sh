#!/bin/bash
set -e

SQLCIPHER_VERSION="4.5.6"
ARCH=${ARCH:-$(uname -m)}
BUILD_DIR="build/macos-${ARCH}"
SRC_DIR="sqlcipher-src"

echo "========================================"
echo "Building SQLCipher ${SQLCIPHER_VERSION} for macOS ${ARCH}"
echo "========================================"

# Download SQLCipher source
if [ !  -d "$SRC_DIR" ]; then
    echo "📦 Downloading SQLCipher source..."
    curl -L "https://github.com/sqlcipher/sqlcipher/archive/v${SQLCIPHER_VERSION}.tar.gz" -o sqlcipher.tar.gz
    tar -xzf sqlcipher.tar.gz
    mv "sqlcipher-${SQLCIPHER_VERSION}" "$SRC_DIR"
    rm sqlcipher.tar.gz
else
    echo "✅ Source directory already exists, skipping download"
fi

# Create build directory
mkdir -p "${BUILD_DIR}/lib" "${BUILD_DIR}/include"

# Build
cd "$SRC_DIR"

# Clean previous builds
if [ -f "Makefile" ]; then
    make distclean || true
fi

# Detect OpenSSL (environment variable takes precedence)
if [ -z "$OPENSSL_ROOT_DIR" ]; then
    echo "🔍 Detecting OpenSSL installation..."
    if [ -d "/opt/homebrew/opt/openssl@3" ]; then
        export OPENSSL_ROOT_DIR="/opt/homebrew/opt/openssl@3"
    elif [ -d "/usr/local/opt/openssl@3" ]; then
        export OPENSSL_ROOT_DIR="/usr/local/opt/openssl@3"
    elif [ -d "/opt/homebrew/opt/openssl@1.1" ]; then
        export OPENSSL_ROOT_DIR="/opt/homebrew/opt/openssl@1.1"
    elif [ -d "/usr/local/opt/openssl@1.1" ]; then
        export OPENSSL_ROOT_DIR="/usr/local/opt/openssl@1.1"
    fi
fi

if [ -z "$OPENSSL_ROOT_DIR" ]; then
    echo "❌ ERROR: Could not find OpenSSL installation"
    exit 1
fi

echo "✅ Using OpenSSL from: ${OPENSSL_ROOT_DIR}"

# Set up environment variables
export PKG_CONFIG_PATH="${OPENSSL_ROOT_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"
export LDFLAGS="-L${OPENSSL_ROOT_DIR}/lib -arch ${ARCH} -framework Security -framework Foundation"
export CPPFLAGS="-I${OPENSSL_ROOT_DIR}/include"
export CFLAGS="-arch ${ARCH} -DSQLITE_HAS_CODEC -DSQLCIPHER_CRYPTO_OPENSSL -I${OPENSSL_ROOT_DIR}/include"

# Architecture-specific settings
if [ "$ARCH" = "arm64" ]; then
    export CFLAGS="$CFLAGS -target arm64-apple-macos11"
    export LDFLAGS="$LDFLAGS -target arm64-apple-macos11"
elif [ "$ARCH" = "x86_64" ]; then
    export CFLAGS="$CFLAGS -target x86_64-apple-macos10.15"
    export LDFLAGS="$LDFLAGS -target x86_64-apple-macos10.15"
fi

echo "🔧 Configuration:"
echo "  ARCH: ${ARCH}"
echo "  CFLAGS: ${CFLAGS}"
echo "  LDFLAGS: ${LDFLAGS}"
echo "  PKG_CONFIG_PATH: ${PKG_CONFIG_PATH}"

# Configure
echo "⚙️  Running configure..."
./configure \
    --enable-tempstore=yes \
    --enable-fts5 \
    --enable-json1 \
    --disable-shared \
    --enable-static \
    --prefix="$(pwd)/../${BUILD_DIR}" \
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    CPPFLAGS="$CPPFLAGS"

# Build
echo "🔨 Building (using $(sysctl -n hw.ncpu) cores)..."
make -j$(sysctl -n hw.ncpu)

# Install
echo "📦 Installing..."
make install

cd ..

echo "✅ Build completed successfully!"
echo "📂 Output directory: ${BUILD_DIR}"
echo "📄 Files created:"
ls -lh "${BUILD_DIR}/lib/" || true
ls -lh "${BUILD_DIR}/include/" || true