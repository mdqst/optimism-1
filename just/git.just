import 'default.just'

# Set default values for git info
GITCOMMIT := env('GITCOMMIT', `git rev-parse HEAD 2> /dev/null || true`)
GITDATE := env('GITDATE', `git show -s --format='%ct' 2> /dev/null|| true`)

PROJECT := shell("basename $1", justfile_directory())

ALL_TAGS := shell("git tag --points-at $1 2> /dev/null || true", GITCOMMIT)
PROJECT_TAGS := shell("echo $1 | grep ^$2/ | sed s:$2/:: | sort -V", ALL_TAGS, PROJECT)
PREFERRED_TAG := shell("echo $1 | grep -v -- '-rc' | tail -n 1", PROJECT_TAGS)
LAST_TAG := shell("echo $1 | tail -n 1", PROJECT_TAGS)

# Find version tag, prioritizing non-rc release tags
VERSION := shell('if [ -z "$1" ]; then
    if [ -z "$2" ]; then
        echo "untagged"
    else
        echo "$2"
    fi
else
    echo $1
fi', PREFERRED_TAG, LAST_TAG)