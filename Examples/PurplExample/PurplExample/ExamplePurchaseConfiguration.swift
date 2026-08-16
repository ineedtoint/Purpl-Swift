//
//  ExamplePurchaseConfiguration.swift
//  PurplExample
//
//  Created by Int on 8/17/26.
//

import Foundation
import Purpl
import PurplUI

/// 예제 앱 전체에서 사용하는 구매 구성
enum ExamplePurchaseConfiguration {
    /// 예제 앱 프리미엄 권한
    static let plusEntitlement = PurchaseEntitlement(
        identifier: "plus",
        titleResource: "Purpl Plus"
    )

    /// 월간 구독 상품
    static let monthlyProduct = PurchaseProduct(
        productIdentifier: "purpl.example.plus.monthly",
        entitlementIdentifier: plusEntitlement.identifier
    )

    /// 연간 구독 상품
    static let yearlyProduct = PurchaseProduct(
        productIdentifier: "purpl.example.plus.yearly",
        entitlementIdentifier: plusEntitlement.identifier
    )

    /// 평생 이용 상품
    static let lifetimeProduct = PurchaseProduct(
        productIdentifier: "purpl.example.plus.lifetime",
        entitlementIdentifier: plusEntitlement.identifier
    )

    /// 권한 확인과 구매 복원에 사용하는 전체 구매 구성
    static let `default` = PurchaseConfiguration(
        entitlements: [plusEntitlement],
        products: [
            monthlyProduct,
            yearlyProduct,
            lifetimeProduct
        ]
    )
}

/// 예제 앱 페이월 구성
enum ExamplePaywallConfiguration {
    /// 페이월에 표시할 상품과 순서
    private static let standardCatalog = PurchaseCatalog(
        identifier: "standard",
        products: [
            ExamplePurchaseConfiguration.monthlyProduct,
            ExamplePurchaseConfiguration.yearlyProduct,
            ExamplePurchaseConfiguration.lifetimeProduct
        ]
    )

    /// 연간 상품을 기본으로 선택하는 로컬 페이월 구성
    static let standard = PaywallConfiguration(
        catalog: standardCatalog,
        defaultProductIdentifier:
            ExamplePurchaseConfiguration.yearlyProduct.productIdentifier,
        autoRenewalNoticeResource: LocalizedStringResource(
            "Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period."
        )
    )
}
