# Knit

A tool for adding safety features to Swinject.
Knit parses Swinject code and generates Swift files for type safety and unit testing.

## `@knit` Comment Commands

Knit is designed to consume the Swinject syntax in your Assembly file. However there are some important aspects of
a registration that are not represented in the Swinject syntax. `@knit` comment commands allow you to configure
your registrations with that additional information.

This is accomplished by adding a comment directly above the registration starting with `// @knit` and then
followed with the configuration command.

### Registration Visibility

Knit can change the visibility of the generated type-safe accessors.
The following commands are available:

* `public`: Make the type safe function public (default is internal)
* `hidden`: Do not generate any type safe function

#### Examples:

Make the generated type-safe accessor `public`:
```
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
* `getter-named`: Generate a named accessor function.
* `getter-callAsFunction`: Generate `callAsFunction` accessor.
* Both commands can be included to specify that both accessors should be generated. `// @knit getter-named getter-callAsFunction`

#### Default Setting

By default Knit generates named getters for its type safety. 

---

## Release Guide

Located in the [Release.md](Release.md) file.
