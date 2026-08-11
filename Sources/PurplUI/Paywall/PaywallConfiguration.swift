//
//  PaywallConfiguration.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import Foundation
import Purpl

/// 페이월 구성
public struct PaywallConfiguration: Sendable {
    /// 페이월에서 사용할 구매 카탈로그
    public let catalog: PurchaseCatalog

    /// 기본 선택 구매 옵션 식별자
    public let defaultProductIdentifier: String?

    /// StoreKit 상품 정보를 불러오지 못한 구매 옵션 표시 여부
    public let showsUnavailablePurchaseOptions: Bool

    /// 자동 갱신 안내 문구
    public let autoRenewalNoticeResource: LocalizedStringResource?

    /// 개인정보 처리방침 주소
    public let privacyPolicyURL: URL?

    /// 서비스 약관 주소
    public let termsOfServiceURL: URL?

    /// 페이월 구성 생성
    public init(
        catalog: PurchaseCatalog,
        defaultProductIdentifier: String? = nil,
        showsUnavailablePurchaseOptions: Bool = false,
        autoRenewalNoticeResource: LocalizedStringResource? = nil,
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
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfServiceURL = termsOfServiceURL
    }
}
