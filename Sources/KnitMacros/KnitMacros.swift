//
// Copyright © Block, Inc. All rights reserved.
//

@attached(peer, names: named(make))
public macro Resolvable<ResolverType>() = #externalMacro(module: "KnitMacrosImplementations", type: "ResolvableMacro")
