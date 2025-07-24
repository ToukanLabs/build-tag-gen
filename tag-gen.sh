#!/bin/bash
allow_latest=1
arch=''
image=''
is_primary=0
outputtags=()
pass=''
prefix=''
slug=""
suffix=""
user=''

PARAMS=()
while [[ $# -gt 0 ]]; do
    p="$1"

    case $p in
    -suffix*) # Set suffix - ignore if .
        suffix=${1#*=}
        #remove any leading - (this will be added back later)
        suffix=${suffix#-}
        ;;
    -prefix*)
        prefix=${1#*=}
        #remove any trailing - (this will be added back later)
        prefix=${prefix%-}
        ;;
    --allow-latest-tag*)
        #do not add the latest tag, even if this is the newest version
        if [ "${1#*=}" == "false" ] || [ "${1#*=}" == "0" ]; then
            allow_latest=0
        else
            allow_latest=1
        fi
        ;;
    --is-primary*)
        # if true, will add the default latest even when used with prefix or suffix, when the semver slug is the latest version
        if [ "${1#*=}" == "true" ] || [ "${1#*=}" == "1" ]; then
            is_primary=1
        else
            is_primary=0
        fi
        ;;
    -u* | --user*)         # set docker user for private images (optional)
        user="-u ${1#*=} " #trailing space is important
        ;;
    -p* | --pass*)         # set docker password for private images (optional)
        pass="-p ${1#*=} " #trailing space is important
        ;;
    -i* | --image*)     # set docker image for semver testing (optional)
        image="${1#*=}" #trailing space is important
        ;;
    -arch*) # set the architecture for the image (optional)
        arch="${1#*=}"
        ;;
    *) # add everything else to the params array for processing in the next section
        PARAMS+=("$1")
        ;;
    esac
    shift
done
set -- "${PARAMS[@]}" # restore positional parameters

slug=$1

# Throw error if no slug was supplied
if [ -z "$slug" ]; then
    echo >&2 "No slug was supplied"
    exit 1
fi

tags=()

[ -n "$prefix" ] && prefix="$prefix-" || :
[ -n "$suffix" ] && suffix="-$suffix" || :
[ -n "$arch" ] && arch="-$arch" || :

# Is the slug matches a semver pattern, then create major/minor version
if grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' <<<"$slug" >/dev/null 2>&1; then
    #strip any leading v
    slug=${slug#v}

    # split to array
    n=${slug//[!0-9]/ }
    a=(${n//\./ })
    major=${a[0]}
    minor=${a[1]}
    patch=${a[2]}

    if [ -n "$image" ]; then
        tagscommand="./dockertags.sh \"${image}\" \"${user}\"\"${pass}\"-s '*.*.*' -av"
        [ -n "$prefix" ] && tagscommand+=" -prefix ${prefix}" || :
        [ -n "$suffix" ] && tagscommand+=" -suffix ${suffix}" || :
        
        readarray -t major_matches <<<"$(eval $tagscommand)"
        newer_major=0
        newer_minor=0
        newer_patch=0
        for i in "${major_matches[@]}"; do
            if [ -z "$i" ]; then
                continue
            fi # skip if line is blank

            # strip any leading v
            i=${i#v}
            # split i to array
            unset x
            unset b
            unset bmajor
            unset bminor
            unset bpatch
            x=${i//[!0-9]/ }
            b=(${x//\./ })
            bmajor=${b[0]}
            bminor=${b[1]}
            bpatch=${b[2]}

            # Test to see if there are any newer versions
            if [[ $bmajor -eq $major ]] && [[ $bminor -ge $minor ]] && [[ $bpatch -gt $patch ]]; then
                newer_patch=1
            fi

            if [[ $bmajor -eq $major ]] && [[ $bminor -gt $minor ]]; then
                newer_minor=1
            fi

            if [[ $bmajor -gt $major ]]; then
                newer_major=1
            fi

        done

        # if no newer patch version exists, then add the minor tag
        if [ $newer_patch -eq 0 ]; then
            tags+=("${major}.${minor}")
        fi

        # if no newer minor version exists, then add a major tag
        if [ $newer_patch -eq 0 ] && [ $newer_minor -eq 0 ]; then
            tags+=("${major}")
        fi

        # if no newer major version exists, then update the latest
        if [ $allow_latest -eq 1 ] && [ $newer_patch -eq 0 ] && [ $newer_minor -eq 0 ] && [ $newer_major -eq 0 ]; then
            tags+=("latest")
        fi
    else
        # set all versions
        tags+=("${major}")
        tags+=("${major}.${minor}")

    fi
    # always set the patch version, regardless
    tags+=("${major}.${minor}.${patch}")

    # if is_primary is true/1, and there is either a prefix or suffix, then also add the tags to the output immediately without prefix or suffix (the pre/suffix tags are added later)
    has_prefix_or_suffix=0
    if [ -n "$prefix" ] || [ -n "$suffix" ]; then
        has_prefix_or_suffix=1
    fi
    if { [ "$is_primary" = "1" ] || [ "$is_primary" = "true" ]; } && [ $has_prefix_or_suffix -eq 1 ]; then
        for tag in "${tags[@]}"; do
            outputtags+=("${image:+$image:}${tag}${arch}")
        done
    fi
else
    # If this wasn't a semver tag, then set the tag using the slug
    tags+=("${slug}")

    # Add "stable" tag for master branch
    if [ "$slug" == "master" ] || [ "$slug" == "main" ]; then
        tags+=("stable")
    fi

    # Add "edge" tag for develop branch
    if [ "$slug" == "develop" ]; then
        tags+=("edge")
    fi
fi

IFS=$'\n' tags=($(sort -V <<<"${tags[*]}"))
unset IFS

# add image name, prefix and suffix to all tags (image adds a trailing ':'')
for tag in "${tags[@]}"; do
    outputtags+=("${image:+$image:}${prefix}${tag}${suffix}${arch}")
done

# output the new slug (which may have the leading v stripped off)
echo "::group::New Slug"
echo "${slug}"
echo "slug=${slug}" >> "$GITHUB_OUTPUT"
echo "::endgroup::"

# output result
echo "::group::Tags"
actionoutput=$(printf '%s\n' "${outputtags[@]}")
echo "${actionoutput}"

# Write tags output with real newlines
{
  echo "tags<<EOF"
  echo "${actionoutput}"
  echo "EOF"
} >> "$GITHUB_OUTPUT"

echo "::endgroup::"
