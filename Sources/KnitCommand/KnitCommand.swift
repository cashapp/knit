import ArgumentParser

@main
public struct KnitCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "knit",
        subcommands: [
            GenCommand.self,
            ModuleDependenciesCommand.self,
        ]
    )

    public init() { }

}
