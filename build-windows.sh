$ErrorActionPreference = "Stop"

$SQLCIPHER_VERSION = "4.5.6"
$ARCH = $env:ARCH
if (-not $ARCH) { $ARCH = "x64" }

$BUILD_DIR = "build/windows-$ARCH"
$SRC_DIR = "sqlcipher-src"

Write-Host "Building SQLCipher $SQLCIPHER_VERSION for Windows $ARCH"

# Download SQLCipher source
if (-not (Test-Path $SRC_DIR)) {
    Write-Host "Downloading SQLCipher source..."
    $url = "https://github.com/sqlcipher/sqlcipher/archive/v$SQLCIPHER_VERSION.tar.gz"
    Invoke-WebRequest -Uri $url -OutFile "sqlcipher.tar.gz"
    tar -xzf sqlcipher.tar.gz
    Move-Item "sqlcipher-$SQLCIPHER_VERSION" $SRC_DIR
    Remove-Item "sqlcipher.tar.gz"
}

# Create build directory
New-Item -ItemType Directory -Force -Path "$BUILD_DIR/lib" | Out-Null
New-Item -ItemType Directory -Force -Path "$BUILD_DIR/include" | Out-Null

# Build using MSVC
Push-Location $SRC_DIR

$OPENSSL_ROOT = "C:\Program Files\OpenSSL-Win64"
if ($ARCH -eq "x86") {
    $OPENSSL_ROOT = "C:\Program Files (x86)\OpenSSL-Win32"
}

$CFLAGS = "/DSQLITE_HAS_CODEC /DSQLCIPHER_CRYPTO_OPENSSL /I`"$OPENSSL_ROOT\include`""
$LDFLAGS = "/LIBPATH:`"$OPENSSL_ROOT\lib`" libcrypto.lib"

# Compile SQLCipher
cl. exe /c sqlite3.c $CFLAGS
lib.exe /OUT:. .\$BUILD_DIR\lib\sqlcipher.lib sqlite3.obj

# Copy headers
Copy-Item "sqlite3.h" ". .\$BUILD_DIR\include\"

Pop-Location

Write-Host "Build completed successfully!"
Write-Host "Output: $BUILD_DIR"