# Knit

A tool for adding safety features to Swinject.
Knit parses Swinject code and generates Swift files for type safety and unit testing.

## `@knit` Comment Commands

Knit is designed to consume the Swinject syntax in your Assembly file. However there are some important aspects of
a registration that are not represented in the Swinject syntax. `@knit` comment commands allow you to configure
your registrations with that additional information.

This is accomplished by adding a comment directly above the registration starting with `// @knit` and then
followed with the configuration command.

Commands can be applied at either the Assembly level or the registration level. Options set at the registration level will override any from the Assembly.

### Registration Visibility

Knit can change the visibility of the generated type-safe accessors.
The following commands are available:

* `public`: Make the type safe function(s) public (default is internal).
* `internal`: Make the type safe function(s) internal. This is a useful override when the assembly is set to `public`.
* `hidden`: Do not generate any type safe function.
* `ignore`: Completely ignore this assembly or registration

#### Examples:

Make the generated type-safe accessor `public`:
``` swift
// @knit public
container.register(MyType.self, factory: { /*...*/ })
```

### Type Safe Getters

One of the core capabilities of Knit is to generate type safe getters/accessors for your registrations.
There are some additional options to control and configure this behavior.

#### Call as Function Getter

This allows the call site to simply use `resolver()` and 
Swift will use type inference to match the appropriate registration.

#### Named Getter

In some situations it is helpful to have more control at the call site to specify the registration you would like to
resolve. 
For example, this can happen in unit test situations where there might be an alternate "testing" or "fake"
version of an existing protocol registration.
Named Getters allow you to write `resolver.myType()` or `resolver.myTypeFake()` to specifically resolve the 
registration for `MyType` or `MyTypeFake`.

In both situations the method call is type-safe.

#### Commands

The following commands are available:
* `getter-named`: Generate a named accessor function. Knit will provide an automatic name based from the type.
* `getter-named("myCustomName")`: Generate a named accessor function with a custom name. Provide the custom name as an argument to the command.
* `getter-callAsFunction`: Generate `callAsFunction` accessor.
* Both commands can be included to specify that both accessors should be generated. `// @knit getter-named getter-callAsFunction`

#### Default Setting

By default Knit generates named getters for its type safety.

## Duplicate Registration Detection

As an app scales, so do the number of DI registrations. It is important to detect duplicate registrations because by
default Swinject will overwrite early registrations with any duplicates.
While this capability is useful in test environments, at runtime it almost always indicates a programming/configuration
error, which could lead to bugs.

Knit includes two capabilities to detect duplicate registrations for additional DI graph safety:

1. Compile-time detection within a single module.
1. Runtime detection across an entire container's graph.

### Compile-time Detection

When Knit parses the assembly files within a single module it will automatically detect any duplicates
found during parsing and immediately report an error with information about the duplicate.
This is always on and automatic.

### Runtime Detection

Knit only parses the assemblies in a single module at a time so it is not able to detect duplicates across modules
during parsing/compile time. 
Instead Knit provides a `DuplicateRegistrationDetector` class, which is a Swinject Behavior.
`DuplicateRegistrationDetector` allows for runtime detection of all registrations made to a single Container (DI graph),
regardless of which modules those registrations came from. 
This adds safety from duplicate registrations to your whole DI graph.

An instance of DuplicateRegistrationDetector should be added to the Container to make use of this feature. Configuration steps:

1. Create an instance of `DuplicateRegistrationDetector`.
1. Provide that instance to your Container (ScopedModuleAssembler/ModuleAssembler/Assembler also allow behaviors to be
    passed into their initializers).
1. Perform the registration phase of your Container setup. If you are using ScopedModuleAssembler/ModuleAssembler then the registration phase will be complete after the initialer returns.
1. Check the `detectedKeys` property of your `DuplicateRegistrationDetector` instance for duplicates.

Note that there are also helpers on `DuplicateRegistrationDetector.Key` and `Array<DuplicateRegistrationDetector.Key>`
to help with creating reports/error messages that are easier to read.

`DuplicateRegistrationDetector` also provides a `duplicateWasDetected` closure hook if you would like to be informed of each
duplicate at the moment that duplicate is registered.

---

## Module Guide

Located in the [Docs/Modules.md](Docs/Modules.md) file.

## Release Guide

Located in the [Docs/Release.md](Docs/Release.md) file.

## Swinject Dependencies

Information about the copied dependencies is located in the [Docs/Swinject.md](Docs/Swinject.md) file.