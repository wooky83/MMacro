import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// 멤버 변수에 붙는 매크로 정의
public struct RelayAccessor: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 변수 선언인지 확인
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            throw MacroError("@RelayAccessor can only be applied to a variable declaration")
        }
        
        // private let인지 확인
        guard varDecl.modifiers.contains(where: { $0.name.text == "private" || $0.name.text == "fileprivate" }),
              varDecl.bindingSpecifier.text == "let" else {
            throw MacroError("@RelayAccessor can only be applied to private or fileprivate let variables")
        }
        
        var results: [DeclSyntax] = []
        
        // 각 바인딩 처리
        for binding in varDecl.bindings {
            // 변수 이름 가져오기
            guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let identifier = identifierPattern.identifier.text.removingSuffix("Sbj") else {
                continue
            }
            
            // 타입 어노테이션 확인 또는 초기화 표현식 확인
            let typeDescription: String
            if let typeAnnotation = binding.typeAnnotation {
                typeDescription = typeAnnotation.type.description
            } else if let initializer = binding.initializer?.value {
                // 초기화 표현식에서 타입 추론
                typeDescription = initializer.description
            } else {
                continue
            }
            
            // Relay 타입인지 확인 (BehaviorRelay 또는 PublishRelay)
            guard typeDescription.contains("Relay") else {
                continue
            }
            
            // 타입 추출 (XXXRelay<Type> -> Type)
            guard let startIdx = typeDescription.firstIndex(of: "<"),
                  let endIdx = typeDescription.lastIndex(of: ">"),
                  startIdx < endIdx else {
                continue
            }
            
            let valueTypeStartIdx = typeDescription.index(after: startIdx)
            let valueType = String(typeDescription[valueTypeStartIdx..<endIdx])
            
            // Observable 프로퍼티 생성 (모든 Relay 타입에 대해)
            let observableProperty = """
            var \(identifier)Observable: Observable<\(valueType)> {
                \(identifierPattern.identifier.text).asObservable()
            }
            """
            results.append(DeclSyntax(stringLiteral: observableProperty))
            
            // 값 프로퍼티는 BehaviorRelay에만 생성
            if typeDescription.contains("BehaviorRelay") {
                let valueProperty = """
                var \(identifier)Value: \(valueType) {
                    \(identifierPattern.identifier.text).value
                }
                """
                results.append(DeclSyntax(stringLiteral: valueProperty))
            }
        }
        
        return results
    }
}

// String 확장
fileprivate extension String {
    func removingSuffix(_ suffix: String) -> String? {
        guard self.hasSuffix(suffix) else {
            return self
        }
        return String(self.dropLast(suffix.count))
    }
}

// 에러 정의
struct MacroError: Error, CustomStringConvertible {
    var message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var description: String {
        return message
    }
}
