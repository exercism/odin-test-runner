#!/bin/sh

# Odin links the test executable by calling `clang`, or the command named in
# ODIN_CLANG_PATH. This script links with gcc instead. Both drivers call the
# same system linker (ld) with the same C runtime files, but clang loads about
# 190 MB of LLVM libraries just to start. Reading those from disk took about
# 0.75 s whenever they were not in the page cache.
#
# gcc accepts every flag Odin passes when linking these tests, apart from
# clang's -Wno-unused-command-line-argument, which is removed here.

for arg; do
    shift
    [ "$arg" = "-Wno-unused-command-line-argument" ] || set -- "$@" "$arg"
done

exec gcc "$@"
