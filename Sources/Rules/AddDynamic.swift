//
//  AddDynamic.swift
//  SwiftFormat
//
//  Created by mlch911 on 2025/6/19.
//

import Foundation

public extension FormatRule {
    /// Add dynamic keyword to function declarations and @objcMembers to classes.
    static let addDynamic = FormatRule(
        help: "Add dynamic keyword to function declarations and @objcMembers to classes.",
        options: ["add-dynamic"]
    ) { formatter in
        guard formatter.options.addDynamic else { return }

        // Pass 1: Add @objcMembers to non-generic classes
        formatter.forEach(.keyword("class")) { i, _ in
            guard let nameIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: i),
                  formatter.tokens[nameIndex].isIdentifier
            else {
                return
            }

            // Check for generics
            guard let nextIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: nameIndex),
                  formatter.tokens[nextIndex] != .startOfScope("<")
            else {
                return // Skip generic classes
            }

            // Check if @objcMembers or @nonobjc already exists
            if formatter.modifiersForDeclaration(at: i, contains: "@objcMembers") ||
                formatter.modifiersForDeclaration(at: i, contains: "@nonobjc")
            {
                return // Already has @objcMembers or marked as @nonobjc
            }

            // Check if @objc exists (search manually since modifiersForDeclaration doesn't catch @objc(xxx))
            var objcIndex: Int?
            let lineStart = formatter.startOfLine(at: i)

            // Search on the same line first
            for searchIndex in (lineStart ..< i).reversed() {
                let token = formatter.tokens[searchIndex]
                if token == .keyword("@objc") {
                    objcIndex = searchIndex
                    break
                }
            }

            // If not found on the same line, search on previous lines
            if objcIndex == nil {
                var searchIndex = lineStart - 1
                while searchIndex >= 0 {
                    let token = formatter.tokens[searchIndex]
                    if token == .keyword("@objc") {
                        objcIndex = searchIndex
                        break
                    }
                    // Stop if we hit a non-space/comment/linebreak token that's not an attribute
                    if !token.isSpaceOrCommentOrLinebreak, !token.isAttribute {
                        break
                    }
                    searchIndex -= 1
                }
            }

            if let objcIdx = objcIndex {
                // Check if @objc has parameters like @objc(name)
                var hasParameters = false
                var checkIndex = objcIdx + 1
                while checkIndex < formatter.tokens.count {
                    let token = formatter.tokens[checkIndex]
                    if token == .startOfScope("(") {
                        hasParameters = true
                        break
                    } else if !token.isSpaceOrComment {
                        // Hit something else (like linebreak or keyword), no parameters
                        break
                    }
                    checkIndex += 1
                }

                if hasParameters {
                    // @objc has parameters, insert @objcMembers on a new line before it
                    formatter.insert(.keyword("@objcMembers"), at: objcIdx)
                    formatter.insertLinebreak(at: objcIdx + 1)
                } else {
                    // Simple @objc without parameters, replace it with @objcMembers
                    formatter.replaceToken(at: objcIdx, with: .keyword("@objcMembers"))
                }
                return
            }

            // Find line start
            let lineStartIndex = formatter.startOfLine(at: i)

