//
//  Purchases.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

// MARK: - 사용법

// 앱 실행 중 configure를 한 번 호출한 후 나머지 API를 사용한다.
// - configure: 공유 인스턴스 구성과 StoreKit 거래 변경 감시 시작
// - customerInfo: 현재 고객 정보 일회성 조회
// - customerInfoStream: 발행된 고객 정보와 이후 변경 구독
// - customerInfoTask: SwiftUI에서 최초 고객 정보 조회와 이후 변경 구독

import Foundation
import StoreKit
import Synchronization

// Purpl 공개 진입점
/// The primary entry point for Purpl purchase and entitlement operations.
public final class Purchases: Sendable {
    /// 구성한 공유 인스턴스 저장소
    private static let sharedStorage = Mutex<Purchases?>(nil)

    // 구성한 Purpl 공유 인스턴스
    /// The configured shared Purpl instance.
    public static var shared: Purchases {
        sharedStorage.withLock { purchases in
            guard let purchases else {
                preconditionFailure("Purchases.configure를 먼저 호출해야 합니다.")
            }

            return purchases
        }
    }

    /// StoreKit과 Purchases 서버 작업을 조율하는 내부 코디네이터
    private let coordinator: PurchasesCoordinator

    // 앱 전체 구매 구성
    /// The app-wide purchase configuration.
    public let purchaseConfiguration: PurchaseConfiguration?

    /// 고객 권한 확인 방식
    private let entitlementMode: EntitlementMode

    /// 원격 구매 구성 캐시
    private let remotePaywallCache: RemotePaywallCache

    /// 고객 정보 스트림 발행기
    private let customerInfoPublisher: CustomerInfoStreamPublisher

    // 최신 고객 정보와 이후 변경 정보를 전달하는 스트림
    /// A stream that delivers the latest customer information and subsequent updates.
    public var customerInfoStream: AsyncStream<CustomerInfo> {
        customerInfoPublisher.makeStream()
    }

    /// 마지막으로 전달한 고객 정보
    var latestCustomerInfo: CustomerInfo? {
        customerInfoPublisher.latestCustomerInfo
    }

    // 로컬 구매 구성으로 StoreKit 권한 확인과 거래 변경 감시 시작
    /// Configures local StoreKit entitlement resolution and starts observing transaction updates.
    /// - Parameter purchaseConfiguration: The app-wide purchase configuration used for product loading and entitlement checks.
    /// - Returns: The configured shared Purpl instance.
    @discardableResult
    public static func configure(
        _ purchaseConfiguration: PurchaseConfiguration
    ) -> Purchases {
        configure(
            purchaseConfiguration,
            entitlementMode: .storeKit
        )
    }

    // Purpl 구성과 StoreKit 거래 변경 감시 시작
    /// Configures Purpl and starts observing StoreKit transaction updates.
    /// - Parameters:
    ///   - purchaseConfiguration: The app-wide purchase configuration used for product loading and StoreKit entitlement checks.
    ///   - entitlementMode: The method used to resolve customer entitlements.
    /// - Returns: The configured shared Purpl instance.
    @discardableResult
    public static func configure(
        _ purchaseConfiguration: PurchaseConfiguration? = nil,
        entitlementMode: EntitlementMode
    ) -> Purchases {
        if entitlementMode != .server {
            precondition(
                purchaseConfiguration != nil,
                "StoreKit 권한을 사용하려면 PurchaseConfiguration이 필요합니다."
            )
        }

        let purchases = Purchases(configuration: PurchasesConfiguration(
            purchaseConfiguration: purchaseConfiguration,
            entitlementMode: entitlementMode
        ))

        sharedStorage.withLock { configuredPurchases in
            precondition(
                configuredPurchases == nil,
                "Purchases.configure는 앱 실행 중 한 번만 호출할 수 있습니다."
            )
            configuredPurchases = purchases
        }

        purchases.start()
        return purchases
    }

    /// Purpl 공개 진입점 생성
    init(configuration: PurchasesConfiguration) {
        let customerInfoPublisher = CustomerInfoStreamPublisher()

        purchaseConfiguration = configuration.purchaseConfiguration
        entitlementMode = configuration.entitlementMode
        remotePaywallCache = RemotePaywallCache()
        self.customerInfoPublisher = customerInfoPublisher
        coordinator = PurchasesCoordinator(
            configuration: configuration,
            customerInfoPublisher: customerInfoPublisher
        )
    }

