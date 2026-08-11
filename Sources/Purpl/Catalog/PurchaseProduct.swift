//
//  PurchaseProduct.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

/// 앱에서 판매하는 구매 상품 구성
public struct PurchaseProduct: Identifiable, Sendable {
    /// App Store Connect에 등록한 StoreKit 상품 식별자
    public let productIdentifier: String

    /// 목록 식별자
    public var id: String {
        productIdentifier
    }

    /// 구매 후 활성화되는 권한 식별자 목록
    ///
    /// 별도 앱 권한에 매핑하지 않는 상품은 빈 집합을 사용한다.
    public let entitlementIdentifiers: Set<String>

    /// 상품 표시 제목
    ///
    /// `nil`이면 기본 페이월에서 StoreKit 상품의 제목과 설명을 사용한다.
    public let titleResource: LocalizedStringResource?

    /// 상품 표시 설명
    ///
    /// 앱에서 상품 제목을 직접 지정하면서 설명을 표시하지 않을 때는 `nil`을 사용한다.
    public let descriptionResource: LocalizedStringResource?

    /// 구매 상품 생성
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

    /// 하나의 권한을 지급하는 구매 상품 생성
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
