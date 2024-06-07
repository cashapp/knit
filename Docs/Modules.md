# Module Assemblies

* Swinject provides the concept of an [Assembly](https://github.com/Swinject/Swinject/blob/master/Documentation/Assembler.md) which is responsible for registering a subset of the app services so that when all Assemblies are registered together via an Assembler all services are available.

`ModuleAssembly` extend the Assembly concept and define relationships between modules.
When services are assembled using `ModuleAssembler` it must be able to resolve the entire tree of modules as for each service we do not know which other services it may require. By enforcing that all child modules are also registered we can guarantee that all expected services have been registered.

## AutoInitModuleAssembly

The requirement for all modules to be initialised and available to the `ModuleAssembler` would be a large burden on developers if they had a large tree and needed to update it whenever the dependency tree changes. `AutoInitModuleAssembly` helps to solve this.
By default assemblies should conform to `AutoInitModuleAssembly`. This requires that the module assembly has an empty init. When the assembly conforms to `AutoInitModuleAssembly` then the `ModuleAssembler` will automatically initialise the child dependency if it has not been explicitly provided.
if the `ModuleAssembly` cannot be initialised without a parameter that is provided upstream, then this can be disabled. This should not be done for test assemblies as it makes more work for consuming tests.

## Overriding Implementations

For testing it may be required that an entire module should be swapped out. For example, a database module assembly may want to setup an in memory database while running tests.
For these cases `static var replaces` defines which modules the assembly overrides. It can then be used as a replacement for any `ModuleAssembly` that it declares it replaces. When an override is defined the original assembly will not be registered, the override will be substituted.
Overrides do not need to be in the same codebase as the original. The usual expectation is that the ModuleFakes would provide a separate version for testing if required.

## DefaultModuleAssemblyOverride

Using `replaces` provides the power to swap DI module implementations but requires explicit setup. A base assembly that implements `DefaultModuleAssemblyOverride` can automatically choose the override when default overrides are enabled in the `ModuleAssembler`. This defaults to true for unit testing and false for normal app runs.


