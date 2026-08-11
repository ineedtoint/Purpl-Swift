//
//  StoreKitServiceProtocol.swift
//  Purpl
//
//  Created by Int on 7/27/26.
//

import Foundation
import StoreKit

/// StoreKit 상품과 검증된 거래를 도메인 독립적으로 제공하는 인터페이스
protocol StoreKitServiceProtocol: Sendable {
    // MARK: - 상품

    /// 상품 식별자에 해당하는 StoreKit 상품 목록 조회
    func products(for productIdentifiers: [String]) async throws -> [Product]

    // MARK: - 구매

    /// StoreKit 상품 구매
    /// - Parameters:
    ///   - product: 구매할 StoreKit 상품
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 식별자
    func purchase(
        _ product: Product,
        appAccountToken: UUID?
    ) async throws -> StoreKitPurchaseResult

    // MARK: - 현재 권한

    /// 현재 권한을 제공하는 검증된 StoreKit 거래 목록 조회
    ///
    /// StoreKit이 현재 권한으로 인정하는 거래만 결과에 포함된다.
    func currentVerifiedEntitlementTransactions() async -> [VerifiedStoreTransaction]

    // MARK: - 미완료 거래

    /// 아직 종료되지 않은 검증된 StoreKit 거래 목록 조회
    ///
    /// 거래 처리나 서버 반영에 실패한 거래를 다시 처리할 때 사용한다.
    func unfinishedVerifiedTransactions() async -> [VerifiedStoreTransaction]

    // MARK: - 전체 거래

    /// 현재 고객의 검증된 StoreKit 전체 거래 내역 조회
    ///
    /// 전체 이력은 감사와 복구에 사용하며 현재 권한 판단에는 사용하지 않는다.
    func allVerifiedTransactions() async -> [VerifiedStoreTransaction]

    // MARK: - 거래 변경

    /// 실행 중 수신하는 검증된 StoreKit 거래 변경 스트림 생성
    ///
    /// 다른 기기의 구매, 보호자 승인, 갱신과 회수처럼 앱 밖에서 발생한 거래를 전달한다.
    func verifiedTransactionUpdates() -> AsyncStream<VerifiedStoreTransaction>

    // MARK: - 구매 복원

    /// 사용자 요청에 따른 App Store 구매 내역 동기화
    ///
    /// 사용자 인증 화면이 나타날 수 있으므로 명시적인 구매 복원 동작에서만 호출한다.
    func synchronizePurchases() async throws

    // MARK: - 앱 거래

    /// 현재 고객을 나타내는 검증된 StoreKit 앱 거래 조회
    func currentVerifiedAppTransaction() async throws -> VerifiedAppTransaction
}
