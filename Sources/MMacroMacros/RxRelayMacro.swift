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
        
        // private let/var인지 확인
        guard varDecl.modifiers.contains(where: { $0.name.text == "private" || $0.name.text == "fileprivate" }) else {
            throw MacroError("@RelayAccessor can only be applied to private or fileprivate variables")
        }
        
        var results: [DeclSyntax] = []
        
        // 각 바인딩 처리
        for binding in varDecl.bindings {
            // 변수 이름 가져오기
            guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            
            let originalName = identifierPattern.identifier.text
            let baseName: String
            
            // 접미사 제거 (Sbj 또는 Subject)
            if originalName.hasSuffix("Sbj") {
                baseName = String(originalName.dropLast(3))
            } else if originalName.hasSuffix("Subject") {
                baseName = String(originalName.dropLast(7))
            } else {
                baseName = originalName
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
            
            // RxSwift Relay 타입 또는 Combine Subject 타입인지 확인
            let isRxRelay = typeDescription.contains("Relay")
            let isCombineSubject = typeDescription.contains("Subject") || typeDescription.contains("CurrentValueSubject") || typeDescription.contains("PassthroughSubject")
            
            guard isRxRelay || isCombineSubject else {
                continue
            }
            
            // 타입 추출 (XXXRelay<Type> 또는 XXXSubject<Type, Error>)
            guard let startIdx = typeDescription.firstIndex(of: "<") else {
                continue
            }
            
            // 제네릭 타입 파싱 (중첩된 꺾쇠 괄호 처리)
            var depth = 1
            var endIdx = startIdx
            var currentIdx = typeDescription.index(after: startIdx)
            
            while depth > 0 && currentIdx < typeDescription.endIndex {
                let char = typeDescription[currentIdx]
                if char == "<" {
                    depth += 1
                } else if char == ">" {
                    depth -= 1
                    if depth == 0 {
                        endIdx = currentIdx
                        break
                    }
                }
                currentIdx = typeDescription.index(after: currentIdx)
            }
            
            guard depth == 0 else {
                continue
            }
            
            // 첫 번째 타입 파라미터 추출 (Combine Subject는 두 개의 타입 파라미터가 있음)
            let valueTypeStartIdx = typeDescription.index(after: startIdx)
            let genericContent = String(typeDescription[valueTypeStartIdx..<endIdx])
            
            // Combine Subject의 경우 Error 타입 제거
            let valueType: String
            if isCombineSubject && genericContent.contains(",") {
                if let commaIdx = genericContent.firstIndex(of: ",") {
                    valueType = String(genericContent[genericContent.startIndex..<commaIdx]).trimmingCharacters(in: .whitespaces)
                } else {
                    valueType = genericContent
                }
            } else {
                valueType = genericContent
            }
            
            // RxSwift Relay 타입에 대한 Observable 프로퍼티 생성
            if isRxRelay {
                let observableProperty = """
                var \(baseName)Observable: Observable<\(valueType)> {
                    \(originalName).asObservable()
                }
                """
                results.append(DeclSyntax(stringLiteral: observableProperty))
                
                // 값 프로퍼티는 BehaviorRelay에만 생성
                if typeDescription.contains("BehaviorRelay") {
                    let valueProperty = """
                    var \(baseName)Value: \(valueType) {
                        \(originalName).value
                    }
                    """
                    results.append(DeclSyntax(stringLiteral: valueProperty))
                }
            }
            
            // Combine Subject 타입에 대한 Publisher 프로퍼티 생성
            if isCombineSubject {
                let publisherProperty = """
                var \(baseName)Observable: AnyPublisher<\(valueType), Never> {
                    \(originalName).eraseToAnyPublisher()
                }
                """
                results.append(DeclSyntax(stringLiteral: publisherProperty))
                
                // 값 프로퍼티는 CurrentValueSubject에만 생성
                if typeDescription.contains("CurrentValueSubject") {
                    let valueProperty = """
                    var \(baseName)Value: \(valueType) {
                        \(originalName).value
                    }
                    """
                    results.append(DeclSyntax(stringLiteral: valueProperty))
                }
            }
        }
        
        return results
    }
}
