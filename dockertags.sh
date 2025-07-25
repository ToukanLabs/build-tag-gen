#!/bin/bash

if [ $# -lt 1 ]; then
    cat <<HELP

dockertags  --  list all tags for a Docker image on a remote registry.

OPTIONS:
    -u | -user ) <string> - Set the username for docker hub private repos
    -p | -pass ) <string> - Set the password for docker hub private repos
    -g | -grep ) <string> - return only results containing <string>
    -s | -semver) <major.minor.patch> - Only return tags matching a given sematic version.
                    Note that * can be used as a wild-card for any part. 
                    E.g., 4.3.* would return all patch versions of the 4.3 tag
    -av | --allow-v ) - When used with -s will allow semver tags to start with a preceding 'v'
                    E.g., would match both 4.3.2 and v4.3.2
    -prefix <string> - When used with -semver will include the given prefix in the search before the version
    -suffix <string> - When used with -semver will include the given suffix in the search after the version

EXAMPLE: 
    - list all tags for ubuntu:
       dockertags ubuntu

    - list all php tags containing apache:
       dockertags php -g apache

    - list all the version 3 alpine minor images that have a patch 1
       dockertags alpine -s 3.*.1
    
    - list all tags from a private repository
       dockertagas myprivate/image -u myuser -p mypassword

HELP
fi

# setup variables
user=''
pass=''
major=''
minor=''
patch=''
allowv=''
prefix=''
suffix=''

PARAMS=()
while [[ $# -gt 0 ]]; do
    p="$1"

    case $p in
    -user | --user | -u) # Set docker username
        user=$2
        shift
        ;;
    -pass | --pass | -p) # Set docker passowrd
        pass=$2
        shift
        ;;
    -grep | --grep | -g) # grep the result with a given string
        grepstring=$2
        shift
        ;;
    -semver | --semver | -s) # Specify a semantic version (1.2.3) to search for, can use * as wildcard
        IFS='.' read -ra SEMVER <<<"${2#v}"
        major="${SEMVER[0]//\*/$'[0-9]+'}" # if '*' is specificed, then replace with [0-9]+
        minor="${SEMVER[1]//\*/$'[0-9]+'}"
        patch="${SEMVER[2]//\*/$'[0-9]+'}"
        shift
        ;;
    --allow-v | -av) # allow a preceding v in semantic versions (when used with -semver)
        allowv=true
        ;;
    -prefix) # include given prefix in front of the semver search
        prefix="$2"
        shift
        ;;
    -suffix) # include given suffix in at the end of of the semver search
        suffix="$2"
        shift
        ;;
    *) # add everything else to the params array for processing in the next section
        PARAMS+=("$1")
        ;;
    esac
    shift
done
set -- "${PARAMS[@]}" # restore positional parameters

image="$1"

# If a semver has been specified, then search it with awk
if [ -n "$major" ]; then
    comparestring='$3 ~ /^'"${prefix}${allowv:+$'v?'}${major}"'\.'"${minor}"'\.'"${patch}${suffix}"'$/ {print $3}'
    echo $comparestring
else # just return all tags
    comparestring='{print $3}'
fi

# # output debug info
# echo "::group::DEBUG: dockertag Parameters"
# echo "DEBUG: User: $user"
# echo "DEBUG: Image: $image"
# echo "DEBUG: Major: $major"
# echo "DEBUG: Minor: $minor"
# echo "DEBUG: Patch: $patch"
# echo "DEBUG: Prefix: $prefix"
# echo "DEBUG: Suffix: $suffix"
# echo "DEBUG: Grep string: $grepstring"
# echo "::endgroup::"

# if user is specified, then use it to get the tags
TOKEN=''
if [ -n "$user" ]; then
    TOKEN=$(curl -s -u $user:$pass \
    "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$image:pull" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
fi

api_url="https://registry-1.docker.io/v2/$image/tags/list"

if [ -n "$TOKEN" ]; then
    response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN" "$api_url")
else
    response=$(curl -s -w "\n%{http_code}" "$api_url")
fi

curl_output=$(echo "$response" | sed '$d')
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" -ne 200 ]; then
    echo "ERROR: Docker Registry API returned HTTP $http_code"
    echo "$curl_output"
    exit 1
fi

# DEBUG information
# echo "DEBUG: API URL: $api_url"
# echo "DEBUG: Response: $curl_output"

# output the tags
mapfile -t tags < <(echo "$curl_output" | grep -o '"tags":[^]]*' | sed 's/"tags":\[//' | tr -d '"' | tr ',' '\n' | sed '/^\s*$/d')

if [ -n "$grepstring" ]; then
    mapfile -t tags < <(printf "%s\n" "${tags[@]}" | grep "$grepstring")
fi

# echo "DEBUG: Tags found: ${#tags[@]}"
# echo "***********"

# remove any tags that do not contain "10"
tags=($(printf "%s\n" "${tags[@]}" | grep "10"))
#remove any tags containing v9
tags=($(printf "%s\n" "${tags[@]}" | grep -v "v9"))

printf "%s\n" "${tags[@]}"