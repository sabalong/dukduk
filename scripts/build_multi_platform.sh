#!/usr/bin/env bash
set -euo pipefail

# Multi-platform build script for fincent-api
# Builds for Linux amd64 and macOS arm64
# Usage: ./scripts/build_multi_platform.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
OS_NAME=$(uname -s)

echo "Building fincent-api for multiple platforms..."
echo "Root directory: ${ROOT_DIR}"
echo "Artifacts will be output to: ${ARTIFACTS_DIR}"

mkdir -p "${ARTIFACTS_DIR}"

build_linux_amd64() {
  echo ""
  echo "=== Building for Linux amd64 ==="
  
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker not installed. Required for Linux builds." >&2
    return 1
  fi

  docker build \
    --target appbuilder \
    --build-arg TARGETARCH=amd64 \
    -t fincent-api-builder:linux-amd64 \
    "${ROOT_DIR}"

  echo "Extracting binary from Docker image..."
  docker create --name extract-linux fincent-api-builder:linux-amd64
  docker cp extract-linux:/app/duckdb-tester/main "${ARTIFACTS_DIR}/fincent-api-linux-amd64" || true
  docker rm extract-linux

  if [ -f "${ARTIFACTS_DIR}/fincent-api-linux-amd64" ]; then
    chmod +x "${ARTIFACTS_DIR}/fincent-api-linux-amd64"
    echo "✓ Linux amd64 binary: ${ARTIFACTS_DIR}/fincent-api-linux-amd64"
  else
    echo "Error: Failed to extract Linux binary from Docker" >&2
    return 1
  fi
}

build_macos_arm64() {
  echo ""
  echo "=== Building for macOS arm64 ==="
  
  if [ "$OS_NAME" != "Darwin" ]; then
    echo "Warning: Not running on macOS. Skipping native macOS build." >&2
    echo "To build for macOS arm64, run this script on a macOS machine with Apple Silicon." >&2
    return 0
  fi

  # Check dependencies
  for cmd in cmake git python3 go make cc c++; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Error: $cmd not installed. Install Xcode Command Line Tools and required packages." >&2
      echo "Run: xcode-select --install" >&2
      echo "Then: brew install cmake git python3 go" >&2
      return 1
    fi
  done

  # Build DuckDB libraries
  echo "Building DuckDB native libraries..."
  export CMAKE_POLICY_VERSION_MINIMUM=3.5
  
  BUILD_DIR="${ROOT_DIR}/.build"
  DUCKDB_DIR="${BUILD_DIR}/duckdb"
  VCPKG_DIR="${BUILD_DIR}/vcpkg"
  DUCKDB_VERSION="v1.3.2"

  mkdir -p "${BUILD_DIR}"

  if [[ ! -d "${DUCKDB_DIR}/.git" ]]; then
    git clone --depth 1 --branch "${DUCKDB_VERSION}" https://github.com/duckdb/duckdb.git "${DUCKDB_DIR}"
  fi

  if [[ ! -d "${VCPKG_DIR}/.git" ]]; then
    git clone https://github.com/Microsoft/vcpkg.git "${VCPKG_DIR}"
  else
    if [[ "$(git -C "${VCPKG_DIR}" rev-parse --is-shallow-repository 2>/dev/null || echo false)" == "true" ]]; then
      echo "Detected shallow vcpkg clone, fetching full history..."
      git -C "${VCPKG_DIR}" fetch --unshallow || git -C "${VCPKG_DIR}" fetch --all --tags --prune
    else
      git -C "${VCPKG_DIR}" fetch --all --tags --prune
    fi
  fi

  "${VCPKG_DIR}/bootstrap-vcpkg.sh"

  export VCPKG_ROOT="${VCPKG_DIR}"
  cp "${ROOT_DIR}/extension_config_local.cmake" "${DUCKDB_DIR}/extension/extension_config_local.cmake"

  pushd "${DUCKDB_DIR}" >/dev/null
  CMAKE_POLICY_VERSION_MINIMUM=3.5 make extension_configuration
  CMAKE_POLICY_VERSION_MINIMUM=3.5 \
  USE_MERGED_VCPKG_MANIFEST=1 \
  VCPKG_TOOLCHAIN_PATH=../vcpkg/scripts/buildsystems/vcpkg.cmake \
  EXTENSION_STATIC_BUILD=1 \
  make -j"$(sysctl -n hw.logicalcpu)" bundle-library
  popd >/dev/null

  # Prepare duckdblib for app build
  TMP_DUCKDBLIB="${ROOT_DIR}/appgo/.duckdblib_build"
  mkdir -p "${TMP_DUCKDBLIB}"
  find "${DUCKDB_DIR}/build/release" -type f -name "*.a" -exec cp {} "${TMP_DUCKDBLIB}/" \;
  if [ -d "${DUCKDB_DIR}/build/release/extension" ]; then
    cp -R "${DUCKDB_DIR}/build/release/extension" "${TMP_DUCKDBLIB}/"
  fi

  # Build Go application
  echo "Building Go application..."
  pushd "${ROOT_DIR}/appgo" >/dev/null
  CGO_ENABLED=1 \
  CPPFLAGS="-DDUCKDB_STATIC_BUILD" \
  CGO_LDFLAGS="-L./.duckdblib_build -lduckdb_bundle -lminizip-ng -lstdc++ -lm -ldl -lexpat -lz -larrow -lcompression" \
  go build -tags=duckdb_use_static_lib -o "${ARTIFACTS_DIR}/fincent-api-macos-arm64" ./duckdb-tester/main.go
  popd >/dev/null

  chmod +x "${ARTIFACTS_DIR}/fincent-api-macos-arm64"
  echo "✓ macOS arm64 binary: ${ARTIFACTS_DIR}/fincent-api-macos-arm64"

  # Cleanup
  rm -rf "${TMP_DUCKDBLIB}"
}

# Main execution
if [ "$OS_NAME" = "Darwin" ]; then
  echo "Detected macOS runner. Building for macOS."
  build_macos_arm64
else
  echo "Detected Linux runner. Building for Linux."
  build_linux_amd64
fi

echo ""
echo "=== Build Summary ==="
echo "Artifacts directory: ${ARTIFACTS_DIR}"
ls -lh "${ARTIFACTS_DIR}" || echo "No artifacts found."
