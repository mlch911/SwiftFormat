//
//  AddDynamicTests.swift
//  SwiftFormatTests
//
//  Created by mlch911 on 2025/6/19.
//

import XCTest
@testable import SwiftFormat

class AddDynamicTests: XCTestCase {
    func test() {
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

        extension TestClass {
            func method() -> A {}
        }

        extension TestClass: XXProtocol {
            func method() -> A {}
        }

        private extension TestClass {
            func method() -> A {}
        }

        func method() -> A {}
        """
        let output = """
        class TestClass: NSObject {
            dynamic func method() -> A {}
            public dynamic func publicMethod() -> A {}
            private func privateMethod() -> A {}

            public dynamic static func publicClassMethod() -> A {}
            private static func privateClassMethod() -> A {}
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

        extension TestClass {
            func method() -> A {}
        }

        extension TestClass: XXProtocol {
            func method() -> A {}
        }

        private extension TestClass {
            func method() -> A {}
        }

        func method() -> A {}
        """
        testFormatting(for: input, output, rule: .addDynamic, options: FormatOptions(addDynamic: true))
    }
}
