# Knit

A tool for adding safety features to Swinject.
Knit parses Swinject code and generates Swift files for type safety and unit testing.

## Registration modifiers

For any registration in an assembly it is possible to give knit additional information about how to generate the type safe functions. <br/>
This is accomplished by adding a comment directly above the registration starting with `// @knit`.

The following modifiers are available:

* `public` -> Make the type safe function public (default is internal)
* `hidden` -> Do not generate any type safe function
* `named-getter` -> Generate a named function in addition to `callAsFunction`.

---

[Release guide](Release.md)