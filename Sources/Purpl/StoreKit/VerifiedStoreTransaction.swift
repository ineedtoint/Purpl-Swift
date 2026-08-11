//
//  VerifiedStoreTransaction.swift
//  Purpl
//
//  Created by Int on 7/27/26.
//

import Foundation
import StoreKit

/// Apple이 검증한 StoreKit 거래
///
/// 상품 유형과 관계없이 StoreKit이 제공하는 거래 사실을 내부 계층에 전달한다.
struct VerifiedStoreTransaction: Sendable {
    /// 검증된 StoreKit 거래 JWS
    let signedTransaction: String

    /// Apple 거래 식별자
    let transactionIdentifier: UInt64

    /// 구매 계보를 나타내는 Apple 최초 거래 식별자
    let originalTransactionIdentifier: UInt64

    /// StoreKit 상품 식별자
    let productIdentifier: String

    /// StoreKit 상품 유형
    let productType: Product.ProductType

    /// 한 거래에서 구매한 상품 수량
    let purchasedQuantity: Int

    /// 거래에 서명되어 포함된 앱 계정 식별자
    let appAccountToken: UUID?

    /// 자동 갱신 구독 그룹 식별자
    let subscriptionGroupIdentifier: String?

    /// 본인 구매 또는 가족 공유 거래 소유 유형
    let ownershipType: Transaction.OwnershipType

    /// StoreKit 거래 구매 시각
    let purchaseDate: Date

    /// StoreKit 거래 만료 시각
    let expirationDate: Date?

    /// StoreKit 거래 회수 시각
    let revocationDate: Date?

    /// 상위 등급 구독으로 전환되어 현재 거래가 대체됐는지 여부
    let isUpgraded: Bool

    /// StoreKit 거래를 발급한 환경
    let environment: AppStore.Environment

    /// 검증된 거래의 처리가 끝났음을 StoreKit에 알리는 작업
    private let finishOperation: @Sendable () async -> Void

    /// 검증된 StoreKit 거래 생성
    init(
        signedTransaction: String,
        transactionIdentifier: UInt64,
        originalTransactionIdentifier: UInt64,
        productIdentifier: String,
        productType: Product.ProductType,
        purchasedQuantity: Int,
        appAccountToken: UUID?,
        subscriptionGroupIdentifier: String?,
        ownershipType: Transaction.OwnershipType,
        purchaseDate: Date,
        expirationDate: Date?,
        revocationDate: Date?,
        isUpgraded: Bool,
        environment: AppStore.Environment,
        finishOperation: @escaping @Sendable () async -> Void
    ) {
        self.signedTransaction = signedTransaction
        self.transactionIdentifier = transactionIdentifier
        self.originalTransactionIdentifier = originalTransactionIdentifier
        self.productIdentifier = productIdentifier
        self.productType = productType
        self.purchasedQuantity = purchasedQuantity
        self.appAccountToken = appAccountToken
        self.subscriptionGroupIdentifier = subscriptionGroupIdentifier
        self.ownershipType = ownershipType
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isUpgraded = isUpgraded
        self.environment = environment
        self.finishOperation = finishOperation
    }

    /// 검증된 거래의 처리가 끝났음을 StoreKit에 전달
    func finish() async {
        await finishOperation()
    }
}
