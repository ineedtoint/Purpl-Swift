//
//  PurchaseConfiguration.swift
//  Purpl
//
//  Created by Int on 8/11/26.
//

import Foundation

/// 앱 전체 상품과 권한 연결을 정의하는 구매 구성
public struct PurchaseConfiguration: Sendable {
    /// 앱에서 사용하는 구매 권한 목록
    public let entitlements: [PurchaseEntitlement]

    /// 권한 확인과 복원에 사용하는 전체 상품 목록
    public let products: [PurchaseProduct]

    /// 구성에 포함된 StoreKit 상품 식별자 목록
    public var productIdentifiers: [String] {
        products.map(\.productIdentifier)
    }

    /// 앱 구매 구성 생성
    /// - Parameters:
    ///   - entitlements: 상품에 선택적으로 연결할 구매 권한 목록
    ///   - products: 권한 확인과 복원에 사용하는 전체 구매 상품 목록
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

    /// 지정한 권한 식별자에 해당하는 권한 반환
    /// - Parameter entitlementIdentifier: 확인할 권한 식별자
    /// - Returns: 일치하는 권한
    public func entitlement(
        for entitlementIdentifier: String
    ) -> PurchaseEntitlement? {
        entitlements.first { entitlement in
            entitlement.identifier == entitlementIdentifier
        }
    }

    /// 지정한 상품 식별자에 해당하는 상품 반환
    /// - Parameter productIdentifier: 확인할 상품 식별자
    /// - Returns: 일치하는 구매 상품
    public func product(for productIdentifier: String?) -> PurchaseProduct? {
        guard let productIdentifier else {
            return nil
        }

        return products.first { product in
            product.productIdentifier == productIdentifier
        }
    }

    /// 지정한 StoreKit 상품 식별자에 해당하는 상품 반환
    /// - Parameter productIdentifier: 확인할 StoreKit 상품 식별자
    /// - Returns: 일치하는 구매 상품
    public func product(
        forStoreProductIdentifier productIdentifier: String
    ) -> PurchaseProduct? {
        product(for: productIdentifier)
    }
}
