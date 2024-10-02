# Knit CLI

The Knit CLI is responsible for parsing Assembly files and producing type safety and unit test source files.
The `knit-cli` executable is the primary interface for this parsing and file generation.
An Xcode Build Plugin is also provided to integrate with Xcode projects that use SPM Package Dependencies.

## Releases

Each Github release has a zip file that includes a precompiled executable of the Knit CLI,
along with source files.

## Xcode Build Plugin

For projects that do not have complex or custom build configurations, you can use the vended build plugin.
If your project has a complex build system or custom needs, please use the `knit-cli` executable.

1. Add the Package Dependency for Knit to your Xcode project
1. Add the vended plugin to both the main application target and unit test target (if it exists). 
1. Create a `knitconfig.json` file and add it to the Xcode project (it does not need to be added to any targets).
