#!/bin/sh
#
# Copyright SecureKey Technologies Inc. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

echo "Generating GNAP signing keys ..."
export RANDFILE=/tmp/rnd

if [ "${KEYS_OUTPUT_DIR}x" == "x" ]; then
    echo "KEYS_OUTPUT_DIR env not set"
    exit 1
fi

if [[ "$OSTYPE" == "win32" ]]; then
  echo "using local"
else
  cd /opt/workspace
fi

mkdir -p ${KEYS_OUTPUT_DIR}

# create private key for GNAP signer for EDV
openssl ecparam -name prime256v1 -genkey -noout -out ${KEYS_OUTPUT_DIR}/edv-gnap-key.pem

echo "... Done generating GNAP signing keys ${KEYS_OUTPUT_DIR}"
