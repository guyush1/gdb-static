#!/usr/bin/env bash

set -e

# Download and install a specific autoconf version.

# Example: "2.10"
AUTOCONF_VERSION="${1}"
if [[ -z "${AUTOCONF_VERSION}" ]]; then
    echo "No autoconf version supplied"
    exit 1
fi

AUTOCONF_URL_BASE="https://ftp.gnu.org/gnu/autoconf/"
AUTOCONF_BASENAME="autoconf-${AUTOCONF_VERSION}.tar.gz"
AUTOCONF_URL="${AUTOCONF_URL_BASE}${AUTOCONF_BASENAME}"

autoconf_dir="$(mktemp -d)"
pushd "${autoconf_dir}"
echo "Using directory: ${autoconf_dir}"

echo "Downloading: ${AUTOCONF_URL}"
wget -O - "${AUTOCONF_URL}" | tar -xzf -

pushd "autoconf-${AUTOCONF_VERSION}"

./configure

make install

popd &> /dev/null

popd &> /dev/null