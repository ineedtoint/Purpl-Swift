//
//  PurchasesCoordinator.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation
import StoreKit

/// StoreKit과 Purchases 서버 작업을 조율하는 내부 코디네이터
actor PurchasesCoordinator {
    /// Purpl 서버 요청 경계
    private let serverClient: any PurchasesServerClientProtocol

    /// StoreKit 구매 정보 제공 경계
    private let storeService: any StoreKitServiceProtocol

    /// 앱 전체 구매 구성
    private let purchaseConfiguration: PurchaseConfiguration?

    /// 고객 권한 확인 방식
    private let entitlementMode: EntitlementMode

    /// 고객 정보 스트림 발행기
    private let customerInfoPublisher: CustomerInfoStreamPublisher

    /// 거래 변경 감시 작업
    private var transactionUpdatesTask: Task<Void, Never>?

    /// 거래 식별자별 진행 중 처리 작업
    private var transactionProcessingTasks = [UInt64: Task<Void, Error>]()

    /// 자동 동기화 시작 여부
    private var started = false

    /// Purpl 내부 코디네이터 생성
    init(
        configuration: PurchasesConfiguration,
        customerInfoPublisher: CustomerInfoStreamPublisher
    ) {
        serverClient = PurchasesServerClient(configuration: configuration)
        storeService = StoreKitService()
        purchaseConfiguration = configuration.purchaseConfiguration
        entitlementMode = configuration.entitlementMode
        self.customerInfoPublisher = customerInfoPublisher
    }

    /// 테스트 가능한 Purpl 내부 코디네이터 생성
    init(
        serverClient: any PurchasesServerClientProtocol,
        storeService: any StoreKitServiceProtocol,
        purchaseConfiguration: PurchaseConfiguration? = nil,
        entitlementMode: EntitlementMode = .server,
        customerInfoPublisher: CustomerInfoStreamPublisher = CustomerInfoStreamPublisher()
    ) {
        self.serverClient = serverClient
        self.storeService = storeService
        self.purchaseConfiguration = purchaseConfiguration
        self.entitlementMode = entitlementMode
        self.customerInfoPublisher = customerInfoPublisher
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    /// StoreKit 거래 변경 감시 시작
    func start() async {
        guard !started else {
            return
        }

        started = true
        let verifiedTransactionUpdates = storeService.verifiedTransactionUpdates()

        transactionUpdatesTask = Task { [weak self] in
            for await transaction in verifiedTransactionUpdates {
                guard let self else {
                    return
                }

                await self.processObservedTransaction(transaction)
            }
        }

        let unfinishedTransactions = await storeService.unfinishedVerifiedTransactions()

        for transaction in unfinishedTransactions {
            await processObservedTransaction(transaction)
        }
    }

    /// StoreKit 상품 목록 조회
    func products(for productIdentifiers: [String]) async throws -> [Product] {
        try await storeService.products(for: productIdentifiers)
    }

    /// 현재 앱 Bundle ID로 원격 페이월 조회
    /// - Parameter paywallIdentifier: 조회할 페이월 구성 식별자
    /// - Returns: 공개 Bundle ID로 서버에서 조회한 원격 페이월 응답
    func remotePaywall(
        paywallIdentifier: String
    ) async throws -> RemotePaywallResponse {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            throw PurchasesError.invalidServerResponse
        }

        return try await serverClient.paywall(
            paywallIdentifier: paywallIdentifier,
            bundleIdentifier: bundleIdentifier
        )
    }

    /// 현재 고객이 보유한 StoreKit 권한 상품 식별자 조회
    /// - Returns: 검증된 현재 권한 거래의 상품 식별자 목록
    func currentEntitlementProductIdentifiers() async -> Set<String> {
        let verifiedTransactions = await storeService.currentVerifiedEntitlementTransactions()
        return Set(verifiedTransactions.map(\.productIdentifier))
    }

    /// 현재 StoreKit 고객과 거래로 최신 고객 정보 조회
    func customerInfo(
        applicationAccountIdentifier: UUID?
    ) async throws -> CustomerInfo {
        let verifiedTransactions = await storeService.currentVerifiedEntitlementTransactions()
        return try await resolveCustomerInfo(
            verifiedTransactions: verifiedTransactions,
            applicationAccountIdentifier: applicationAccountIdentifier?.uuidString.lowercased()
        )
    }

    /// StoreKit 상품 구매와 공통 거래 처리
    /// - Parameters:
    ///   - product: 구매할 StoreKit 상품
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    /// - Returns: StoreKit 구매 처리 상태
    func purchase(
        _ product: Product,
        appAccountToken: UUID?
    ) async throws -> PurchaseResult {
        guard product.type != .consumable else {
            throw PurchasesError.unsupportedProductType
        }

        let storePurchaseResult = try await storeService.purchase(
            product,
            appAccountToken: appAccountToken
        )

        switch storePurchaseResult {
        case .completed(let transaction):
            try await processTransaction(
                transaction,
                applicationAccountIdentifier: appAccountToken?.uuidString.lowercased()
            )

            return .completed
        case .pending:
            return .pending
        case .cancelled:
            return .cancelled
        }
    }

    /// App Store 구매 내역 복원과 최신 고객 정보 확인
    func restorePurchases(
        applicationAccountIdentifier: UUID? = nil
    ) async throws -> CustomerInfo {
        try await storeService.synchronizePurchases()
        return try await customerInfo(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
    }

    /// App Store 구매 내역만 동기화
    func synchronizePurchases() async throws {
        try await storeService.synchronizePurchases()
    }

    /// 호출자가 없는 거래 변경이나 미완료 거래 처리
    /// - Parameter transaction: 처리할 검증된 StoreKit 거래
    private func processObservedTransaction(
        _ transaction: VerifiedStoreTransaction
    ) async {
        do {
            try await processTransaction(
                transaction,
                applicationAccountIdentifier: nil
            )
        } catch {
            // 서버 검증이나 앱 지급에 실패한 거래는 종료하지 않고 다음 실행에서 재시도한다.
        }
    }

    /// 모든 진입점에서 받은 검증 거래를 식별자별로 한 번씩 처리
    /// - Parameters:
    ///   - transaction: 처리할 검증된 StoreKit 거래
    ///   - applicationAccountIdentifier: 현재 앱 사용자를 연결할 선택 식별자
    func processTransaction(
        _ transaction: VerifiedStoreTransaction,
        applicationAccountIdentifier: String?
    ) async throws {
        if let transactionProcessingTask =
            transactionProcessingTasks[transaction.transactionIdentifier] {
            try await transactionProcessingTask.value
            return
        }

        let resolvedApplicationAccountIdentifier =
            applicationAccountIdentifier
            ?? transaction.appAccountToken?.uuidString.lowercased()
        let transactionProcessingTask = Task { [self] in
            try await processTransactionOnce(
                transaction,
                applicationAccountIdentifier: resolvedApplicationAccountIdentifier
            )
        }
        transactionProcessingTasks[transaction.transactionIdentifier] =
            transactionProcessingTask

        do {
            try await transactionProcessingTask.value
            transactionProcessingTasks[transaction.transactionIdentifier] = nil
        } catch {
            transactionProcessingTasks[transaction.transactionIdentifier] = nil
            throw error
        }
    }

    /// 상품 유형에 따라 검증 거래를 한 번 처리
    /// - Parameters:
    ///   - transaction: 처리할 검증된 StoreKit 거래
    ///   - applicationAccountIdentifier: 현재 앱 사용자를 연결할 선택 식별자
    private func processTransactionOnce(
        _ transaction: VerifiedStoreTransaction,
        applicationAccountIdentifier: String?
    ) async throws {
        guard transaction.productType != .consumable else {
            throw PurchasesError.unsupportedProductType
        }

        try await synchronizeTransaction(
            transaction,
            applicationAccountIdentifier: applicationAccountIdentifier
        )
        await transaction.finish()
    }

    /// 검증된 StoreKit 거래를 현재 거래 목록과 함께 동기화
    /// - Parameters:
    ///   - transaction: 동기화할 검증된 StoreKit 거래
    ///   - applicationAccountIdentifier: 현재 앱 사용자를 연결할 선택 식별자
    private func synchronizeTransaction(
        _ transaction: VerifiedStoreTransaction,
        applicationAccountIdentifier: String?
    ) async throws {
        var verifiedTransactions = await storeService.currentVerifiedEntitlementTransactions()
        appendTransactionIfNeeded(
            transaction,
            to: &verifiedTransactions
        )

        _ = try await resolveCustomerInfo(
            verifiedTransactions: verifiedTransactions,
            applicationAccountIdentifier: applicationAccountIdentifier
        )
    }

    /// 설정한 권한 확인 방식으로 고객 정보 결정
    private func resolveCustomerInfo(
        verifiedTransactions: [VerifiedStoreTransaction],
        applicationAccountIdentifier: String?
    ) async throws -> CustomerInfo {
        switch entitlementMode {
        case .server:
            let verifiedAppTransaction = try await storeService.currentVerifiedAppTransaction()

            return try await synchronizeServerCustomer(
                verifiedAppTransaction: verifiedAppTransaction,
                verifiedTransactions: verifiedTransactions,
                applicationAccountIdentifier: applicationAccountIdentifier
            )
        case .serverWithStoreKitFallback:
            var verifiedAppTransaction: VerifiedAppTransaction?

            do {
                let currentVerifiedAppTransaction = try await storeService
                    .currentVerifiedAppTransaction()
                verifiedAppTransaction = currentVerifiedAppTransaction

                return try await synchronizeServerCustomer(
                    verifiedAppTransaction: currentVerifiedAppTransaction,
                    verifiedTransactions: verifiedTransactions,
                    applicationAccountIdentifier: applicationAccountIdentifier
                )
            } catch let serverModeError {
                do {
                    return try await makeStoreKitCustomerInfo(
                        verifiedTransactions: verifiedTransactions,
                        appTransactionIdentifier: verifiedAppTransaction?
                            .appTransactionIdentifier
                    )
                } catch {
                    throw serverModeError
                }
            }
        case .storeKit:
            let verifiedAppTransaction = try? await storeService.currentVerifiedAppTransaction()

            return try await makeStoreKitCustomerInfo(
                verifiedTransactions: verifiedTransactions,
                appTransactionIdentifier: verifiedAppTransaction?.appTransactionIdentifier
            )
        }
    }

    /// 현재 StoreKit 정보로 서버 고객과 거래 및 권한 동기화
    private func synchronizeServerCustomer(
        verifiedAppTransaction: VerifiedAppTransaction,
        verifiedTransactions: [VerifiedStoreTransaction],
        applicationAccountIdentifier: String?
    ) async throws -> CustomerInfo {
        let payload = SignedPurchasesPayload(
            // StoreKit AppTransaction에서 현재 Apple 고객을 식별하는 검증된 JWS를 조회
            signedAppTransaction: verifiedAppTransaction.signedAppTransaction,
            // StoreKit 현재 권한 거래에서 서버가 검증하고 저장할 거래 JWS 목록을 구성
            signedTransactions: Array(
                Set(verifiedTransactions.map(\.signedTransaction))
            ).sorted(),
            // 앱 개발자가 customerInfo 호출에 전달한 선택적 사용자 UUID를 고객의 추가 신원으로 연결
            applicationAccountIdentifier: applicationAccountIdentifier
        )

        // 서버가 확인한 고객 정보에 검증된 StoreKit 앱 거래 식별자를 결합한다.
        let serverCustomerInfo = try await serverClient.synchronizeCustomer(with: payload)
        let customerInfo = CustomerInfo(
            source: serverCustomerInfo.source,
            appTransactionIdentifier: verifiedAppTransaction.appTransactionIdentifier,
            customerIdentifier: serverCustomerInfo.customerIdentifier,
            entitlements: serverCustomerInfo.entitlements
        )
        customerInfoPublisher.publish(customerInfo)
        return customerInfo
    }

    /// 현재 StoreKit 거래와 구매 카탈로그로 로컬 고객 정보 생성
    private func makeStoreKitCustomerInfo(
        verifiedTransactions: [VerifiedStoreTransaction],
        appTransactionIdentifier: String?
    ) async throws -> CustomerInfo {
        guard let purchaseConfiguration else {
            throw PurchasesError.missingPurchaseConfiguration
        }

        let verificationDate = Date()
        let activeTransactions = verifiedTransactions.filter { transaction in
            guard purchaseConfiguration.product(
                forStoreProductIdentifier: transaction.productIdentifier
            ) != nil else {
                return false
            }

            guard transaction.revocationDate == nil else {
                return false
            }

            guard transaction.isUpgraded == false else {
                return false
            }

            if let expirationDate = transaction.expirationDate {
                return expirationDate > verificationDate
            }

            return true
        }

        if activeTransactions.isEmpty {
            // 상품 조회 성공 여부로 무료 상태와 StoreKit 통신 실패를 구분한다.
            _ = try await storeService.products(for: purchaseConfiguration.productIdentifiers)
        }

        let entitlements: [CustomerEntitlement] = purchaseConfiguration.entitlements.compactMap { entitlement in
            guard let transaction = activeTransactions.first(where: { transaction in
                purchaseConfiguration.product(
                    forStoreProductIdentifier: transaction.productIdentifier
                )?.entitlementIdentifiers.contains(entitlement.identifier) == true
            }) else {
                return nil
            }

            return CustomerEntitlement(
                identifier: entitlement.identifier,
                displayName: entitlement.titleResource.map { titleResource in
                    String(localized: titleResource)
                } ?? entitlement.identifier,
                productIdentifier: transaction.productIdentifier,
                environment: Self.customerEnvironment(from: transaction.environment),
                status: .active,
                active: true,
                startsAt: transaction.purchaseDate,
                expiresAt: transaction.expirationDate,
                revokedAt: transaction.revocationDate,
                lastVerifiedAt: verificationDate
            )
        }
        let customerInfo = CustomerInfo(
            source: .storeKit,
            appTransactionIdentifier: appTransactionIdentifier,
            customerIdentifier: nil,
            entitlements: entitlements
        )

        customerInfoPublisher.publish(customerInfo)
        return customerInfo
    }

    /// StoreKit 거래 환경을 공개 고객 정보 환경으로 변환
    private static func customerEnvironment(
        from environment: AppStore.Environment
    ) -> StoreEnvironment {
        switch environment {
        case .production:
            return .production
        case .sandbox:
            return .sandbox
        case .xcode:
            return .xcode
        default:
            return .sandbox
        }
    }

    /// 동일 StoreKit JWS가 없는 경우 거래 목록에 추가
    private func appendTransactionIfNeeded(
        _ transaction: VerifiedStoreTransaction,
        to verifiedTransactions: inout [VerifiedStoreTransaction]
    ) {
        guard !verifiedTransactions.contains(where: { verifiedTransaction in
            verifiedTransaction.signedTransaction == transaction.signedTransaction
        }) else {
            return
        }

        verifiedTransactions.append(transaction)
    }
}
