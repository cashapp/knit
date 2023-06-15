# Release

Instructions to create a new release of Knit.

## Prerequisite steps:

1. Open and merge a pull request to change the version number in the `Knit.podspec`

## Create the release from the merge commit of the above PR:

1. Run `swift -v` and check that your toolchain is `v5.8.1`
   - If not make sure your current toolchain is selected as Xcode `14.3.1`
1. Run `swift build -c release --arch arm64 --arch x86_64` from the root of the Knit repo
1. Change directory: `cd ./.build/apple/Products/Release`
1. Rename the executable binary: `mv knit-cli knit`
1. Compress into a zip: `zip knit.zip knit`
1. Go to https://github.com/squareup/knit/releases/new
1. Create the new release version and include the zip file as a binary attachment.
   - GitHub will automatically create the tag for you.
