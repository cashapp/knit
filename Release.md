# Release

Instructions to create a new release of Knit.

## Prerequisite steps

1. Open and merge a pull request to change the version number in the `Knit.podspec`

## Create the release from the merge commit of the above PR

1. Navigate to [Actions](https://github.com/squareup/knit/actions).
1. Trigger the `Release` workflow.
1. Enter the version number of the release you want to create, use the same version number as the PR you merged above.
1. Navigate to [Releases](https://github.com/squareup/knit/releases) for the release.
1. Upload the release `.zip` file to [Artifactory](https://artifactory.global.square/ui/repos/tree/General/squarepods) under the `squarepods` repository.
1. Publish the `.podpsec` to `ios-squarepod`

   ```sh
   # Check if the ios-squarepods repo is added to your CocoaPods install
   pod repo list

   # If it's not added:
   pod repo add squareup 'org-49461806@github.com:squareup/ios-squarepods.git'

   # Push the podspec to the repo
   # NOTE: Your repository name may be different, check the output of `pod repo list`
   pod repo push squareup-ios-squarepods Knit.podspec --allow-warnings
   ```
1. Update any `Podfile` with the new version
