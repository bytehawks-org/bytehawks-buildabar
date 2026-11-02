#!/bin/bash
# builda-bar-entrypoint: keeps what the image always did (`docker run image` and `docker run image -c '...'` give bash) and lets a command be
# given directly (`docker run image builda-bar-selftest`, `docker run image python script.py`, `docker run image sh -c '...'`).
#
#   no argument, or an option (-c, -l ...)   ->  bash "$@"
#   the first argument is a command on PATH  ->  that command
#   anything else (a script file)            ->  bash "$@"
if [ "$#" -eq 0 ]; then
    exec /bin/bash
fi
case "$1" in
    -*) exec /bin/bash "$@" ;;
esac
if [ ! -d "$1" ] && command -v "$1" >/dev/null 2>&1; then
    exec "$@"
fi
exec /bin/bash "$@"
