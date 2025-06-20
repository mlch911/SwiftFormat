//
//  AddDynamic.swift
//  SwiftFormat
//
//  Created by mlch911 on 2025/6/19.
//

import Foundation

public extension FormatRule {
    /// Add dynamic keyword to function declarations.
    static let addDynamic = FormatRule(
        help: "Add dynamic keyword to function declarations.",
        options: ["addDynamic"]
    ) { formatter in
        guard formatter.options.addDynamic else { return }

        var inClass = false
        var classLevel = 0
        var currentLevel = 0

        formatter.forEach(.nonSpaceOrComment) { i, token in
            // 跟踪大括号层级
            if token.string == "{" {
                currentLevel += 1
            } else if token.string == "}" {
                currentLevel -= 1
                if currentLevel < classLevel {
                    inClass = false
                }
            }

            // 检测是否进入类定义
            if token.string == "class", !token.isIdentifier {
                var j = i + 1
                // 跳过空格
                while let nextToken = formatter.token(at: j), nextToken.isSpace {
                    j += 1
                }
                // 检查是否是类声明（后面跟着标识符）
                if let nextToken = formatter.token(at: j), nextToken.isIdentifier {
                    inClass = true
                    classLevel = currentLevel
                }
            }

            // 检测是否进入 struct 或 enum
            if ["struct", "enum", "extension"].contains(token.string), !token.isIdentifier {
                inClass = false
            }

            // 只处理类内部的方法和初始化器声明
            if ["func", "init"].contains(token.string), inClass {
                // 检查前一个非空白字符，如果是点号，说明是方法调用而不是声明
                var k = i - 1
                while k >= 0, let prevToken = formatter.token(at: k) {
                    if !prevToken.isSpace {
                        if prevToken.string == "." {
                            return // 这是方法调用，跳过
                        }
                        break
                    }
                    k -= 1
                }

                var j = i - 1
                var hasPrivate = false
                var hasDynamic = false
                var modifiers: [(token: Token, index: Int)] = []

                // 向前查找修饰符，直到行首或非修饰符token
                while j >= 0, let token = formatter.token(at: j), token.isSpace {
                    j -= 1
                }

                // 收集所有修饰符
                while j >= 0, let token = formatter.token(at: j) {
                    if token.isLinebreak {
                        break
                    }
                    if !token.isSpace && !token.isLinebreak {
                        if token.string == "private" {
                            hasPrivate = true
                        } else if token.string == "dynamic" {
                            hasDynamic = true
                        }
                        modifiers.insert((token: token, index: j), at: 0)
                    }
                    j -= 1
                }

                // 如果不是 private 方法且没有 dynamic 关键字，则添加 dynamic
                if !hasPrivate, !hasDynamic {
                    var insertIndex = i

                    if modifiers.isEmpty {
                        // 如果没有修饰符，直接在 func/init 关键字前插入
                        insertIndex = i
                        formatter.insert(.keyword("dynamic"), at: insertIndex)
                        formatter.insert(.space(" "), at: insertIndex + 1)
                    } else {
                        // 找到访问修饰符
                        let accessModifiers = ["open", "public", "internal", "fileprivate", "private", "override"]
                        let hasAccessModifiers = modifiers.contains(where: { accessModifiers.contains($0.token.string) })
                        if hasAccessModifiers {
                            insertIndex = 0
                            for (_, index) in modifiers.filter({ accessModifiers.contains($0.token.string) }) {
                                insertIndex = max(insertIndex, index + 2)
                            }
                            formatter.insert(.keyword("dynamic"), at: insertIndex)
                            formatter.insert(.space(" "), at: insertIndex + 1)
                        } else {
                            // 没有访问修饰符，在第一个修饰符前插入
                            insertIndex = modifiers[0].index
                            formatter.insert(.keyword("dynamic"), at: insertIndex)
                            formatter.insert(.space(" "), at: insertIndex + 1)
                        }
                    }
                }
            }
        }
    } examples: {
        """
        ```diff
        class TestClass: NSObject {
            - func method() -> A {}
            + dynamic func method() -> A {}
            - public func publicMethod() -> A {}
            + public dynamic func publicMethod() -> A {}
            private func privateMethod() -> A {}
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

        struct TestStruct {
            func method() -> A {}
        }

        enum TestEnum {
            func method() -> A {}
        }

        extension TestClass {
            func method() -> A {}
        }
        ```
        """
    }
}
