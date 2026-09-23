//
//  RemotePaywallTests.swift
//  PurplTests
//
//  Created by Int on 8/11/26.
//

import Foundation
import Testing
@testable import Purpl

/// 원격 페이월 응답 해석 테스트
struct RemotePaywallResponseTests {
    /// 서버 권한 모드에서 원격 구매 구성과 카탈로그를 함께 사용하는지 확인
    @Test
    func serverModeUsesRemoteCatalog() throws {
        let remotePaywall = makeRemotePaywall()

        let configuration = try remotePaywall.resolvedConfiguration(
            paywallIdentifier: "standard",
            localPurchaseConfiguration: nil,
            entitlementMode: .server
        )

        #expect(configuration.paywallIdentifier == "standard")
        #expect(configuration.catalog.productIdentifiers == [
            "test.subscription.monthly",
            "test.subscription.yearly"
        ])
        #expect(
            configuration.purchaseConfiguration.product(
                for: "test.subscription.monthly"
            )?
                .entitlementIdentifiers == ["access"]
        )
        #expect(configuration.defaultProductIdentifier == "test.subscription.yearly")
        #expect(configuration.productContents.first?.title == "연간")
        #expect(configuration.autoRenewalNotice == "자동 갱신 안내")
        #expect(configuration.privacyPolicyURL?.absoluteString == "https://example.com/privacy")
        #expect(configuration.termsOfServiceURL.absoluteString == "https://example.com/terms")
    }

    /// 로컬에 없는 상품과 표시 내용을 제외하고 기본 선택을 변경하는지 확인
    @Test(arguments: [EntitlementMode.storeKit, .serverWithStoreKitFallback])
    func filtersUnknownRemoteProducts(entitlementMode: EntitlementMode) throws {
        let localPurchaseConfiguration = makeLocalPurchaseConfiguration(
            productIdentifiers: ["test.subscription.monthly"]
        )

        let configuration = try makeRemotePaywall().resolvedConfiguration(
            paywallIdentifier: "standard",
            localPurchaseConfiguration: localPurchaseConfiguration,
            entitlementMode: entitlementMode
        )

        #expect(configuration.catalog.productIdentifiers == ["test.subscription.monthly"])
        #expect(configuration.defaultProductIdentifier == "test.subscription.monthly")
        #expect(configuration.productContents.map(\.productIdentifier) == [
            "test.subscription.monthly"
        ])
        #expect(configuration.productContents.first?.title == "월간")
        #expect(configuration.productContents.first?.description == nil)
        #expect(configuration.autoRenewalNotice == "자동 갱신 안내")
        #expect(configuration.privacyPolicyURL?.absoluteString == "https://example.com/privacy")
        #expect(configuration.termsOfServiceURL.absoluteString == "https://example.com/terms")
    }

    /// 로컬 상품 순서와 무관하게 원격 순서와 유효한 기본 선택을 유지하는지 확인
    @Test(arguments: [EntitlementMode.storeKit, .serverWithStoreKitFallback])
    func preservesRemoteOrderAndLocalEntitlementMappings(
        entitlementMode: EntitlementMode
    ) throws {
        let localProductIdentifiers = [
            "test.subscription.monthly",
            "test.subscription.yearly",
            "test.subscription.legacy"
        ]
        let localPurchaseConfiguration = makeLocalPurchaseConfiguration(
            productIdentifiers: localProductIdentifiers
        )
        let remotePaywall = makeRemotePaywall(
            catalogProductIdentifiers: [
                "test.subscription.yearly",
                "test.subscription.lifetime",
                "test.subscription.monthly"
            ]
        )

        let configuration = try remotePaywall.resolvedConfiguration(
            paywallIdentifier: "standard",
            localPurchaseConfiguration: localPurchaseConfiguration,
            entitlementMode: entitlementMode
        )

        #expect(configuration.catalog.productIdentifiers == [
            "test.subscription.yearly",
            "test.subscription.monthly"
        ])
        #expect(configuration.defaultProductIdentifier == "test.subscription.yearly")
        #expect(configuration.purchaseConfiguration.productIdentifiers == localProductIdentifiers)
        #expect(
            configuration.purchaseConfiguration.product(for: "test.subscription.yearly")?
                .entitlementIdentifiers == ["local_access"]
        )
    }

    /// 원격에서 판매를 중단한 로컬 상품을 다시 추가하지 않는지 확인
    @Test(arguments: [EntitlementMode.storeKit, .serverWithStoreKitFallback])
    func preservesRemoteProductRemoval(entitlementMode: EntitlementMode) throws {
        let localPurchaseConfiguration = makeLocalPurchaseConfiguration(
            productIdentifiers: ["test.subscription.monthly", "test.subscription.yearly"]
        )
        let remotePaywall = makeRemotePaywall(
            catalogProductIdentifiers: ["test.subscription.yearly", "test.subscription.lifetime"],
            defaultProductIdentifier: "test.subscription.lifetime"
        )

        let configuration = try remotePaywall.resolvedConfiguration(
            paywallIdentifier: "standard",
            localPurchaseConfiguration: localPurchaseConfiguration,
            entitlementMode: entitlementMode
        )

        #expect(configuration.catalog.productIdentifiers == ["test.subscription.yearly"])
        #expect(configuration.defaultProductIdentifier == "test.subscription.yearly")
    }

    /// 기본 선택이 없는 원격 구성에서 상품을 제외해도 기본 선택을 만들지 않는지 확인
    @Test(arguments: [EntitlementMode.storeKit, .serverWithStoreKitFallback])
    func preservesMissingDefaultProduct(entitlementMode: EntitlementMode) throws {
        let configuration = try makeRemotePaywall(defaultProductIdentifier: nil)
            .resolvedConfiguration(
                paywallIdentifier: "standard",
                localPurchaseConfiguration: makeLocalPurchaseConfiguration(
                    productIdentifiers: ["test.subscription.monthly"]
                ),
                entitlementMode: entitlementMode
            )

        #expect(configuration.catalog.productIdentifiers == ["test.subscription.monthly"])
        #expect(configuration.defaultProductIdentifier == nil)
    }

    /// 로컬에서 처리할 상품이 없으면 기존 실패 복구 흐름으로 넘기는지 확인
    @Test(arguments: [EntitlementMode.storeKit, .serverWithStoreKitFallback])
    func rejectsCatalogWithoutRegisteredProducts(entitlementMode: EntitlementMode) {
        let localPurchaseConfiguration = makeLocalPurchaseConfiguration(
            productIdentifiers: ["test.subscription.legacy"]
        )

        #expect(throws: PurchasesError.invalidServerResponse) {
            try makeRemotePaywall().resolvedConfiguration(
                paywallIdentifier: "standard",
                localPurchaseConfiguration: localPurchaseConfiguration,
                entitlementMode: entitlementMode
            )
        }
    }

    /// 서버 권한 모드에서는 로컬 상품 목록으로 원격 상품을 제한하지 않는지 확인
    @Test
    func serverModeIgnoresLocalProductRestrictions() throws {
        let configuration = try makeRemotePaywall().resolvedConfiguration(
            paywallIdentifier: "standard",
            localPurchaseConfiguration: makeLocalPurchaseConfiguration(
                productIdentifiers: ["test.subscription.monthly"]
            ),
            entitlementMode: .server
        )

        #expect(configuration.catalog.productIdentifiers == [
            "test.subscription.monthly",
            "test.subscription.yearly"
        ])
        #expect(configuration.defaultProductIdentifier == "test.subscription.yearly")
        #expect(
            configuration.purchaseConfiguration.product(for: "test.subscription.yearly")?
                .entitlementIdentifiers == ["access"]
        )
    }

    /// 상품 제외 전에 잘못된 식별자와 참조 관계를 전체 거절하는지 확인
    @Test(arguments: [EntitlementMode.server, .storeKit, .serverWithStoreKitFallback])
    func rejectsInvalidReferencesBeforeFiltering(entitlementMode: EntitlementMode) {
        let localPurchaseConfiguration = makeLocalPurchaseConfiguration(
            productIdentifiers: ["test.subscription.monthly"]
        )
        let invalidResponses = [
            makeRemotePaywall(
                catalogProductIdentifiers: ["test.subscription.monthly", "unknown"]
            ),
            makeRemotePaywall(defaultProductIdentifier: "test.subscription.lifetime"),
            makeRemotePaywall(catalogProductIdentifiers: [
                "test.subscription.monthly",
                "test.subscription.monthly",
                "test.subscription.yearly"
            ])
        ]

        for remotePaywall in invalidResponses {
            #expect(throws: PurchasesError.invalidServerResponse) {
                try remotePaywall.resolvedConfiguration(
                    paywallIdentifier: "standard",
                    localPurchaseConfiguration: localPurchaseConfiguration,
                    entitlementMode: entitlementMode
                )
            }
        }

        #expect(throws: PurchasesError.invalidServerResponse) {
            try makeRemotePaywall().resolvedConfiguration(
                paywallIdentifier: "different",
                localPurchaseConfiguration: localPurchaseConfiguration,
                entitlementMode: entitlementMode
            )
        }
    }

    /// 잘못된 원격 권한 연결을 사전조건 실패 대신 서버 응답 오류로 처리하는지 확인
    @Test
    func rejectsUnknownEntitlementMapping() {
        let remotePaywall = RemotePaywallResponse(
            paywallConfiguration: RemotePaywallConfiguration(
                identifier: "standard",
                catalogIdentifier: "standard",
                defaultProductIdentifier: nil
            ),
            catalog: RemotePurchaseCatalog(
                identifier: "standard",
                productIdentifiers: ["test.subscription.monthly"]
            ),
            purchaseConfiguration: RemotePurchaseConfiguration(
                entitlements: [],
                products: [
                    RemotePurchaseProduct(
                        productIdentifier: "test.subscription.monthly",
                        entitlementIdentifiers: ["unknown"]
                    )
                ]
            ),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(throws: PurchasesError.invalidServerResponse) {
            try remotePaywall.resolvedConfiguration(
                paywallIdentifier: "standard",
                localPurchaseConfiguration: nil,
                entitlementMode: .server
            )
        }
    }

    /// 로컬 권한 연결을 별도로 지정한 테스트 구매 구성 생성
    private func makeLocalPurchaseConfiguration(
        productIdentifiers: [String]
    ) -> PurchaseConfiguration {
        PurchaseConfiguration(
            entitlements: [PurchaseEntitlement(identifier: "local_access")],
            products: productIdentifiers.map { productIdentifier in
                PurchaseProduct(
                    productIdentifier: productIdentifier,
                    entitlementIdentifier: "local_access"
                )
            }
        )
    }

    /// 테스트용 원격 페이월 응답 생성
    private func makeRemotePaywall(
        catalogProductIdentifiers: [String] = [
            "test.subscription.monthly",
            "test.subscription.yearly"
        ],
        defaultProductIdentifier: String? = "test.subscription.yearly"
    ) -> RemotePaywallResponse {
        RemotePaywallResponse(
            paywallConfiguration: RemotePaywallConfiguration(
                identifier: "standard",
                catalogIdentifier: "standard",
                defaultProductIdentifier: defaultProductIdentifier
            ),
            catalog: RemotePurchaseCatalog(
                identifier: "standard",
                productIdentifiers: catalogProductIdentifiers
            ),
            purchaseConfiguration: RemotePurchaseConfiguration(
                entitlements: [RemotePurchaseEntitlement(identifier: "access")],
                products: [
                    RemotePurchaseProduct(
                        productIdentifier: "test.subscription.monthly",
                        entitlementIdentifiers: ["access"]
                    ),
                    RemotePurchaseProduct(
                        productIdentifier: "test.subscription.yearly",
                        entitlementIdentifiers: ["access"]
                    ),
                    RemotePurchaseProduct(
                        productIdentifier: "test.subscription.lifetime",
                        entitlementIdentifiers: ["access"]
                    )
                ]
            ),
            localization: RemotePaywallLocalization(
                localeIdentifier: "ko",
                products: [
                    RemotePaywallProductContent(
                        productIdentifier: "test.subscription.yearly",
                        title: "연간",
                        description: "프리미엄 기능"
                    ),
                    RemotePaywallProductContent(
                        productIdentifier: "test.subscription.monthly",
                        title: "월간",
                        description: nil
                    )
                ],
                autoRenewalNotice: "자동 갱신 안내"
            ),
            policy: RemotePaywallPolicy(
                privacyPolicyURL: "https://example.com/privacy",
                termsOfServiceURL: "https://example.com/terms"
            ),
            updatedAt: Date(timeIntervalSince1970: 1_786_412_800)
        )
    }
}

