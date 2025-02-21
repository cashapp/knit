//
// Copyright © Block, Inc. All rights reserved.
//

@attached(peer, names: named(make))
public macro Resolvable<TargetResolver>() = #externalMacro(module: "KnitMacrosImplementations", type: "ResolvableMacro")
