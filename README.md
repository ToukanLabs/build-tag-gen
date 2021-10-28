# build-tag-gen
Generates build tags to use with docker builds, based on the github branch/tag name.

The input branch/tag name should be in slug format (i.e. / converted to undescore, etc)

It is recommended to use rlespinasse/github-slug-action@v3.x action to generate the GITHUB_REF_SLUG env variable.

If the supplied tag is in semver format (e.g., 1.2.3), then tags for the major and minor versions will also be produced.

E.g, if the given input slug was: 5.1.0, then the output would be:

- v5
- v5.1
- v5.1.0

(note that including v at the start of the slug is optional)

When the input slug/branch is master or main, a "latest" tag will also be added

When the inlut slug/branch is develop, and "edge" tag will be added

If a prefix or suffix are given, these will be added to all tags, separated by '-'. i.e., \<prefix>-\<tag>-\<suffix>
