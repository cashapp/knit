//
// Copyright © Block, Inc. All rights reserved.
//

@attached(peer, names: named(make), overloaded)
public macro Resolvable<TargetResolver>() = #externalMacro(module: "KnitMacrosImplementations", type: "ResolvableMacro")
