//
//  PurchaseConfiguration.swift
//  Purpl
//
//  Created by Int on 8/11/26.
//

import Foundation

// 앱 전체 상품과 권한 연결을 정의하는 구매 구성
/// A purchase configuration that defines all app products and entitlement mappings.
public struct PurchaseConfiguration: Sendable {
    // 앱에서 사용하는 구매 권한 목록
    /// The purchase entitlements used by the app.
    public let entitlements: [PurchaseEntitlement]

    // 권한 확인과 복원에 사용하는 전체 상품 목록
    /// All products used for entitlement checks and purchase restoration.
    public let products: [PurchaseProduct]

    // 구성에 포함된 StoreKit 상품 식별자 목록
    /// The StoreKit product identifiers included in the configuration.
    public var productIdentifiers: [String] {
        products.map(\.productIdentifier)
    }

    // 앱 구매 구성 생성
    /// Creates an app purchase configuration.
    /// - Parameters:
    ///   - entitlements: The purchase entitlements that products can optionally grant.
    ///   - products: All purchase products used for entitlement checks and restoration.
    public init(
        entitlements: [PurchaseEntitlement] = [],
        products: [PurchaseProduct]
    ) {
        let entitlementIdentifiers = entitlements.map(\.identifier)
        let productIdentifiers = products.map(\.productIdentifier)
        let knownEntitlementIdentifiers = Set(entitlementIdentifiers)

        precondition(
            Set(entitlementIdentifiers).count == entitlementIdentifiers.count,
            "PurchaseConfiguration의 권한 식별자는 중복될 수 없습니다."
        )
        precondition(
            Set(productIdentifiers).count == productIdentifiers.count,
            "PurchaseConfiguration의 StoreKit 상품 식별자는 중복될 수 없습니다."
        )
        precondition(
            products.allSatisfy { product in
                product.entitlementIdentifiers.isSubset(
                    of: knownEntitlementIdentifiers
                )
            },
            "PurchaseConfiguration의 상품 권한은 등록된 권한과 연결되어야 합니다."
        )

        self.entitlements = entitlements
        self.products = products
    }

    // 지정한 권한 식별자에 해당하는 권한 반환
    /// Returns the entitlement with the specified identifier.
    /// - Parameter entitlementIdentifier: The entitlement identifier to find.
    /// - Returns: The matching entitlement, if one exists.
    public func entitlement(
        for entitlementIdentifier: String
    ) -> PurchaseEntitlement? {
        entitlements.first { entitlement in
            entitlement.identifier == entitlementIdentifier
        }
    }

    // 지정한 상품 식별자에 해당하는 상품 반환
    /// Returns the product with the specified identifier.
    /// - Parameter productIdentifier: The product identifier to find.
    /// - Returns: The matching purchase product, if one exists.
    public func product(for productIdentifier: String?) -> PurchaseProduct? {
        guard let productIdentifier else {
            return nil
        }

        return products.first { product in
            product.productIdentifier == productIdentifier
        }
    }

    // 지정한 StoreKit 상품 식별자에 해당하는 상품 반환
    /// Returns the product with the specified StoreKit product identifier.
    /// - Parameter productIdentifier: The StoreKit product identifier to find.
    /// - Returns: The matching purchase product, if one exists.
    public func product(
        forStoreProductIdentifier productIdentifier: String
    ) -> PurchaseProduct? {
        product(for: productIdentifier)
    }
}
