//
//  RemotePaywallResponse.swift
//  Purpl
//
//  Created by Int on 8/11/26.
//

import Foundation

/// 서버와 로컬 캐시가 공유하는 원격 페이월 응답
struct RemotePaywallResponse: Codable, Sendable {
    /// 원격 페이월 구성
    let paywallConfiguration: RemotePaywallConfiguration

    /// 원격 구매 카탈로그
    let catalog: RemotePurchaseCatalog

    /// 원격 앱 전체 구매 구성
    let purchaseConfiguration: RemotePurchaseConfiguration

    /// 요청 로케일에 맞게 해결한 표시 내용
    let localization: RemotePaywallLocalization

    /// Apple 페이월 정책
    let policy: RemotePaywallPolicy

    /// 원격 구성의 마지막 수정 시각
    let updatedAt: Date

    /// 서버와 캐시가 공유하는 원격 페이월 응답 생성
    init(
        paywallConfiguration: RemotePaywallConfiguration,
        catalog: RemotePurchaseCatalog,
        purchaseConfiguration: RemotePurchaseConfiguration,
        localization: RemotePaywallLocalization = RemotePaywallLocalization(
            localeIdentifier: "en-US",
            products: [],
            autoRenewalNotice: nil
        ),
        policy: RemotePaywallPolicy = RemotePaywallPolicy(
            privacyPolicyURL: nil,
            termsOfServiceURL:
                "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        ),
        updatedAt: Date
    ) {
        self.paywallConfiguration = paywallConfiguration
        self.catalog = catalog
        self.purchaseConfiguration = purchaseConfiguration
        self.localization = localization
        self.policy = policy
        self.updatedAt = updatedAt
    }

    /// 현재 권한 확인 방식에 맞는 공개 페이월 구성으로 변환
    /// - Parameters:
    ///   - paywallIdentifier: 요청한 페이월 구성 식별자
    ///   - localPurchaseConfiguration: 앱에서 등록한 전체 구매 구성
    ///   - entitlementMode: 고객 권한 확인 방식
    /// - Returns: 앱에서 사용할 해석된 페이월 구성
    func resolvedConfiguration(
        paywallIdentifier: String,
        localPurchaseConfiguration: PurchaseConfiguration?,
        entitlementMode: EntitlementMode
    ) throws -> ResolvedPaywallConfiguration {
        try validate(paywallIdentifier: paywallIdentifier)

        let remotePurchaseConfiguration = PurchaseConfiguration(
            entitlements: purchaseConfiguration.entitlements.map { entitlement in
                PurchaseEntitlement(identifier: entitlement.identifier)
            },
            products: purchaseConfiguration.products.map { product in
                PurchaseProduct(
                    productIdentifier: product.productIdentifier,
                    entitlementIdentifiers: Set(product.entitlementIdentifiers)
                )
            }
        )
        let catalog = PurchaseCatalog(
            identifier: catalog.identifier,
            productIdentifiers: catalog.productIdentifiers
        )
        let resolvedPurchaseConfiguration: PurchaseConfiguration

        switch entitlementMode {
        case .server:
            resolvedPurchaseConfiguration = remotePurchaseConfiguration
        case .serverWithStoreKitFallback, .storeKit:
            guard let localPurchaseConfiguration else {
                throw PurchasesError.missingPurchaseConfiguration
            }

            let localProductIdentifiers = Set(
                localPurchaseConfiguration.productIdentifiers
            )

            guard Set(catalog.productIdentifiers).isSubset(
                of: localProductIdentifiers
            ) else {
                throw PurchasesError.invalidServerResponse
            }

            resolvedPurchaseConfiguration = localPurchaseConfiguration
        }

        return ResolvedPaywallConfiguration(
            paywallIdentifier: paywallConfiguration.identifier,
            purchaseConfiguration: resolvedPurchaseConfiguration,
            catalog: catalog,
            defaultProductIdentifier:
                paywallConfiguration.defaultProductIdentifier,
            productContents: localization.products.map { product in
                ResolvedPaywallProductContent(
                    productIdentifier: product.productIdentifier,
                    title: product.title,
                    description: product.description
                )
            },
            autoRenewalNotice: localization.autoRenewalNotice,
            privacyPolicyURL: try policy.privacyPolicyURL.map { value in
                try value.validatedURL()
            },
            termsOfServiceURL: try policy.termsOfServiceURL.validatedURL(),
            updatedAt: updatedAt
        )
    }

    /// 원격 페이월 응답의 식별자와 참조 관계 검증
    /// - Parameter paywallIdentifier: 요청한 페이월 구성 식별자
    private func validate(paywallIdentifier: String) throws {
        let entitlementIdentifiers = purchaseConfiguration.entitlements.map(
            \.identifier
        )
        let productIdentifiers = purchaseConfiguration.products.map(
            \.productIdentifier
        )
        let knownEntitlementIdentifiers = Set(entitlementIdentifiers)
        let knownProductIdentifiers = Set(productIdentifiers)
        let catalogProductIdentifiers = catalog.productIdentifiers

        guard
            paywallConfiguration.identifier == paywallIdentifier,
            paywallConfiguration.catalogIdentifier == catalog.identifier,
            paywallConfiguration.identifier.isEmpty == false,
            catalog.identifier.isEmpty == false,
            entitlementIdentifiers.allSatisfy({ $0.isEmpty == false }),
            productIdentifiers.allSatisfy({ $0.isEmpty == false }),
            catalogProductIdentifiers.allSatisfy({ $0.isEmpty == false }),
            Set(entitlementIdentifiers).count == entitlementIdentifiers.count,
            knownProductIdentifiers.count == productIdentifiers.count,
            Set(catalogProductIdentifiers).count
                == catalogProductIdentifiers.count,
            Set(catalogProductIdentifiers).isSubset(
                of: knownProductIdentifiers
            ),
            purchaseConfiguration.products.allSatisfy({ product in
                Set(product.entitlementIdentifiers).count
                    == product.entitlementIdentifiers.count
                    && Set(product.entitlementIdentifiers).isSubset(
                        of: knownEntitlementIdentifiers
                    )
            })
        else {
            throw PurchasesError.invalidServerResponse
        }

        if let defaultProductIdentifier =
            paywallConfiguration.defaultProductIdentifier {
            guard catalogProductIdentifiers.contains(
                defaultProductIdentifier
            ) else {
                throw PurchasesError.invalidServerResponse
            }
        }
    }
}

/// 서버와 캐시가 공유하는 해결된 페이월 현지화
struct RemotePaywallLocalization: Codable, Sendable {
    /// 실제 선택된 로케일 식별자
    let localeIdentifier: String

