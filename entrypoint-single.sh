#!/bin/bash
set -e

# Source the configuration setup script from the same directory
. "$(dirname "$0")/setup-config.sh"

# Start Trino
exec /usr/lib/trino/bin/run-trino