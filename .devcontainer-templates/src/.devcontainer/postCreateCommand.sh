#!/bin/bash

set -euo pipefail  # Exit on error, undefined vars, and pipeline failures
IFS=$'\n\t'       # Stricter word splitting
echo "--- pre firewall"
sudo "/usr/local/bin/init-firewall.sh"
echo "--- past firewall"
