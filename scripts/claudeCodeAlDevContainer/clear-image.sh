#!/bin/bash
sed -i 's/\r$//' "$0"

docker rmi claude-code-sandbox
echo ""
echo "--- Done (exit $?). Press any key to close ---"
read -n 1