            // Insert @objcMembers
            formatter.insert(.keyword("@objcMembers"), at: lineStartIndex)
            formatter.insertLinebreak(at: lineStartIndex + 1)
        }

        // Pass 2: Add dynamic to methods in classes (not in extensions or global scope)
        struct ScopeInfo {
            let type: String
            let level: Int
            let isGeneric: Bool
            let hasNonobjc: Bool
        }

        var scopeStack: [ScopeInfo] = []
        var currentLevel = 0
        var pendingScopeInfo: ScopeInfo? = nil

        formatter.forEach(.nonSpaceOrComment) { i, token in
            // Track brace level and finalize pending scope
            if token == .startOfScope("{") {
                currentLevel += 1
                // If we have a pending scope, push it now with the correct level
                if var scopeInfo = pendingScopeInfo {
                    scopeInfo = ScopeInfo(
                        type: scopeInfo.type,
                        level: currentLevel,
                        isGeneric: scopeInfo.isGeneric,
                        hasNonobjc: scopeInfo.hasNonobjc
                    )
                    scopeStack.append(scopeInfo)
                    pendingScopeInfo = nil
                }
            } else if token == .endOfScope("}") {
                currentLevel -= 1
                // Pop scopes that have ended
                while !scopeStack.isEmpty, scopeStack.last!.level > currentLevel {
                    scopeStack.removeLast()
                }
            }

            // Detect class, struct, enum, or extension entry
            if token == .keyword("class") || token == .keyword("struct") ||
                token == .keyword("enum") || token == .keyword("extension")
            {
                guard let nameIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: i),
                      formatter.tokens[nameIndex].isIdentifier || token == .keyword("extension")
                else {
                    return
                }

                // Check if generic (for class/struct/enum/extension)
                var isGeneric = false
                if let nextIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: nameIndex),
                   formatter.tokens[nextIndex] == .startOfScope("<")
                {
                    isGeneric = true
                }

                // Check if has @nonobjc
                let hasNonobjc = formatter.modifiersForDeclaration(at: i, contains: "@nonobjc")

                // Store the scope info, will be pushed when we encounter the opening brace
                pendingScopeInfo = ScopeInfo(
                    type: token.string,
                    level: currentLevel, // Will be updated when we push
                    isGeneric: isGeneric,
                    hasNonobjc: hasNonobjc
                )
            }

            // Handle methods and init - only process if we're directly inside a class
            guard token == .keyword("func") || token == .keyword("init") else {
                return
            }

            // Check if we're inside a non-generic, non-@nonobjc class (and not in a nested struct/enum/extension or global scope)
            guard let currentScope = scopeStack.last,
                  currentScope.type == "class",
                  currentScope.level == currentLevel,
                  !currentScope.isGeneric,
                  !currentScope.hasNonobjc
            else {
                return // Not directly in a valid class body
            }

            // Check if this is a method call (preceded by a dot)
            if let prevNonSpaceIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, before: i),
               formatter.tokens[prevNonSpaceIndex] == .operator(".", .infix)
            {
                return // Method call, skip
            }

            // Check if already has dynamic or marked as @nonobjc
            guard !formatter.modifiersForDeclaration(at: i, contains: "dynamic"),
                  !formatter.modifiersForDeclaration(at: i, contains: "@nonobjc")
            else {
                return // Already has dynamic or marked as @nonobjc
            }

            // Check if private
            let hasPrivate = formatter.modifiersForDeclaration(at: i, contains: "private")
            let hasObjc = formatter.modifiersForDeclaration(at: i, contains: "@objc")

            // Handle private methods: need @objc and dynamic
            if hasPrivate {
                // Add @objc if needed
                if !hasObjc {
                    // Insert @objc at the beginning of the line (after indentation)
                    let lineStartIndex = formatter.startOfLine(at: i, excludingIndent: true)
                    formatter.insert(.keyword("@objc"), at: lineStartIndex)
                    formatter.insert(.space(" "), at: lineStartIndex + 1)
                }

                // Find private keyword index to insert dynamic after it
                var privateIndex: Int?
                var j = i - 1
                while j >= 0 {
                    let checkToken = formatter.tokens[j]
                    if checkToken.isLinebreak {
                        break
                    }
                    if checkToken.string == "private" {
                        privateIndex = j
                        break
                    }
                    j -= 1
                }

                // Add dynamic after private
                if let privateIdx = privateIndex {
                    var insertIdx = privateIdx + 1
                    while insertIdx < formatter.tokens.count,
                          formatter.tokens[insertIdx].isSpaceOrComment
                    {
                        insertIdx += 1
                    }
                    formatter.insert(.keyword("dynamic"), at: insertIdx)
                    formatter.insert(.space(" "), at: insertIdx + 1)
                }
            } else {
                // Handle non-private methods: add dynamic only
                // Find the position to insert dynamic (after access modifiers and before static/class)
                // Order should be: override + access + dynamic + static/class + func/init
                let accessModifiers = ["open", "public", "internal", "fileprivate"]
                let staticModifiers = ["static", "class"]
                var lastAccessModifierIndex: Int?
                var firstStaticModifierIndex: Int?
                var overrideIndex: Int?

                var j = i - 1
                while j >= 0 {
                    let checkToken = formatter.tokens[j]
                    if checkToken.isLinebreak {
                        break
                    }
                    if !checkToken.isSpaceOrCommentOrLinebreak {
                        if checkToken.string == "override" {
                            overrideIndex = j
                        } else if accessModifiers.contains(checkToken.string) {
                            lastAccessModifierIndex = j
                        } else if staticModifiers.contains(checkToken.string) {
                            if firstStaticModifierIndex == nil {
                                firstStaticModifierIndex = j
                            }
                        }
                    }
                    j -= 1
                }

                // Insert dynamic after access modifiers (including override) but before static/class
                // Priority: after override/access, before static/class
                if let staticIdx = firstStaticModifierIndex {
                    // Insert before static/class
                    formatter.insert(.keyword("dynamic"), at: staticIdx)
                    formatter.insert(.space(" "), at: staticIdx + 1)
                } else if let lastAccessIdx = lastAccessModifierIndex {
                    // Insert after the last access modifier
                    var insertIdx = lastAccessIdx + 1
                    while insertIdx < formatter.tokens.count,
                          formatter.tokens[insertIdx].isSpaceOrComment
                    {
                        insertIdx += 1
                    }
                    formatter.insert(.keyword("dynamic"), at: insertIdx)
                    formatter.insert(.space(" "), at: insertIdx + 1)
                } else if let overrideIdx = overrideIndex {
                    // Insert after override
                    var insertIdx = overrideIdx + 1
                    while insertIdx < formatter.tokens.count,
                          formatter.tokens[insertIdx].isSpaceOrComment
                    {
                        insertIdx += 1
                    }
                    formatter.insert(.keyword("dynamic"), at: insertIdx)
                    formatter.insert(.space(" "), at: insertIdx + 1)
                } else {
                    // No modifiers, insert before func/init
                    formatter.insert(.keyword("dynamic"), at: i)
                    formatter.insert(.space(" "), at: i + 1)
                }
            }
        }
    } examples: {
        """
        ```diff
        - class TestClass: NSObject {
        + @objcMembers
        + class TestClass: NSObject {
            - func method() -> A {}
            + dynamic func method() -> A {}
            - public func publicMethod() -> A {}
            + public dynamic func publicMethod() -> A {}
            - private func privateMethod() -> A {}
            + @objc private dynamic func privateMethod() -> A {}
            - static func internalClassMethod() -> A {}
            + dynamic static func internalClassMethod() -> A {}

            - override public func publicMethod() -> A {}
            + override public dynamic func publicMethod() -> A {}
            - override public class func publicClassMethod() -> A {}
            + override public dynamic class func publicClassMethod() -> A {}

            - public init() {
            + public dynamic init() {
                super.init(frame: .zero)
            }
        }

        // Generic classes are not modified
        class GenericClass<T>: NSObject {
            func method() -> A {}
        }

        struct TestStruct {
            func method() -> A {}
        }

        enum TestEnum {
            func method() -> A {}
        }

        // Extensions are not modified
        extension TestClass {
            func method() -> A {}
        }
        ```
        """
    }
}
