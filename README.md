build-tag-gen
-------------
-------------

- [Purpose](#purpose)
- [Inputs](#inputs)
- [Outputs](#outputs)
# Purpose
Generates build tags to use with docker builds, based on the github branch/tag name.

The input branch/tag name should be in `slug` format (i.e. / converted to undescore, etc)

It is recommended to use rlespinasse/github-slug-action@v3.x action to generate the `GITHUB_REF_SLUG` env variable.

If the supplied tag is in semver format (e.g., `1.2.3`), then tags for the major and minor versions will also be produced.

E.g, if the given input slug was: `5.1.0`, then the output would be:

- `5`
- `5.1`
- `5.1.0`

(note that any `v` at the start of the slug will be stripped)

When the input `slug`/branch is `master` or `main`, a `"stable"` tag will also be added

When the inlut `slug`/branch is `develop`, an `"edge"` tag will be added

If a `prefix` or `suffix` are given, these will be added to all tags, separated by '-'. i.e., `<prefix>-<tag>-<suffix>`

If an `image-name` is given, this will be prepended to the tag names in the format `<image-name>:<tag>`.

When an `image-name` is given **AND** the `slug` is a semver format, then existing tags will be parsed from docker hub, and major / minor tags will only be added if there is no newer respective major / minor version.

If there is no newer version aviable on docker hub, then the `latest` tag will be added (with relevant pre/suffixes)

# Inputs

| Name | description |
|------|-------------|
| `docker-pass` | The docker hub account password (needed if image is private) |
| `docker-user` | The docker hub user account (needed if image is private) |
| `image-name` | A docker image name. e.g, myrepo/myimage. If provided, the image name will be prepended to the start of each tag. Also any existing semantic version tags for the image will be used to determine if latest, x.x and x version tags should be added |
| `prefix` | An optional prefix to append before all tag names (e.g, debug) |
| `suffix` | An optional suffix to append after all tag names (e.g, a client-specific suffix) |
| `slug` | **Mandatory**.  This will be used as the root for the tag(s). Cannot contain any characters that are not allowed in docker image tags (e.g, `/` shoulf be converted to `_`  etc.) |

# Outputs
| Name | description |
|------|-------------|
| `tags` | a newline separated list of tags. This can be used as an input to the [`docker/build-push-action`](https://github.com/docker/build-push-action) action. |
| `slug` | An adjusted slug with any leading `v` stripped from the front (for semantic version formatted tags only). This may be useful when referring to the image tag in later actions | 
