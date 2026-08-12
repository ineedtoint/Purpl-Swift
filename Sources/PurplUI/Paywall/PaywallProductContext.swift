//
//  PaywallProductContext.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import Purpl
import StoreKit

/// 페이월 상품 사용 가능 상태
public enum PaywallProductAvailability: Equatable, Sendable {
    /// StoreKit 상품 확인 중
    case loading

    /// StoreKit 상품 사용 가능
    case available

    /// StoreKit 상품 사용 불가
    case unavailable
}

/// 사용자 정의 페이월 상품 콘텐츠에 전달하는 상태
public struct PaywallProductContext: Identifiable, Sendable {
    /// 구매 옵션 식별자
    public var id: String {
        catalogProduct.id
    }

    /// 앱에서 구성한 구매 상품
    public let catalogProduct: PurchaseProduct

    /// StoreKit에서 불러온 상품
    public let storeProduct: Product?

    /// 원격 페이월에서 해결한 선택 표시 제목
    public let displayTitle: String?

    /// 원격 페이월에서 해결한 선택 표시 설명
    public let displayDescription: String?

    /// 로컬 또는 원격 구성에서 상품 제목을 직접 지정했는지 여부
    var hasConfiguredTitle: Bool {
        displayTitle != nil || catalogProduct.titleResource != nil
    }

    /// StoreKit 상품 사용 가능 상태
    public let availability: PaywallProductAvailability

    /// 현재 선택 여부
    public let isSelected: Bool

    /// 현재 StoreKit 상품 보유 여부
    public let isOwned: Bool

    /// 연결된 구매 권한 활성 여부
    public let isEntitlementActive: Bool

    /// 같은 권한 상품의 구매 결과 확인 대기 상태
    public let purchaseResolutionState: PaywallPurchaseResolutionState?

    /// 사용자 정의 페이월 상품 상태 생성
    init(
        catalogProduct: PurchaseProduct,
        storeProduct: Product?,
        displayTitle: String? = nil,
        displayDescription: String? = nil,
        availability: PaywallProductAvailability,
        isSelected: Bool,
        isOwned: Bool,
        isEntitlementActive: Bool,
        purchaseResolutionState: PaywallPurchaseResolutionState?
    ) {
        self.catalogProduct = catalogProduct
        self.storeProduct = storeProduct
        self.displayTitle = displayTitle
        self.displayDescription = displayDescription
        self.availability = availability
        self.isSelected = isSelected
        self.isOwned = isOwned
        self.isEntitlementActive = isEntitlementActive
        self.purchaseResolutionState = purchaseResolutionState
    }
}

/// 페이월 상품 표시와 선택 정책
enum PaywallProductVisibilityPolicy {
    /// 화면에 표시할 구매 상품 목록 반환
    /// - Parameters:
    ///   - configuredProducts: 앱에서 구성한 전체 구매 상품 목록
    ///   - availableProductIdentifiers: StoreKit에서 불러온 상품 식별자 목록
    ///   - isLoadingProducts: StoreKit 상품 조회 진행 여부
    ///   - hasCompletedProductLoading: StoreKit 상품 조회 완료 경험 여부
    ///   - showsUnavailablePurchaseOptions: 사용할 수 없는 구매 옵션 표시 여부
    /// - Returns: 화면에 표시할 구매 상품 목록
    static func visibleProducts(
        configuredProducts: [PurchaseProduct],
        availableProductIdentifiers: Set<String>,
        isLoadingProducts: Bool,
        hasCompletedProductLoading: Bool,
        showsUnavailablePurchaseOptions: Bool
    ) -> [PurchaseProduct] {
        if isLoadingProducts || !hasCompletedProductLoading {
            return configuredProducts
        }

        if showsUnavailablePurchaseOptions {
            return configuredProducts
        }

        return configuredProducts.filter { catalogProduct in
            availableProductIdentifiers.contains(catalogProduct.productIdentifier)
        }
    }

    /// 사용 가능한 상품을 기준으로 선택할 구매 옵션 식별자 반환
    /// - Parameters:
    ///   - currentOptionIdentifier: 현재 선택된 구매 옵션 식별자
    ///   - configuredProducts: 앱에서 구성한 전체 구매 상품 목록
    ///   - availableProductIdentifiers: StoreKit에서 불러온 상품 식별자 목록
    /// - Returns: 유지하거나 새로 선택할 구매 옵션 식별자
    static func selectedOptionIdentifier(
        currentOptionIdentifier: String?,
        configuredProducts: [PurchaseProduct],
        availableProductIdentifiers: Set<String>
    ) -> String? {
        if let currentOptionIdentifier,
           let currentProduct = configuredProducts.first(where: { catalogProduct in
               catalogProduct.id == currentOptionIdentifier
           }),
           availableProductIdentifiers.contains(currentProduct.productIdentifier) {
            return currentOptionIdentifier
        }

        return configuredProducts.first(where: { catalogProduct in
            availableProductIdentifiers.contains(catalogProduct.productIdentifier)
        })?.id ?? currentOptionIdentifier
    }
}
