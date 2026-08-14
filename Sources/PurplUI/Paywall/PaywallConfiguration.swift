//
//  PaywallConfiguration.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import Foundation
import Purpl

// 페이월 상품의 해결된 표시 내용
/// Resolved display content for a paywall product.
public struct PaywallProductDisplayContent: Sendable {
    // StoreKit 상품 식별자
    /// The StoreKit product identifier.
    public let productIdentifier: String

    // 선택 표시 제목
    /// The optional display title.
    public let title: String?

    // 선택 표시 설명
    /// The optional display description.
    public let description: String?

    // 페이월 상품 표시 내용 생성
    /// Creates display content for a paywall product.
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

// 페이월 구성
/// A configuration that defines the products and supporting content shown on a paywall.
public struct PaywallConfiguration: Sendable {
    // 페이월에서 사용할 구매 카탈로그
    /// The purchase catalog used by the paywall.
    public let catalog: PurchaseCatalog

    // 기본 선택 구매 옵션 식별자
    /// The purchase option identifier selected by default.
    public let defaultProductIdentifier: String?

    // StoreKit 상품 정보를 불러오지 못한 구매 옵션 표시 여부
    /// A Boolean value that indicates whether to show purchase options unavailable from StoreKit.
    public let showsUnavailablePurchaseOptions: Bool

    // 자동 갱신 안내 문구
    /// The localized auto-renewal notice resource.
    public let autoRenewalNoticeResource: LocalizedStringResource?

    // 서버에서 현재 언어에 맞게 해결한 자동 갱신 안내 문구
    /// The auto-renewal notice resolved by the server for the current language.
    public let autoRenewalNoticeText: String?

    // 서버에서 현재 언어에 맞게 해결한 상품 표시 내용
    /// Product display content resolved by the server for the current language.
    public let productDisplayContents: [PaywallProductDisplayContent]

    // 개인정보 처리방침 주소
    /// The privacy policy URL.
    public let privacyPolicyURL: URL?

    // 서비스 약관 주소
    /// The terms of service URL.
    public let termsOfServiceURL: URL?

    // 페이월 구성 생성
    /// Creates a paywall configuration.
    public init(
        catalog: PurchaseCatalog,
        defaultProductIdentifier: String? = nil,
        showsUnavailablePurchaseOptions: Bool = false,
        autoRenewalNoticeResource: LocalizedStringResource? = nil,
        autoRenewalNoticeText: String? = nil,
        productDisplayContents: [PaywallProductDisplayContent] = [],
        privacyPolicyURL: URL? = nil,
        termsOfServiceURL: URL? = nil
    ) {
        if let defaultProductIdentifier {
            precondition(
                catalog.productIdentifiers.contains(defaultProductIdentifier),
                "PaywallConfiguration의 기본 상품은 PurchaseCatalog에 포함되어야 합니다."
            )
        }

        self.catalog = catalog
        self.defaultProductIdentifier = defaultProductIdentifier
        self.showsUnavailablePurchaseOptions = showsUnavailablePurchaseOptions
        self.autoRenewalNoticeResource = autoRenewalNoticeResource
        self.autoRenewalNoticeText = autoRenewalNoticeText
        self.productDisplayContents = productDisplayContents
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfServiceURL = termsOfServiceURL
    }
}
