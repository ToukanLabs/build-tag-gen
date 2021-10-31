#!/bin/bash
slug=""
prefix=''
suffix=""
user=''
pass=''
image=''

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
    -u* | --user*)         # set docker user for private images (optional)
        user="-u ${1#*=} " #trailing space is important
        ;;
    -p* | --pass*)         # set docker password for private images (optional)
        pass="-p ${1#*=} " #trailing space is important
        ;;
    -i* | --image*)     # set docker image for semver testing (optional)
        image="${1#*=}" #trailing space is important
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
        tagscommand="./dockertags.sh "${image}" "${user}""${pass}"-s '*.*.*' -av"
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

        # if no newer patch version existsw, then add the minor tag
        if [ $newer_patch -eq 0 ]; then
            tags+=("${major}.${minor}")
        fi

        # if no newer minor version exists, then add a major tag
        if [ $newer_patch -eq 0 ] && [ $newer_minor -eq 0 ]; then
            tags+=("${major}")
        fi

        # if no newer major version exixts, then update the latest
        if [ $newer_patch -eq 0 ] && [ $newer_minor -eq 0 ] && [ $newer_major -eq 0 ]; then
            tags+=("latest")
        fi
    else
        # set all versions
        tags+=("${major}")
        tags+=("${major}.${minor}")

    fi
    # always set the patch version, regradless
    tags+=("${major}.${minor}.${patch}")
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

outputtags=()
# add image name, prefix and suffix to all tags (image adds a trailing ':'')
for tag in "${tags[@]}"; do
    outputtags+=("${image:+$image:}${prefix}${tag}${suffix}")
done

# output the new slug (which may have the leaving v stripped off)
echo "::set-output name=slug::${slug}"

# output result
actionoutput=$(printf '%s\n' "${outputtags[@]}")
# cleanup to allow GHA to process multi-line string as an output

actionoutput="${outputtags[*]//'%'/'%25'}"
actionoutput="${outputtags[*]//$'\n'/'%0A'}"
actionoutput="${outputtags[*]//$'\r'/'%0D'}"

echo "::set-output name=tags::$actionoutput"
