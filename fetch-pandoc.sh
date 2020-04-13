#!/bin/bash -eux
echo 'test'
PANDOC_VERSION=$1
# DEST=${2}-pandoc.deb
echo $PANDOC_VERSION
#URL=https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-1-amd64.deb
#exec wget --continue --output-document ${DEST} ${URL}