//
//  StoreKitPurchaseResult.swift
//  Purpl
//
//  Created by Int on 7/27/26.
//

/// StoreKit 상품 구매 처리 결과
enum StoreKitPurchaseResult: Sendable {
    /// 검증된 StoreKit 거래를 포함한 구매 완료
    case completed(VerifiedStoreTransaction)

    /// 보호자 승인 등 구매 완료 대기
    case pending

    /// 사용자 구매 취소
    case cancelled
}
