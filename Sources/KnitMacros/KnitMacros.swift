//
// Copyright © Block, Inc. All rights reserved.
//

@attached(peer, names: named(make))
public macro Resolvable<ResolverType>() = #externalMacro(module: "KnitMacrosImplementations", type: "ResolvableMacro")

@attached(extension, names: named(make))
public macro ResolvableStruct<ResolverType>() = #externalMacro(module: "KnitMacrosImplementations", type: "ResolvableStructMacro")
