#!/bin/bash
slug=""
prefix=""
suffix=""

PARAMS=()
while [[ $# -gt 0 ]]; do
    p="$1"

    case $p in
    -suffix) # Set suffix - ignore if .
        [ "$2" != "." ] && suffix=$2 || :
        shift
        ;;
    -prefix) # Set prefix - ignore if .
        [ "$2" != "." ] && prefix=$2 || :
        shift
        ;;
    *) # add everything else to the params array for processing in the next section
        slug=$1
        ;;
    esac
    shift
done

# Throw error if no slug was supplied
if [ -z "$slug" ]; then
    echo >&2 "No slug was supplied"
    exit 1
fi

tags=''

[ -n "$prefix" ] && prefix="$prefix-" || :
[ -n "$suffix" ] && suffix="-$suffix" || :

# Is the slug matches a semver pattern, then create major/minor version
if grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' <<<"$slug" >/dev/null 2>&1; then
    # It has the correct syntax.
    n=${slug//[!0-9]/ }
    a=(${n//\./ })
    major=${a[0]}
    minor=${a[1]}
    patch=${a[2]}
    tags+="${prefix}v${major}${suffix}\n"
    tags+="${prefix}v${major}.${minor}${suffix}\n"
    tags+="${prefix}v${major}.${minor}.${patch}${suffix}\n"
else
    # main tag
    tags+="${prefix}${slug}${suffix}\n"
fi

# Set "latest" tag for master branch
if [ "$slug" == "master" ] || [ "$slug" == "main" ]; then
    tags+="${prefix}latest${suffix}\n"
fi

# Set "edge" tag for develop branch
if [ "$slug" == "develop" ]; then
    tags+="${prefix}edge${suffix}\n"
fi

# output result
echo -e "$tags"
