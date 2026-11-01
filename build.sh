#!/usr/bin/env bash
# Builds the mod-portal zip at dist/<name>_<version>.zip from the last commit.
#
# Packing from the last commit (git archive) means stray local files can never
# end up in a release. Repo-only files are excluded via `export-ignore` in
# .gitattributes.
set -euo pipefail
cd "$(dirname "$0")"

read_info() { python3 -c "import json; print(json.load(open('info.json'))['$1'])"; }
name=$(read_info name)
version=$(read_info version)

changelog_version=$(sed -n 's/^Version: //p' changelog.txt | head -n 1)
if [ "$changelog_version" != "$version" ]; then
    echo "Error: info.json is version $version but the newest changelog entry is $changelog_version." >&2
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "Warning: you have uncommitted changes. They are NOT in the zip; it is built from the last commit." >&2
fi

mkdir -p dist
out="dist/${name}_${version}.zip"
git archive --format=zip --prefix="${name}_${version}/" -o "$out" HEAD
echo "Built $out"
