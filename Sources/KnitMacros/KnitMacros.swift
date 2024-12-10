//
// Copyright © Block, Inc. All rights reserved.
//

@attached(peer, names: named(make))
public macro Resolvable<ResolverType>(arguments: [String] = [], names: [String: String] = [:]) = #externalMacro(module: "KnitMacrosImplementations", type: "ResolvableMacro")
