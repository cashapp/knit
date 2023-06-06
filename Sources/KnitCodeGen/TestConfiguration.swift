import SwiftSyntax

public class TestConfiguration {

    public var testSetupCodeBlock: CodeBlockItemListSyntax?

    public var imports: [String]

    public init(
        testSetupCodeBlock: CodeBlockItemListSyntax? = nil,
        imports: [String] = []
    ) {
        self.testSetupCodeBlock = testSetupCodeBlock
        self.imports = imports
    }

}