    /// 상품별 표시 내용
    let products: [RemotePaywallProductContent]

    /// Apple 자동 갱신 안내 문구
    let autoRenewalNotice: String?
}

/// 서버와 캐시가 공유하는 해결된 상품 표시 내용
struct RemotePaywallProductContent: Codable, Sendable {
    /// StoreKit 상품 식별자
    let productIdentifier: String

    /// 선택 표시 제목
    let title: String?

    /// 선택 표시 설명
    let description: String?
}

/// 서버와 캐시가 공유하는 Apple 페이월 정책
struct RemotePaywallPolicy: Codable, Sendable {
    /// 개인정보 처리방침 주소 문자열
    let privacyPolicyURL: String?

    /// 서비스 약관 주소 문자열
    let termsOfServiceURL: String
}

private extension String {
    /// 원격 구성의 필수 HTTPS 주소 검증
    func validatedURL() throws -> URL {
        guard let url = URL(string: self), url.scheme == "https" else {
            throw PurchasesError.invalidServerResponse
        }

        return url
    }
}

/// 서버와 캐시가 공유하는 원격 페이월 구성
struct RemotePaywallConfiguration: Codable, Sendable {
    /// 페이월 구성 식별자
    let identifier: String

    /// 연결한 구매 카탈로그 식별자
    let catalogIdentifier: String

    /// 선택 기본 상품 식별자
    let defaultProductIdentifier: String?
}

/// 서버와 캐시가 공유하는 원격 구매 카탈로그
struct RemotePurchaseCatalog: Codable, Sendable {
    /// 구매 카탈로그 식별자
    let identifier: String

    /// 표시 순서대로 정렬한 상품 식별자
    let productIdentifiers: [String]
}

/// 서버와 캐시가 공유하는 원격 앱 전체 구매 구성
struct RemotePurchaseConfiguration: Codable, Sendable {
    /// 권한 정의 목록
    let entitlements: [RemotePurchaseEntitlement]

    /// 상품 정의 목록
    let products: [RemotePurchaseProduct]
}

/// 서버와 캐시가 공유하는 원격 권한 정의
struct RemotePurchaseEntitlement: Codable, Sendable {
    /// 권한 식별자
    let identifier: String
}

/// 서버와 캐시가 공유하는 원격 상품 정의
struct RemotePurchaseProduct: Codable, Sendable {
    /// 스토어 상품 식별자
    let productIdentifier: String

    /// 상품이 지급하는 권한 식별자 목록
    let entitlementIdentifiers: [String]
}
