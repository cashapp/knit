# Macros

## @Resolvable

`@Resolvable<ResolverType>` can be applied to any init or static function. It will generate a new static function which takes the resolver as a parameter and resolves all the original parameters and then passes the resolved dependencies into the original function.
The generated code will use the Knit generated resolvers so it gets the same compile time safety as if the code was written manually.

Examples of the macro output can be seen in the tests [ResolvableTests.swift](../Tests/KnitMacrosTests/ResolvableTests.swift)

### Property Wrappers

* `@Named("name")` - The parameter will be resolved from the DI graph using the given name.
* `@Argument` - The parameter will not be resolved from the DI graph. An additional parameter will be added to the generated function.
* `@UseDefault` - The parameter will not be resolved from the DI graph and will use the deafault value provided instead.

### Optional parameters

The `@Resolvable` macro uses the same naming system to access the knit generated fuctions. In that naming system optionals are not included in the name so an optional parameter will correctly access the non optional value from the DI graph while allowing an optional value for testing. It is also possible to register an optional type in the DI graph which will also work in this situation. 
