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

/// Purpl 공개 진입점
public final class Purchases: Sendable {
    /// 구성한 공유 인스턴스 저장소
    private static let sharedStorage = Mutex<Purchases?>(nil)

    /// 구성한 Purpl 공유 인스턴스
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

    /// 앱 전체 구매 구성
    public let purchaseConfiguration: PurchaseConfiguration?

    /// 고객 권한 확인 방식
    private let entitlementMode: EntitlementMode

    /// 원격 구매 구성 캐시
    private let remotePaywallCache: RemotePaywallCache

    /// 고객 정보 스트림 발행기
    private let customerInfoPublisher: CustomerInfoStreamPublisher

    /// 최신 고객 정보와 이후 변경 정보를 전달하는 스트림
    public var customerInfoStream: AsyncStream<CustomerInfo> {
        customerInfoPublisher.makeStream()
    }

    /// 마지막으로 전달한 고객 정보
    var latestCustomerInfo: CustomerInfo? {
        customerInfoPublisher.latestCustomerInfo
    }

    /// 로컬 구매 구성으로 StoreKit 권한 확인과 거래 변경 감시 시작
    /// - Parameter purchaseConfiguration: 상품 조회와 권한 확인에 사용할 앱 전체 구매 구성
    /// - Returns: 구성한 Purpl 공유 인스턴스
    @discardableResult
    public static func configure(
        _ purchaseConfiguration: PurchaseConfiguration
    ) -> Purchases {
        configure(
            purchaseConfiguration,
            entitlementMode: .storeKit
        )
    }

    /// Purpl 구성과 StoreKit 거래 변경 감시 시작
    /// - Parameters:
    ///   - purchaseConfiguration: 상품 조회와 StoreKit 권한 확인에 사용할 앱 전체 구매 구성
    ///   - entitlementMode: 고객 권한을 확인할 방식
    /// - Returns: 구성한 Purpl 공유 인스턴스
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

    /// StoreKit 상품 목록 조회
    /// - Parameter productIdentifiers: 조회할 StoreKit 상품 식별자 목록
    /// - Returns: StoreKit에서 조회한 상품 목록
    /// - Throws: StoreKit 상품 조회 실패 오류
    public func products(for productIdentifiers: [String]) async throws -> [Product] {
        try await coordinator.products(for: productIdentifiers)
    }

    /// 전체 구매 구성의 상품 목록 조회
    /// - Returns: 구매 구성 순서로 정리한 StoreKit 상품 목록
    /// - Throws: 구매 구성 누락 또는 StoreKit 상품 조회 실패 오류
    public func products() async throws -> [Product] {
        guard let purchaseConfiguration else {
            throw PurchasesError.missingPurchaseConfiguration
        }

        return try await coordinator.products(
            for: purchaseConfiguration.productIdentifiers
        )
    }

    /// Purpl에서 페이월 구매 구성 조회
    ///
    /// 캐시가 있으면 즉시 반환하고 다음 페이월 표시를 위해 백그라운드에서 갱신한다.
    /// 캐시가 없으면 서버 응답을 기다린 뒤 저장한다.
    ///
    /// - Parameter paywallIdentifier: Purpl 웹에서 정의한 페이월 구성 식별자
    /// - Returns: 현재 권한 확인 방식에 맞게 해석한 앱 구매 구성
    public func paywallConfiguration(
        for paywallIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration {
        try await paywallConfiguration(
            for: paywallIdentifier,
            localeIdentifier: Locale.current.identifier
        )
    }

    /// Purpl에서 현재 로케일에 맞는 페이월 구매 구성 조회
    /// - Parameters:
    ///   - paywallIdentifier: Purpl 웹에서 정의한 페이월 구성 식별자
    ///   - localeIdentifier: 기기의 현재 로케일 식별자
    /// - Returns: 현재 권한 확인 방식에 맞게 해석한 앱 구매 구성
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

    /// 현재 고객이 보유한 StoreKit 권한 상품 식별자 조회
    ///
    /// StoreKit이 현재 권한으로 인정하는 상품만 결과에 포함된다.
    /// - Returns: StoreKit이 현재 권한으로 확인한 상품 식별자 목록
    public func currentEntitlementProductIdentifiers() async -> Set<String> {
        await coordinator.currentEntitlementProductIdentifiers()
    }

    /// 현재 고객과 거래를 동기화해 최신 고객 정보 조회
    /// - Parameter applicationAccountIdentifier: 현재 앱 사용자를 고객의 추가 신원으로 연결할 선택 UUID
    /// - Returns: 설정한 권한 확인 방식으로 확인한 최신 고객 정보
    /// - Throws: StoreKit 정보 조회 또는 Purchases 서버 동기화 실패 오류
    public func customerInfo(
        applicationAccountIdentifier: UUID? = nil
    ) async throws -> CustomerInfo {
        try await coordinator.customerInfo(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
    }

    /// StoreKit 상품 구매
    /// - Parameters:
    ///   - product: 구매할 StoreKit 상품
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    /// - Returns: StoreKit 구매 처리 상태
    /// - Throws: StoreKit 구매 또는 거래 검증 실패 오류
    public func purchase(
        _ product: Product,
        appAccountToken: UUID? = nil
    ) async throws -> PurchaseResult {
        try await coordinator.purchase(
            product,
            appAccountToken: appAccountToken
        )
    }

    /// App Store 구매 내역 복원과 최신 고객 정보 확인
    /// - Parameter applicationAccountIdentifier: 현재 앱 사용자를 고객의 추가 신원으로 연결할 선택 UUID
    /// - Returns: 복원 후 설정한 권한 확인 방식으로 확인한 최신 고객 정보
    /// - Throws: App Store 복원 또는 고객 정보 동기화 실패 오류
    public func restorePurchases(
        applicationAccountIdentifier: UUID? = nil
    ) async throws -> CustomerInfo {
        try await coordinator.restorePurchases(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
    }

    /// App Store 구매 내역 동기화
    ///
    /// 고객 정보 서버 동기화와 관계없이 StoreKit 동기화만 수행한다.
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
