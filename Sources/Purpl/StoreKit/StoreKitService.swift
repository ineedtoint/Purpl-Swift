//
//  StoreKitService.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation
import StoreKit

/// StoreKit 상품과 검증된 거래를 도메인 독립적으로 제공하는 서비스
struct StoreKitService: StoreKitServiceProtocol {
    // MARK: - 상품

    /// 상품 식별자에 해당하는 StoreKit 상품 목록 조회
    func products(for productIdentifiers: [String]) async throws -> [Product] {
        let loadedProducts = try await Product.products(for: productIdentifiers)
        let productsByIdentifier = Dictionary(
            uniqueKeysWithValues: loadedProducts.map { product in
                (product.id, product)
            }
        )

        // App Store 응답 순서와 관계없이 개발자가 요청한 상품 순서를 유지한다.
        return productIdentifiers.compactMap { productIdentifier in
            productsByIdentifier[productIdentifier]
        }
    }

    // MARK: - 구매

    /// StoreKit 상품 구매
    /// - Parameters:
    ///   - product: 구매할 StoreKit 상품
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 식별자
    func purchase(
        _ product: Product,
        appAccountToken: UUID?
    ) async throws -> StoreKitPurchaseResult {
        let purchaseResult: Product.PurchaseResult

        if let appAccountToken {
            // 앱 계정 식별자를 Apple 서명 거래에 포함해 서버에서도 연결을 검증할 수 있게 한다.
            purchaseResult = try await product.purchase(
                options: [.appAccountToken(appAccountToken)]
            )
        } else {
            purchaseResult = try await product.purchase()
        }

        switch purchaseResult {
        case .success(let verificationResult):
            guard case .verified(let transaction) = verificationResult else {
                throw PurchasesError.unverifiedTransaction
            }

            return .completed(Self.makeVerifiedTransaction(
                transaction,
                signedTransaction: verificationResult.jwsRepresentation
            ))
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw PurchasesError.unknownPurchaseResult
        }
    }

    // MARK: - 현재 권한

    /// 현재 권한을 제공하는 검증된 StoreKit 거래 목록 조회
    func currentVerifiedEntitlementTransactions() async -> [VerifiedStoreTransaction] {
        await Self.verifiedTransactions(from: Transaction.currentEntitlements)
    }

    // MARK: - 미완료 거래

    /// 아직 종료되지 않은 검증된 StoreKit 거래 목록 조회
    func unfinishedVerifiedTransactions() async -> [VerifiedStoreTransaction] {
        await Self.verifiedTransactions(from: Transaction.unfinished)
    }

    // MARK: - 전체 거래

    /// 현재 고객의 검증된 StoreKit 전체 거래 내역 조회
    func allVerifiedTransactions() async -> [VerifiedStoreTransaction] {
        await Self.verifiedTransactions(from: Transaction.all)
    }

    // MARK: - 거래 변경

    /// 실행 중 수신하는 검증된 StoreKit 거래 변경 스트림 생성
    func verifiedTransactionUpdates() -> AsyncStream<VerifiedStoreTransaction> {
        AsyncStream { continuation in
            let observationTask = Task {
                for await transactionResult in Transaction.updates {
                    // 검증하지 못한 거래는 상위 계층에 전달하거나 종료하지 않는다.
                    guard case .verified(let transaction) = transactionResult else {
                        continue
                    }

                    continuation.yield(Self.makeVerifiedTransaction(
                        transaction,
                        signedTransaction: transactionResult.jwsRepresentation
                    ))
                }

                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                observationTask.cancel()
            }
        }
    }

    // MARK: - 구매 복원

    /// 사용자 요청에 따른 App Store 구매 내역 동기화
    func synchronizePurchases() async throws {
        // AppStore.sync는 인증 화면을 표시할 수 있으므로 명시적인 복원 요청에서만 호출한다.
        try await AppStore.sync()
    }

    // MARK: - 앱 거래

    /// 현재 고객을 나타내는 검증된 StoreKit 앱 거래 조회
    func currentVerifiedAppTransaction() async throws -> VerifiedAppTransaction {
        let appTransactionResult = try await AppTransaction.shared

        guard case .verified(let appTransaction) = appTransactionResult else {
            throw PurchasesError.unverifiedAppTransaction
        }

        return VerifiedAppTransaction(
            signedAppTransaction: appTransactionResult.jwsRepresentation,
            appTransactionIdentifier: appTransaction.appTransactionID,
            environment: appTransaction.environment
        )
    }

    // MARK: - 검증과 변환

    /// StoreKit 거래 시퀀스에서 Apple이 검증한 거래만 SDK 공통 모델로 변환
    private static func verifiedTransactions(
        from transactions: Transaction.Transactions
    ) async -> [VerifiedStoreTransaction] {
        var verifiedTransactions = [VerifiedStoreTransaction]()

        for await transactionResult in transactions {
            // 권한이나 재화를 잘못 제공하지 않도록 검증 실패 거래는 결과에서 제외한다.
            guard case .verified(let transaction) = transactionResult else {
                continue
            }

            verifiedTransactions.append(makeVerifiedTransaction(
                transaction,
                signedTransaction: transactionResult.jwsRepresentation
            ))
        }

        return verifiedTransactions.sorted { firstTransaction, secondTransaction in
            if firstTransaction.transactionIdentifier ==
                secondTransaction.transactionIdentifier {
                return firstTransaction.signedTransaction < secondTransaction.signedTransaction
            }

            return firstTransaction.transactionIdentifier < secondTransaction.transactionIdentifier
        }
    }

    /// StoreKit 거래를 SDK 공통 거래 정보로 변환
    private static func makeVerifiedTransaction(
        _ transaction: Transaction,
        signedTransaction: String
    ) -> VerifiedStoreTransaction {
        VerifiedStoreTransaction(
            signedTransaction: signedTransaction,
            transactionIdentifier: transaction.id,
            originalTransactionIdentifier: transaction.originalID,
            productIdentifier: transaction.productID,
            productType: transaction.productType,
            purchasedQuantity: transaction.purchasedQuantity,
            appAccountToken: transaction.appAccountToken,
            subscriptionGroupIdentifier: transaction.subscriptionGroupID,
            ownershipType: transaction.ownershipType,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate,
            isUpgraded: transaction.isUpgraded,
            environment: transaction.environment,
            finishOperation: {
                await transaction.finish()
            }
        )
    }
}
