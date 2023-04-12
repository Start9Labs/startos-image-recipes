#!/bin/sh

cat > /etc/wgetrc << EOF
retry_connrefused = on
tries = 100
EOF