//
//  PurchaseCatalog.swift
//  Purpl
//
//  Created by Int on 8/11/26.
//

import Foundation

/// 함께 판매할 상품과 표시 순서를 정의하는 구매 카탈로그
public struct PurchaseCatalog: Identifiable, Sendable {
    /// 구매 카탈로그 식별자
    public let identifier: String

    /// 카탈로그 식별자
    public var id: String {
        identifier
    }

    /// 표시 순서대로 정렬한 StoreKit 상품 식별자 목록
    public let productIdentifiers: [String]

    /// 상품 식별자로 구매 카탈로그 생성
    public init(
        identifier: String,
        productIdentifiers: [String]
    ) {
        precondition(
            identifier.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty == false,
            "PurchaseCatalog의 식별자는 비어 있을 수 없습니다."
        )
        precondition(
            productIdentifiers.allSatisfy { productIdentifier in
                productIdentifier.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty == false
            },
            "PurchaseCatalog의 상품 식별자는 비어 있을 수 없습니다."
        )
        precondition(
            Set(productIdentifiers).count == productIdentifiers.count,
            "PurchaseCatalog의 상품 식별자는 중복될 수 없습니다."
        )

        self.identifier = identifier
        self.productIdentifiers = productIdentifiers
    }

    /// 구매 상품으로 구매 카탈로그 생성
    public init(
        identifier: String,
        products: [PurchaseProduct]
    ) {
        self.init(
            identifier: identifier,
            productIdentifiers: products.map(\.productIdentifier)
        )
    }

    /// 전체 구매 구성에서 카탈로그 순서에 맞는 상품 조회
    /// - Parameter configuration: 앱 전체 구매 구성
    /// - Returns: 카탈로그에 포함된 구매 상품 목록
    public func products(
        in configuration: PurchaseConfiguration
    ) -> [PurchaseProduct] {
        productIdentifiers.compactMap { productIdentifier in
            configuration.product(for: productIdentifier)
        }
    }
}
