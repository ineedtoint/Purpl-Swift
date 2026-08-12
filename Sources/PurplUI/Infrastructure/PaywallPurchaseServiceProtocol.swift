//
//  PaywallPurchaseServiceProtocol.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import Foundation
import Purpl
import StoreKit

/// 페이월에서 사용하는 Purpl 서비스 경계
protocol PaywallPurchaseServiceProtocol: Sendable {
    /// 최신 고객 정보와 이후 변경 정보를 전달하는 스트림
    var customerInfoStream: AsyncStream<CustomerInfo> { get }

    /// Purpl에서 원격 페이월 구성 조회
    func paywallConfiguration(
        for paywallIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration

    /// Purpl에서 현재 로케일에 맞는 원격 페이월 구성 조회
    func paywallConfiguration(
        for paywallIdentifier: String,
        localeIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration

    /// StoreKit 상품 목록 조회
    /// - Parameter productIdentifiers: 조회할 StoreKit 상품 식별자 목록
    /// - Returns: StoreKit에서 조회한 상품 목록
    func products(for productIdentifiers: [String]) async throws -> [Product]

    /// 현재 고객이 보유한 StoreKit 권한 상품 식별자 조회
    /// - Returns: StoreKit이 현재 권한으로 확인한 상품 식별자 목록
    func currentEntitlementProductIdentifiers() async -> Set<String>

    /// 현재 고객 정보 조회
    /// - Parameter applicationAccountIdentifier: 현재 앱 사용자를 연결할 선택 UUID
    /// - Returns: 최신 고객 정보
    func customerInfo(
        applicationAccountIdentifier: UUID?
    ) async throws -> CustomerInfo

    /// StoreKit 상품 구매
    /// - Parameters:
    ///   - product: 구매할 StoreKit 상품
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    /// - Returns: StoreKit 구매 처리 상태
    func purchase(
        _ product: Product,
        appAccountToken: UUID?
    ) async throws -> PurchaseResult

    /// App Store 구매 내역 동기화
    func synchronizePurchases() async throws
}

extension PaywallPurchaseServiceProtocol {
    /// 로케일별 조회를 구현하지 않은 테스트 경계의 기존 조회 사용
    func paywallConfiguration(
        for paywallIdentifier: String,
        localeIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration {
        try await paywallConfiguration(for: paywallIdentifier)
    }

    /// 원격 페이월을 사용하지 않는 테스트 경계의 기본 동작
    func paywallConfiguration(
        for paywallIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration {
        throw PurchasesError.invalidServerResponse
    }
}

extension Purchases: PaywallPurchaseServiceProtocol { }
