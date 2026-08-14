//
//  PurchaseResult.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

// Purpl 상품 구매 결과
/// The result of a Purpl product purchase.
public enum PurchaseResult: Equatable, Sendable {
    // StoreKit 구매 완료
    /// The StoreKit purchase completed successfully.
    case completed
    // 보호자 승인 등 구매 완료 대기
    /// The purchase is awaiting completion, such as approval from a guardian.
    case pending
    // 사용자 구매 취소
    /// The user cancelled the purchase.
    case cancelled
}
