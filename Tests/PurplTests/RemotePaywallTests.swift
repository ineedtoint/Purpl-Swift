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

    /// StoreKit 권한 모드에서 로컬 카탈로그에 없는 원격 상품을 거부하는지 확인
    @Test
    func storeKitModeRejectsUnknownRemoteProduct() {
        let localPurchaseConfiguration = PurchaseConfiguration(
            entitlements: [PurchaseEntitlement(identifier: "access")],
            products: [
                PurchaseProduct(
                    productIdentifier: "test.subscription.monthly",
                    entitlementIdentifier: "access"
                )
            ]
        )

        #expect(throws: PurchasesError.invalidServerResponse) {
            try makeRemotePaywall().resolvedConfiguration(
                paywallIdentifier: "standard",
                localPurchaseConfiguration: localPurchaseConfiguration,
                entitlementMode: .storeKit
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

    /// 테스트용 원격 페이월 응답 생성
    private func makeRemotePaywall() -> RemotePaywallResponse {
        RemotePaywallResponse(
            paywallConfiguration: RemotePaywallConfiguration(
                identifier: "standard",
                catalogIdentifier: "standard",
                defaultProductIdentifier: "test.subscription.yearly"
            ),
            catalog: RemotePurchaseCatalog(
                identifier: "standard",
                productIdentifiers: [
                    "test.subscription.monthly",
                    "test.subscription.yearly"
                ]
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
