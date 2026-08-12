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

    /// 요청 언어에 맞게 해결한 상품 표시 내용
    public let productContents: [ResolvedPaywallProductContent]

    /// 요청 언어에 맞게 해결한 자동 갱신 안내 문구
    public let autoRenewalNotice: String?

    /// 개인정보 처리방침 주소
    public let privacyPolicyURL: URL?

    /// 서비스 약관 주소
    public let termsOfServiceURL: URL

    /// 원격 구성의 마지막 수정 시각
    public let updatedAt: Date

    /// 해석된 원격 페이월 구성 생성
    init(
        paywallIdentifier: String,
        purchaseConfiguration: PurchaseConfiguration,
        catalog: PurchaseCatalog,
        defaultProductIdentifier: String?,
        productContents: [ResolvedPaywallProductContent] = [],
        autoRenewalNotice: String? = nil,
        privacyPolicyURL: URL? = nil,
        termsOfServiceURL: URL = URL(
            string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        )!,
        updatedAt: Date
    ) {
        self.paywallIdentifier = paywallIdentifier
        self.purchaseConfiguration = purchaseConfiguration
        self.catalog = catalog
        self.defaultProductIdentifier = defaultProductIdentifier
        self.productContents = productContents
        self.autoRenewalNotice = autoRenewalNotice
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfServiceURL = termsOfServiceURL
        self.updatedAt = updatedAt
    }
}

/// 원격 페이월에서 해결한 상품 표시 내용
public struct ResolvedPaywallProductContent: Sendable {
    /// StoreKit 상품 식별자
    public let productIdentifier: String

    /// 선택 표시 제목
    public let title: String?

    /// 선택 표시 설명
    public let description: String?

    /// 해결된 상품 표시 내용 생성
    public init(
        productIdentifier: String,
        title: String? = nil,
        description: String? = nil
    ) {
        self.productIdentifier = productIdentifier
        self.title = title
        self.description = description
    }
}
