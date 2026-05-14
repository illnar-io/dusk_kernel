#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/module"
OUTPUT="../dusk-companion-v2.1.zip"
rm -f "$OUTPUT"
zip -r9 "$OUTPUT" . -x '*.git*'
echo "✅ Companion module built: $(ls -lh "$OUTPUT" | awk '{print $5}')"
echo "   $(realpath "$OUTPUT")"
