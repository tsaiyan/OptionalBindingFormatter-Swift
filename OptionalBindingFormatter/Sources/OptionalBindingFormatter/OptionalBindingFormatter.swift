//
//  OptionalBindingFormatter.swift
//
//
//  Created by Artyom Baranov on 24.04.2024.
//

import Foundation
import SwiftSyntax
import SwiftParser

@main
struct Main {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            print("Usage: \(CommandLine.arguments[0]) <directory>")
            return
        }
        
        let directoryPath = CommandLine.arguments[1]
        let fileManager = FileManager.default
        
        try processDirectory(atPath: directoryPath, using: fileManager)
    }
    
    static func processDirectory(atPath path: String, using fileManager: FileManager) throws {
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        
        for item in contents {
            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Рекурсивно обрабатываем вложенную папку
                    try processDirectory(atPath: fullPath, using: fileManager)
                } else if item.hasSuffix(".swift") {
                    // Обрабатываем файл Swift
                    try processSwiftFile(atPath: fullPath)
                }
            }
        }
    }
    
    static func processSwiftFile(atPath path: String) throws {
        let url = URL(fileURLWithPath: path)
        let source = try String(contentsOf: url, encoding: .utf8)
        let sourceFile = try Parser.parse(source: source)
        
        // Применяем рефакторинг к файлу
        let rewriter = OptionalBindingChanger()
        let incremented = rewriter.visit(sourceFile)
        let rewrittenCode = incremented.description
        try rewrittenCode.write(to: url, atomically: true, encoding: .utf8)
        
        print("Processed file: \(path)")
    }
}


private class OptionalBindingChanger: SyntaxRewriter {

    override func visit(_ node: OptionalBindingConditionSyntax) -> OptionalBindingConditionSyntax {

        let childer = node.children(viewMode: .all)
        var leadingValue: String?
        var trailingValue: String?
        
        var trailing: InitializerClauseSyntax?
        
        childer.forEach { syntax in
            
            if let leading = IdentifierPatternSyntax(syntax) {
                leadingValue = leading._syntaxNode.trimmedDescription
            }
            
            if let trail = InitializerClauseSyntax(syntax) {
                trailingValue = trail._syntaxNode.trimmedDescription
                trailing = trail
            }
        }
        
        let result = OptionalBindingConditionSyntax(
            bindingSpecifier: node.bindingSpecifier,
            pattern: node.pattern
                .with(\.trailingTrivia, trailing?.trailingTrivia ?? .backslash)
        )
        
        if let leadingValue, let trailingValue,
           "= \(leadingValue)" == trailingValue {
            return result
        }

      return node
    }

}
