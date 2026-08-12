//
//  PaywallProductVisibilityTests.swift
//  PurplUITests
//
//  Created by Int on 7/28/26.
//

import Foundation
import Purpl
import Testing
@testable import PurplUI

/// 페이월 상품 표시와 선택 정책 테스트
struct PaywallProductVisibilityTests {
    /// 최초 상품 조회 전에는 모든 구매 옵션을 유지하는지 확인
    @Test
    func showsAllProductsBeforeLoadingCompletes() {
        let configuredProducts = makePurchaseProducts()

        let visibleProducts = PaywallProductVisibilityPolicy.visibleProducts(
            configuredProducts: configuredProducts,
            availableProductIdentifiers: [],
            isLoadingProducts: false,
            hasCompletedProductLoading: false,
            showsUnavailablePurchaseOptions: false
        )

        #expect(visibleProducts.map(\.id) == [
            "test.product.monthly",
            "test.product.yearly"
        ])
    }

    /// 상품 조회 중에는 모든 구매 옵션을 유지하는지 확인
    @Test
    func showsAllProductsWhileLoading() {
        let configuredProducts = makePurchaseProducts()

        let visibleProducts = PaywallProductVisibilityPolicy.visibleProducts(
            configuredProducts: configuredProducts,
            availableProductIdentifiers: [],
            isLoadingProducts: true,
            hasCompletedProductLoading: true,
            showsUnavailablePurchaseOptions: false
        )

        #expect(visibleProducts.map(\.id) == [
            "test.product.monthly",
            "test.product.yearly"
        ])
    }

    /// 사용할 수 없는 옵션 표시 설정이 켜져 있으면 모든 상품을 유지하는지 확인
    @Test
    func showsUnavailableProductsWhenConfigured() {
        let configuredProducts = makePurchaseProducts()

        let visibleProducts = PaywallProductVisibilityPolicy.visibleProducts(
            configuredProducts: configuredProducts,
            availableProductIdentifiers: ["test.product.yearly"],
            isLoadingProducts: false,
            hasCompletedProductLoading: true,
            showsUnavailablePurchaseOptions: true
        )

        #expect(visibleProducts.map(\.id) == [
            "test.product.monthly",
            "test.product.yearly"
        ])
    }

    /// 상품 조회 후 사용할 수 있는 구매 옵션만 표시하는지 확인
    @Test
    func hidesUnavailableProductsAfterLoading() {
        let configuredProducts = makePurchaseProducts()

        let visibleProducts = PaywallProductVisibilityPolicy.visibleProducts(
            configuredProducts: configuredProducts,
            availableProductIdentifiers: ["test.product.yearly"],
            isLoadingProducts: false,
            hasCompletedProductLoading: true,
            showsUnavailablePurchaseOptions: false
        )

        #expect(visibleProducts.map(\.id) == ["test.product.yearly"])
    }

    /// 원격 제목만 지정한 상품을 사용자 지정 제목 구성으로 인식하는지 확인
    @Test
    func recognizesRemoteTitleAsConfiguredTitle() {
        let context = PaywallProductContext(
            catalogProduct: PurchaseProduct(
                productIdentifier: "test.product.monthly"
            ),
            storeProduct: nil,
            displayTitle: "Monthly",
            displayDescription: nil,
            availability: .unavailable,
            isSelected: false,
            isOwned: false,
            isEntitlementActive: false,
            purchaseResolutionState: nil
        )

        #expect(context.hasConfiguredTitle)
    }

    /// 현재 선택 상품을 사용할 수 없으면 첫 사용 가능 상품을 선택하는지 확인
    @Test
    func selectsFirstAvailableProduct() {
        let configuredProducts = makePurchaseProducts()

        let selectedOptionIdentifier =
            PaywallProductVisibilityPolicy.selectedOptionIdentifier(
                currentOptionIdentifier: "test.product.monthly",
                configuredProducts: configuredProducts,
                availableProductIdentifiers: ["test.product.yearly"]
            )

        #expect(selectedOptionIdentifier == "test.product.yearly")
    }

    /// 현재 선택 상품을 사용할 수 있으면 선택을 유지하는지 확인
    @Test
    func keepsAvailableSelectedProduct() {
        let configuredProducts = makePurchaseProducts()

        let selectedOptionIdentifier =
            PaywallProductVisibilityPolicy.selectedOptionIdentifier(
                currentOptionIdentifier: "test.product.monthly",
                configuredProducts: configuredProducts,
                availableProductIdentifiers: [
                    "test.product.monthly",
                    "test.product.yearly"
                ]
            )

        #expect(selectedOptionIdentifier == "test.product.monthly")
    }

    /// 테스트용 구매 상품 목록 생성
    /// - Returns: 월간과 연간 구매 상품 목록
    private func makePurchaseProducts() -> [PurchaseProduct] {
        [
            makePurchaseProduct(productIdentifier: "test.product.monthly"),
            makePurchaseProduct(productIdentifier: "test.product.yearly")
        ]
    }

    /// 테스트용 구매 상품 생성
    /// - Parameter productIdentifier: StoreKit 상품 식별자
    /// - Returns: 테스트용 구매 상품
    private func makePurchaseProduct(
        productIdentifier: String
    ) -> PurchaseProduct {
        PurchaseProduct(
            productIdentifier: productIdentifier,
            entitlementIdentifier: "access",
            titleResource: LocalizedStringResource(
                "test.product.title",
                defaultValue: "Product"
            ),
            descriptionResource: LocalizedStringResource(
                "test.product.description",
                defaultValue: "Product description"
            )
        )
    }
}
