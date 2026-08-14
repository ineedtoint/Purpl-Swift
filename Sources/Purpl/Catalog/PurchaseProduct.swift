//
//  PurchaseProduct.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

// 앱에서 판매하는 구매 상품 구성
/// A purchase product configuration sold by the app.
public struct PurchaseProduct: Identifiable, Sendable {
    // App Store Connect에 등록한 StoreKit 상품 식별자
    /// The StoreKit product identifier registered in App Store Connect.
    public let productIdentifier: String

    // 목록 식별자
    /// The identifier used for identifiable collections.
    public var id: String {
        productIdentifier
    }

    // 구매 후 활성화되는 권한 식별자 목록
    /// The entitlement identifiers activated by the purchase.
    ///
    /// Use an empty set for a product that doesn't map to an app entitlement.
    public let entitlementIdentifiers: Set<String>

    // 상품 표시 제목
    /// The localized display title for the product.
    ///
    /// When this value is `nil`, the default paywall uses the StoreKit product title and description.
    public let titleResource: LocalizedStringResource?

    // 상품 표시 설명
    /// The localized display description for the product.
    ///
    /// Use `nil` when the app provides a custom title but doesn't want to display a description.
    public let descriptionResource: LocalizedStringResource?

    // 구매 상품 생성
    /// Creates a purchase product.
    public init(
        productIdentifier: String,
        entitlementIdentifiers: Set<String> = [],
        titleResource: LocalizedStringResource? = nil,
        descriptionResource: LocalizedStringResource? = nil
    ) {
        precondition(
            productIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            "PurchaseProduct의 상품 식별자는 비어 있을 수 없습니다."
        )
        precondition(
            entitlementIdentifiers.allSatisfy { entitlementIdentifier in
                entitlementIdentifier.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty == false
            },
            "PurchaseProduct의 권한 식별자는 비어 있을 수 없습니다."
        )

        self.productIdentifier = productIdentifier
        self.entitlementIdentifiers = entitlementIdentifiers
        self.titleResource = titleResource
        self.descriptionResource = descriptionResource
    }

    // 하나의 권한을 지급하는 구매 상품 생성
    /// Creates a purchase product that grants one entitlement.
    public init(
        productIdentifier: String,
        entitlementIdentifier: String,
        titleResource: LocalizedStringResource? = nil,
        descriptionResource: LocalizedStringResource? = nil
    ) {
        self.init(
            productIdentifier: productIdentifier,
            entitlementIdentifiers: [entitlementIdentifier],
            titleResource: titleResource,
            descriptionResource: descriptionResource
        )
    }
}
