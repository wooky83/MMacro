import Foundation
// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A macro that produces both a value and a string containing the
/// source code that generated the value. For example,
///
///     #stringify(x + y)
///
/// produces a tuple `(x + y, "x + y")`.
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MMacroMacros", type: "StringifyMacro")

/// A macro that creates accessor properties for RxSwift Relay objects.
/// For BehaviorRelay, it creates both Observable and value accessors.
/// For PublishRelay, it creates only Observable accessors.
///
/// For example:
///
///     @RelayAccessor
///     private let messageSbj = BehaviorRelay<String>(value: "")
///
/// produces:
///
///     var messageObservable: Observable<String> { messageSbj.asObservable() }
///     var messageValue: String { messageSbj.value }
///
@attached(peer, names: arbitrary)
public macro RelayAccessor() = #externalMacro(module: "MMacroMacros", type: "RelayAccessor")

@attached(member, names: named(reuseIdentifier))
public macro ReuseIdentifier() = #externalMacro(module: "MMacroMacros", type: "ReuseIdentifierMacro")

@attached(peer, names: arbitrary)
@attached(accessor)
public macro AssociatedObject(_ policy: objc_AssociationPolicy) = #externalMacro(module: "MMacroMacros", type: "AssociatedObjectMacro")
