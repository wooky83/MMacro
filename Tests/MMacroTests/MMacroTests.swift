import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(MMacroMacros)
import MMacroMacros

let testMacros: [String: Macro.Type] = [
    "stringify": StringifyMacro.self,
    "RelayAccessor": RelayAccessor.self,
]
#endif

final class MMacroTests: XCTestCase {
    func testMacro() throws {
        #if canImport(MMacroMacros)
        assertMacroExpansion(
            """
            #stringify(a + b)
            """,
            expandedSource: """
            (a + b, "a + b")
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithStringLiteral() throws {
        #if canImport(MMacroMacros)
        assertMacroExpansion(
            #"""
            #stringify("Hello, \(name)")
            """#,
            expandedSource: #"""
            ("Hello, \(name)", #""Hello, \(name)""#)
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testBehaviorRelayMacro() throws {
#if canImport(MMacroMacros)
        // 이제 정확한 형식으로 테스트
        assertMacroExpansion(
                """
                @RelayAccessor
                private let messageSbj = BehaviorRelay<String>(value: "")
                """,
                expandedSource: """
                private let messageSbj = BehaviorRelay<String>(value: "")
                
                var messageObservable: Observable<String> {
                    messageSbj.asObservable()
                }
                
                var messageValue: String {
                    messageSbj.value
                }
                """,
                macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }
    
    func testPublishRelayMacro() throws {
        #if canImport(MMacroMacros)
            assertMacroExpansion(
                """
                @RelayAccessor
                private let eventSbj = PublishRelay<Event>()
                """,
                expandedSource: """
                private let eventSbj = PublishRelay<Event>()
                
                var eventObservable: Observable<Event> {
                    eventSbj.asObservable()
                }
                """,
                macros: testMacros
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
