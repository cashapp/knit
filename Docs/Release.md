# Release

Instructions to create a new release of Knit.

## Prerequisite steps

1. Open and merge a pull request to change the version number in the `Knit.podspec`

## Create the release from the merge commit of the above PR

1. Navigate to [Actions](https://github.com/squareup/knit/actions).
1. Trigger the `Release` workflow.
1. Enter the version number of the release you want to create, use the same version number as the PR you merged above.
1. Navigate to [Releases](https://github.com/squareup/knit/releases) for the release.