# Knit Comment Commmands

Knit is designed to consume the Swinject syntax in your Assembly file. However there are some important aspects of
a registration that are not represented in the Swinject syntax. `@knit` comment commands allow you to configure
your registrations with that additional information.

This is accomplished by adding a comment directly above the registration starting with `// @knit` and then
followed with the configuration command.

Commands can be applied at either the Assembly level or the registration level. Options set at the registration level will override any from the Assembly.

### Registration Visibility

Knit can change the visibility of the generated type-safe accessors.
The following commands are available:

* `public`: Make the type safe function(s) public (default is internal). Defines the public API exposed from the DI graph for an assembly.
* `internal`: Make the type safe function(s) internal. This is a useful override when the assembly is set to `public`.
* `hidden`: Do not generate any type safe function. This is useful when for implementations where the public API is already defined.
* `ignore`: Completely ignore this assembly or registration. Primarily for cases that are not supported by the Knit parser.

#### Example:

Make the generated type-safe accessor `public`:
``` swift
// @knit public
container.register(MyType.self, factory: { /*...*/ })
```

#### Getter Named

* `getter-named("myCustomName")`: Generate a named accessor function with a custom name where the default name is not appropriate. Provide the custom name as an argument to the command.

### SPI

If a registration is using a type that is protected by a swift System Programming Interface (SPI) then the generated resolver can be generated with the same SPI protection `// @knit @_spi(Testing)`.

### ModuleName

Knit makes some assumptions during code generation about the name of the module which can be controlled via the `--module-name-regex` flag provided to the gen command. Alternatively `// @knit module-name("MyModule")` can be used to override the default.

### DisablePerformanceGen

`// @knit disable-performance-gen` disables the generation of the `_assemblyFlags` and `_autoInstantiate` functions which are important for large projects to cut down on the number of `as` and `is` calls.
