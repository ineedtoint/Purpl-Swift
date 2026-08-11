//
//  ResolvedPaywallConfiguration.swift
//  Purpl
//
//  Created by Int on 8/11/26.
//

import Foundation

/// 원격 페이월 조회를 마친 구매 구성
public struct ResolvedPaywallConfiguration: Sendable {
    /// 페이월 구성 식별자
    public let paywallIdentifier: String

    /// 상품과 권한 연결을 해석할 전체 구매 구성
    public let purchaseConfiguration: PurchaseConfiguration

    /// 페이월에서 판매할 구매 카탈로그
    public let catalog: PurchaseCatalog

    /// 기본 선택 상품 식별자
    public let defaultProductIdentifier: String?

    /// 원격 구성의 마지막 수정 시각
    public let updatedAt: Date

    /// 해석된 원격 페이월 구성 생성
    init(
        paywallIdentifier: String,
        purchaseConfiguration: PurchaseConfiguration,
        catalog: PurchaseCatalog,
        defaultProductIdentifier: String?,
        updatedAt: Date
    ) {
        self.paywallIdentifier = paywallIdentifier
        self.purchaseConfiguration = purchaseConfiguration
        self.catalog = catalog
        self.defaultProductIdentifier = defaultProductIdentifier
        self.updatedAt = updatedAt
    }
}
