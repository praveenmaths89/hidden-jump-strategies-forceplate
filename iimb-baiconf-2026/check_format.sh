#!/bin/sh
# Run the IIMB format checker on the Overleaf project (see overleaf/check_format.py)
cd "$(dirname "$0")/overleaf" && exec python3 check_format.py "$@"
