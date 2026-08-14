//
//  ResolvedPaywallConfiguration.swift
//  Purpl
//
//  Created by Int on 8/11/26.
//

import Foundation

// 원격 페이월 조회를 마친 구매 구성
/// A resolved purchase configuration returned by a remote paywall request.
public struct ResolvedPaywallConfiguration: Sendable {
    // 페이월 구성 식별자
    /// The paywall configuration identifier.
    public let paywallIdentifier: String

    // 상품과 권한 연결을 해석할 전체 구매 구성
    /// The complete purchase configuration used to resolve product and entitlement mappings.
    public let purchaseConfiguration: PurchaseConfiguration

    // 페이월에서 판매할 구매 카탈로그
    /// The purchase catalog sold on the paywall.
    public let catalog: PurchaseCatalog

    // 기본 선택 상품 식별자
    /// The product identifier selected by default.
    public let defaultProductIdentifier: String?

    // 요청 언어에 맞게 해결한 상품 표시 내용
    /// Product display content resolved for the requested language.
    public let productContents: [ResolvedPaywallProductContent]

    // 요청 언어에 맞게 해결한 자동 갱신 안내 문구
    /// The auto-renewal notice resolved for the requested language.
    public let autoRenewalNotice: String?

    // 개인정보 처리방침 주소
    /// The privacy policy URL.
    public let privacyPolicyURL: URL?

    // 서비스 약관 주소
    /// The terms of service URL.
    public let termsOfServiceURL: URL

    // 원격 구성의 마지막 수정 시각
    /// The date when the remote configuration was last updated.
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

// 원격 페이월에서 해결한 상품 표시 내용
/// Product display content resolved by a remote paywall.
public struct ResolvedPaywallProductContent: Sendable {
    // StoreKit 상품 식별자
    /// The StoreKit product identifier.
    public let productIdentifier: String

    // 선택 표시 제목
    /// The optional display title.
    public let title: String?

    // 선택 표시 설명
    /// The optional display description.
    public let description: String?

    // 해결된 상품 표시 내용 생성
    /// Creates resolved product display content.
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
