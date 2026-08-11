//
//  PurchaseResult.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

/// Purpl 상품 구매 결과
public enum PurchaseResult: Equatable, Sendable {
    /// StoreKit 구매 완료
    case completed
    /// 보호자 승인 등 구매 완료 대기
    case pending
    /// 사용자 구매 취소
    case cancelled
}
