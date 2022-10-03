#!/bin/sh
#
# Copyright SecureKey Technologies Inc. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

echo "Generating test key ..."
export RANDFILE=/tmp/rnd

if [ "${KEYS_OUTPUT_DIR}x" == "x" ]; then
    echo "KEYS_OUTPUT_DIR env not set"
    exit 1
fi

if [[ "$OSTYPE" == "win32" ]]; then
  echo "using local"
elif [[ "$OSTYPE" == "msys" ]]; then
  echo "using local"
else
  cd /opt/workspace
fi

mkdir -p ${KEYS_OUTPUT_DIR}

# create issuer store key
openssl rand -out ${KEYS_OUTPUT_DIR}/oidc-enc.key 32

echo "... Done generating test keys"
