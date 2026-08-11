//
//  PurchaseConfigurationTests.swift
//  PurplTests
//
//  Created by Int on 7/28/26.
//

import Foundation
import Testing
@testable import Purpl

/// 앱 전체 구매 구성과 판매 카탈로그 테스트
struct PurchaseConfigurationTests {
    /// 별도 표시 문구 없이 StoreKit 상품 정보를 사용하도록 구성할 수 있는지 확인
    @Test
    func supportsStoreProductDisplayContent() throws {
        let purchaseConfiguration = PurchaseConfiguration(
            products: [
                PurchaseProduct(
                    productIdentifier: "test.subscription.monthly"
                )
            ]
        )

        let product = try #require(
            purchaseConfiguration.product(for: "test.subscription.monthly")
        )

        #expect(product.titleResource == nil)
        #expect(product.descriptionResource == nil)
    }

    /// 별도 앱 권한에 매핑하지 않는 상품을 구성할 수 있는지 확인
    @Test
    func supportsProductWithoutEntitlement() throws {
        let product = PurchaseProduct(
            productIdentifier: "test.theme.midnight",
            titleResource: LocalizedStringResource(
                "test.theme.title",
                defaultValue: "Midnight Theme"
            )
        )
        let purchaseConfiguration = PurchaseConfiguration(products: [product])

        let configuredProduct = try #require(
            purchaseConfiguration.product(for: "test.theme.midnight")
        )

        #expect(configuredProduct.entitlementIdentifiers.isEmpty)
        #expect(configuredProduct.descriptionResource == nil)
        #expect(configuredProduct.id == "test.theme.midnight")
        #expect(purchaseConfiguration.entitlements.isEmpty)
        #expect(purchaseConfiguration.productIdentifiers == ["test.theme.midnight"])
    }

    /// 등록된 권한과 연결한 상품을 구성할 수 있는지 확인
    @Test
    func supportsProductWithEntitlement() throws {
        let purchaseConfiguration = PurchaseConfiguration(
            entitlements: [
                PurchaseEntitlement(
                    identifier: "access",
                    titleResource: LocalizedStringResource(
                        "test.access.title",
                        defaultValue: "Access"
                    )
                )
            ],
            products: [
                PurchaseProduct(
                    productIdentifier: "test.subscription.yearly",
                    entitlementIdentifier: "access",
                    titleResource: LocalizedStringResource(
                        "test.yearly.title",
                        defaultValue: "Yearly"
                    ),
                    descriptionResource: LocalizedStringResource(
                        "test.yearly.description",
                        defaultValue: "Renews yearly"
                    )
                )
            ]
        )

        let product = try #require(
            purchaseConfiguration.product(for: "test.subscription.yearly")
        )

        #expect(product.productIdentifier == "test.subscription.yearly")
        #expect(product.entitlementIdentifiers == ["access"])
        #expect(product.descriptionResource != nil)
        #expect(purchaseConfiguration.entitlements.first?.id == "access")
        #expect(purchaseConfiguration.entitlements.map(\.identifier) == ["access"])
    }

    /// 하나의 상품이 여러 권한을 지급할 수 있는지 확인
    @Test
    func supportsProductWithMultipleEntitlements() throws {
        let purchaseConfiguration = PurchaseConfiguration(
            entitlements: [
                PurchaseEntitlement(identifier: "access"),
                PurchaseEntitlement(identifier: "themes")
            ],
            products: [
                PurchaseProduct(
                    productIdentifier: "test.lifetime",
                    entitlementIdentifiers: ["access", "themes"]
                )
            ]
        )

        let product = try #require(
            purchaseConfiguration.product(for: "test.lifetime")
        )

        #expect(product.entitlementIdentifiers == ["access", "themes"])
    }

    /// 판매 카탈로그가 앱 전체 구매 구성과 독립적으로 표시 순서를 유지하는지 확인
    @Test
    func catalogKeepsPaywallOrder() {
        let monthlyProduct = PurchaseProduct(productIdentifier: "test.monthly")
        let yearlyProduct = PurchaseProduct(productIdentifier: "test.yearly")
        let purchaseConfiguration = PurchaseConfiguration(
            products: [monthlyProduct, yearlyProduct]
        )
        let catalog = PurchaseCatalog(
            identifier: "standard",
            products: [yearlyProduct, monthlyProduct]
        )

        #expect(catalog.productIdentifiers == ["test.yearly", "test.monthly"])
        #expect(catalog.products(in: purchaseConfiguration).map(\.productIdentifier) == [
            "test.yearly",
            "test.monthly"
        ])
    }
}