    // StoreKit 상품 목록 조회
    /// Loads StoreKit products with the specified identifiers.
    /// - Parameter productIdentifiers: The StoreKit product identifiers to load.
    /// - Returns: The products returned by StoreKit.
    /// - Throws: An error when StoreKit product loading fails.
    public func products(for productIdentifiers: [String]) async throws -> [Product] {
        try await coordinator.products(for: productIdentifiers)
    }

    // 전체 구매 구성의 상품 목록 조회
    /// Loads all products in the purchase configuration.
    /// - Returns: StoreKit products in purchase configuration order.
    /// - Throws: An error when the purchase configuration is missing or StoreKit product loading fails.
    public func products() async throws -> [Product] {
        guard let purchaseConfiguration else {
            throw PurchasesError.missingPurchaseConfiguration
        }

        return try await coordinator.products(
            for: purchaseConfiguration.productIdentifiers
        )
    }

    // Purpl에서 페이월 구매 구성 조회
    /// Loads a paywall purchase configuration from Purpl.
    ///
    /// When a cached configuration exists, this method returns it immediately and refreshes it in the background for the next paywall presentation. When no cache exists, it waits for the server response and stores the result.
    ///
    /// - Parameter paywallIdentifier: The paywall configuration identifier defined in Purpl.
    /// - Returns: An app purchase configuration resolved for the current entitlement mode.
    public func paywallConfiguration(
        for paywallIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration {
        try await paywallConfiguration(
            for: paywallIdentifier,
            localeIdentifier: Locale.current.identifier
        )
    }

    // Purpl에서 현재 로케일에 맞는 페이월 구매 구성 조회
    /// Loads a paywall purchase configuration from Purpl for the specified locale.
    /// - Parameters:
    ///   - paywallIdentifier: The paywall configuration identifier defined in Purpl.
    ///   - localeIdentifier: The locale identifier used to resolve localized content.
    /// - Returns: An app purchase configuration resolved for the current entitlement mode.
    public func paywallConfiguration(
        for paywallIdentifier: String,
        localeIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration {
        if let cachedConfiguration = await cachedPaywallConfiguration(
            for: paywallIdentifier,
            localeIdentifier: localeIdentifier
        ) {
            Task {
                _ = try? await refreshPaywallConfiguration(
                    for: paywallIdentifier,
                    localeIdentifier: localeIdentifier
                )
            }

            return cachedConfiguration
        }

        return try await refreshPaywallConfiguration(
            for: paywallIdentifier,
            localeIdentifier: localeIdentifier
        )
    }

    /// 캐시에 저장된 원격 페이월 구성 조회
    /// - Parameters:
    ///   - paywallIdentifier: 조회할 페이월 구성 식별자
    ///   - localeIdentifier: 조회할 로케일 식별자
    /// - Returns: 현재 앱 구성에 맞게 해석한 캐시 또는 캐시가 없으면 `nil`
    package func cachedPaywallConfiguration(
        for paywallIdentifier: String,
        localeIdentifier: String
    ) async -> ResolvedPaywallConfiguration? {
        guard let cachedConfiguration = await remotePaywallCache.load(
            paywallIdentifier: paywallIdentifier,
            localeIdentifier: localeIdentifier
        ) else {
            return nil
        }

        do {
            return try cachedConfiguration.resolvedConfiguration(
                paywallIdentifier: paywallIdentifier,
                localPurchaseConfiguration: purchaseConfiguration,
                entitlementMode: entitlementMode
            )
        } catch {
            // 현재 앱 구성과 맞지 않는 캐시는 제거하고 서버에서 최신 구성을 다시 확인한다.
            await remotePaywallCache.remove(
                paywallIdentifier: paywallIdentifier,
                localeIdentifier: localeIdentifier
            )
            return nil
        }
    }

    /// Purpl 서버에서 최신 원격 페이월 구성을 조회하고 캐시 갱신
    /// - Parameters:
    ///   - paywallIdentifier: 조회할 페이월 구성 식별자
    ///   - localeIdentifier: 조회할 로케일 식별자
    /// - Returns: 현재 앱 구성에 맞게 해석한 최신 페이월 구성
    package func refreshPaywallConfiguration(
        for paywallIdentifier: String,
        localeIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration {
        try await fetchRemotePaywall(
            paywallIdentifier: paywallIdentifier,
            localeIdentifier: localeIdentifier
        )
    }

    // 현재 고객이 보유한 StoreKit 권한 상품 식별자 조회
    /// Returns the StoreKit product identifiers that currently grant entitlements to the customer.
    ///
    /// The result includes only products that StoreKit currently recognizes as entitlements.
    /// - Returns: The product identifiers verified as current entitlements by StoreKit.
    public func currentEntitlementProductIdentifiers() async -> Set<String> {
        await coordinator.currentEntitlementProductIdentifiers()
    }

    // 현재 고객과 거래를 동기화해 최신 고객 정보 조회
    /// Synchronizes the current customer and transactions, then returns the latest customer information.
    /// - Parameter applicationAccountIdentifier: An optional UUID that links the current app user as an additional customer identity.
    /// - Returns: The latest customer information resolved with the configured entitlement mode.
    /// - Throws: An error when StoreKit information loading or Purpl server synchronization fails.
    public func customerInfo(
        applicationAccountIdentifier: UUID? = nil
    ) async throws -> CustomerInfo {
        try await coordinator.customerInfo(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
    }

    // StoreKit 상품 구매
    /// Purchases a StoreKit product.
    /// - Parameters:
    ///   - product: The StoreKit product to purchase.
    ///   - appAccountToken: An optional UUID that links the signed-in user's purchase to an app account.
    /// - Returns: The StoreKit purchase processing result.
    /// - Throws: An error when the StoreKit purchase or transaction verification fails.
    public func purchase(
        _ product: Product,
        appAccountToken: UUID? = nil
    ) async throws -> PurchaseResult {
        try await coordinator.purchase(
            product,
            appAccountToken: appAccountToken
        )
    }

    // App Store 구매 내역 복원과 최신 고객 정보 확인
    /// Restores App Store purchases and returns the latest customer information.
    /// - Parameter applicationAccountIdentifier: An optional UUID that links the current app user as an additional customer identity.
    /// - Returns: The latest customer information resolved with the configured entitlement mode after restoration.
    /// - Throws: An error when App Store restoration or customer information synchronization fails.
    public func restorePurchases(
        applicationAccountIdentifier: UUID? = nil
    ) async throws -> CustomerInfo {
        try await coordinator.restorePurchases(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
    }

    // App Store 구매 내역 동기화
    /// Synchronizes App Store purchase history.
    ///
    /// This method performs only StoreKit synchronization without synchronizing customer information with the server.
    public func synchronizePurchases() async throws {
        try await coordinator.synchronizePurchases()
    }

    /// 내부 StoreKit 거래 변경 감시 시작
    private func start() {
        Task {
            await coordinator.start()
        }
    }

    /// 원격 구매 구성 조회와 캐시 저장
    private func fetchRemotePaywall(
        paywallIdentifier: String,
        localeIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration {
        do {
            let remotePaywall = try await coordinator
                .remotePaywall(
                    paywallIdentifier: paywallIdentifier,
                    localeIdentifier: localeIdentifier
                )
            let resolvedConfiguration = try remotePaywall.resolvedConfiguration(
                paywallIdentifier: paywallIdentifier,
                localPurchaseConfiguration: purchaseConfiguration,
                entitlementMode: entitlementMode
            )

            try? await remotePaywallCache.save(
                remotePaywall,
                paywallIdentifier: paywallIdentifier,
                localeIdentifier: localeIdentifier
            )
            return resolvedConfiguration
        } catch {
            if case PurchasesError.unsuccessfulServerResponse(
                statusCode: 404,
                errorCode: _
            ) = error {
                await remotePaywallCache.remove(
                    paywallIdentifier: paywallIdentifier,
                    localeIdentifier: localeIdentifier
                )
            }

            throw error
        }
    }

}
