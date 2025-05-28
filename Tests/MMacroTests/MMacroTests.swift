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
    "ReuseIdentifier": ReuseIdentifierMacro.self,
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
                
                public var messageObservable: Observable<String> {
                    messageSbj.asObservable()
                }
                
                public var messageValue: String {
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
                
                public var eventObservable: Observable<Event> {
                    eventSbj.asObservable()
                }
                """,
                macros: testMacros
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testCombineComplexGenericType() throws {
           #if canImport(MMacroMacros)
           assertMacroExpansion(
               """
               @RelayAccessor
               private let presetModelsSubject = CurrentValueSubject<[DiscoverCardModel], Never>((0..<6).map { _ in DiscoverCardModel() })
               """,
               expandedSource: """
               private let presetModelsSubject = CurrentValueSubject<[DiscoverCardModel], Never>((0..<6).map { _ in DiscoverCardModel() })

               public var presetModelsObservable: AnyPublisher<[DiscoverCardModel], Never> {
                   presetModelsSubject.eraseToAnyPublisher()
               }
               
               public var presetModelsValue: [DiscoverCardModel] {
                   presetModelsSubject.value
               }
               """,
               macros: testMacros
           )
           #else
           throw XCTSkip("macros are only supported when running tests for the host platform")
           #endif
       }
    
    func testPassthroughSubjectMacro() throws {
        #if canImport(MMacroMacros)
        assertMacroExpansion(
            """
            @RelayAccessor
            private let notificationSubject = PassthroughSubject<Notification, Never>()
            """,
            expandedSource: """
            private let notificationSubject = PassthroughSubject<Notification, Never>()

            public var notificationObservable: AnyPublisher<Notification, Never> {
                notificationSubject.eraseToAnyPublisher()
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testExpanded() {
        assertMacroExpansion(
               """
               @ReuseIdentifier
               class CarouselCollectionViewCell {
               }
               """,
               expandedSource: """
               
               class CarouselCollectionViewCell {
               
                   static var reuseIdentifier: String {
                       "CarouselCollectionViewCell"
                   }
               }
               """,
               macros: testMacros
        )
    }
    
    func testAssociatedObjectMacro() {
        assertMacroExpansion(
            #"""
            class AssociatedClass { }
            extension AssociatedClass {
                @AssociatedObject(.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                var intValue: Int
                @AssociatedObject(.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                var StringValue: String = "Hello World!!"
            }
            """#,
            expandedSource: #"""
            class AssociatedClass { }
            extension AssociatedClass {
                var intValue: Int {
                    get {
                      if let associatedObject = objc_getAssociatedObject(
                          self,
                          &Self.__associated_intValueKey
                      ) as? Int {
                          return associatedObject
                      }
                      let variable = Int()
                      objc_setAssociatedObject(
                          self,
                          &Self.__associated_intValueKey,
                          variable,
                          .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                      )
                      return variable
                    }
                    set {
                      objc_setAssociatedObject(
                          self,
                          &Self.__associated_intValueKey,
                          newValue,
                          .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                      )
                    }
                }
            
                fileprivate static var __associated_intValueKey: UInt8 = 0
                var StringValue: String {
                    get {
                      if let associatedObject = objc_getAssociatedObject(
                          self,
                          &Self.__associated_StringValueKey
                      ) as? String  {
                          return associatedObject
                      }
                      let variable = "Hello World!!"
                      objc_setAssociatedObject(
                          self,
                          &Self.__associated_StringValueKey,
                          variable,
                          .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                      )
                      return variable
                    }
                    set {
                      objc_setAssociatedObject(
                          self,
                          &Self.__associated_StringValueKey,
                          newValue,
                          .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                      )
                    }
                }

                fileprivate static var __associated_StringValueKey: UInt8 = 0
            }
            """#,
            macros: ["AssociatedObject": AssociatedObjectMacro.self]
        )
    }
}
