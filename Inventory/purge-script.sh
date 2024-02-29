#!/bin/bash
CACHE_PATH="/var/cache/nginx"

if [ -z "$1" ]; then
    echo "Usage: $0 filename"
    exit 1
fi

find $CACHE_PATH -name "$1" -exec rm -f {} \;

echo "File $1 has been purged from cache."