/// 원격 페이월 디스크 캐시 테스트
struct RemotePaywallCacheTests {
    /// 저장한 원격 페이월 응답을 다시 읽고 제거할 수 있는지 확인
    @Test
    func savesLoadsAndRemovesConfiguration() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cache = RemotePaywallCache(directoryURL: directoryURL)
        let remotePaywall = RemotePaywallResponse(
            paywallConfiguration: RemotePaywallConfiguration(
                identifier: "standard",
                catalogIdentifier: "standard",
                defaultProductIdentifier: nil
            ),
            catalog: RemotePurchaseCatalog(
                identifier: "standard",
                productIdentifiers: ["test.subscription.monthly"]
            ),
            purchaseConfiguration: RemotePurchaseConfiguration(
                entitlements: [RemotePurchaseEntitlement(identifier: "access")],
                products: [
                    RemotePurchaseProduct(
                        productIdentifier: "test.subscription.monthly",
                        entitlementIdentifiers: ["access"]
                    )
                ]
            ),
            updatedAt: Date(timeIntervalSince1970: 1_786_412_800)
        )
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        try await cache.save(
            remotePaywall,
            paywallIdentifier: "standard",
            localeIdentifier: "ko"
        )
        let cachedPaywall = await cache.load(
            paywallIdentifier: "standard",
            localeIdentifier: "ko"
        )

        #expect(cachedPaywall?.paywallConfiguration.identifier == "standard")
        #expect(
            cachedPaywall?.purchaseConfiguration.products.first?
                .entitlementIdentifiers == ["access"]
        )
        #expect(await cache.load(
            paywallIdentifier: "standard",
            localeIdentifier: "en-US"
        ) == nil)

        await cache.remove(
            paywallIdentifier: "standard",
            localeIdentifier: "ko"
        )

        #expect(await cache.load(
            paywallIdentifier: "standard",
            localeIdentifier: "ko"
        ) == nil)
    }
}
