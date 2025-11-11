//
//  AddDynamicTests.swift
//  SwiftFormatTests
//
//  Created by mlch911 on 2025/6/19.
//

import XCTest
@testable import SwiftFormat

final class AddDynamicTests: XCTestCase {
    func testAddDynamicToClassMethods() {
        let input = """
        class TestClass: NSObject {
            func method() -> A {}
            public func publicMethod() -> A {}
            private func privateMethod() -> A {}

            public static func publicClassMethod() -> A {}
            private static func privateClassMethod() -> A {}
            static func internalClassMethod() -> A {}

            override public func publicMethod() -> A {}
            override public class func publicClassMethod() -> A {}

            public init() {
                super.init(frame: .zero)
            }
        }

        struct TestStruct {
            func method() -> A {}
        }

        enum TestEnum {
            case test

            func method() -> A {}
        }

        private func method() -> A {}
        """
        let output = """
        @objcMembers
        class TestClass: NSObject {
            dynamic func method() -> A {}
            public dynamic func publicMethod() -> A {}
            @objc private dynamic func privateMethod() -> A {}

            public dynamic static func publicClassMethod() -> A {}
            @objc private dynamic static func privateClassMethod() -> A {}
            dynamic static func internalClassMethod() -> A {}

            override public dynamic func publicMethod() -> A {}
            override public dynamic class func publicClassMethod() -> A {}

            public dynamic init() {
                super.init(frame: .zero)
            }
        }

        struct TestStruct {
            func method() -> A {}
        }

        enum TestEnum {
            case test

            func method() -> A {}
        }

        private func method() -> A {}
        """
        testFormatting(for: input, output, rule: .addDynamic, options: FormatOptions(addDynamic: true), exclude: [.redundantPublic])
    }

    func testDoesNotAddObjcMembersToGenericClasses() {
        let input = """
        class GenericClass<T>: NSObject {
            func method() -> A {}
        }

        class GenericClass<T, U>: NSObject {
            func method() -> A {}
        }

        class NormalClass: NSObject {
            func method() -> A {}
        }
        """
        let output = """
        class GenericClass<T>: NSObject {
            func method() -> A {}
        }

        class GenericClass<T, U>: NSObject {
            func method() -> A {}
        }

        @objcMembers
        class NormalClass: NSObject {
            dynamic func method() -> A {}
        }
        """
        testFormatting(for: input, output, rule: .addDynamic, options: FormatOptions(addDynamic: true))
    }

    func testDoesNotDuplicateObjcMembers() {
        let input = """
        @objcMembers
        class TestClass: NSObject {
            func method() -> A {}
        }
        """
        let output = """
        @objcMembers
        class TestClass: NSObject {
            dynamic func method() -> A {}
        }
        """
        testFormatting(for: input, output, rule: .addDynamic, options: FormatOptions(addDynamic: true))
    }

    func testDoesNotDuplicateDynamic() {
        let input = """
        class TestClass: NSObject {
            dynamic func method() -> A {}
            @objc private dynamic func privateMethod() -> A {}
        }
        """
        let output = """
        @objcMembers
        class TestClass: NSObject {
            dynamic func method() -> A {}
            @objc private dynamic func privateMethod() -> A {}
        }
        """
        testFormatting(for: input, output, rule: .addDynamic, options: FormatOptions(addDynamic: true))
    }

    func testDoesNotAddToNonobjcClass() {
        let input = """
        @nonobjc
        class TestClass: NSObject {
            func method() -> A {}
        }
        """
        testFormatting(for: input, rule: .addDynamic, options: FormatOptions(addDynamic: true))
    }

    func testDoesNotAddToNonobjcMethod() {
        let input = """
        class TestClass: NSObject {
            @nonobjc func method() -> A {}
            func normalMethod() -> A {}
        }
        """
        let output = """
        @objcMembers
        class TestClass: NSObject {
            @nonobjc func method() -> A {}
            dynamic func normalMethod() -> A {}
        }
        """
        testFormatting(for: input, output, rule: .addDynamic, options: FormatOptions(addDynamic: true))
    }

    func testReplacesSimpleObjcWithObjcMembers() {
        let input = """
        @objc
        class TestClass: NSObject {
            func method() -> A {}
        }
        """
        let output = """
        @objcMembers
        class TestClass: NSObject {
            dynamic func method() -> A {}
        }
        """
        testFormatting(for: input, output, rule: .addDynamic, options: FormatOptions(addDynamic: true))
    }

    func testAddsObjcMembersToObjcWithParameters() {
        let input = """
        @objc(MyClass)
        class TestClass: NSObject {
            func method() -> A {}
        }
        """
        let output = """
        @objc(MyClass)
        @objcMembers
        class TestClass: NSObject {
            dynamic func method() -> A {}
        }
        """
        testFormatting(for: input, output, rule: .addDynamic, options: FormatOptions(addDynamic: true))
    }
}
