# Macros

## @Resolvable

`@Resolvable<ResolverType>` can be applied to any init or static function. It will generate a new static function which takes the resolver as a parameter and resolves all the original parameters and then passes the resolved dependencies into the original function.
The generated code will use the Knit generated resolvers so it gets the same compile time safety as if the code was written manually.

Parameters which resolve named registrations can use the `@Named("name")` property wrapper.
Parameters which should be used as arguments instead can use the `@Argument` property wrapper. They will be added as parameters to the generated function.

Examples of the macro output can be seen in the tests [ResolvableTests.swift](../Tests/KnitMacrosTests/ResolvableTests.swift)