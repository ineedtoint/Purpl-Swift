//
//  PurchasesCoordinatorTests.swift
//  PurplTests
//
//  Created by Int on 7/26/26.
//

import Foundation
import StoreKit
import Testing
@testable import Purpl

/// Purpl 내부 코디네이터 테스트
struct PurchasesCoordinatorTests {
    /// 거래 변경 감시 시작만으로 고객 동기화를 요청하지 않는지 확인
    @Test
    func startDoesNotSynchronizeCustomer() async {
        let serverClient = SequentialPurchasesServerClientSpy(
            customerInfos: [makeCustomerInfo()]
        )
        let coordinator = PurchasesCoordinator(
            serverClient: serverClient,
            storeService: StoreKitServiceStub()
        )

        await coordinator.start()

        #expect(await serverClient.requestCount == 0)
    }

    /// 현재 StoreKit 정보와 앱 계정 식별자를 서버에 전달하는지 확인
    @Test
    func customerInfoSynchronizesCurrentStoreInformation() async throws {
        let applicationAccountIdentifier = UUID(
            uuidString: "0A4AB892-252E-46E5-AF13-1C9A7738E0BE"
        )!
        let expectedCustomerInfo = makeCustomerInfo()
        let serverClient = PurchasesServerClientSpy(customerInfo: expectedCustomerInfo)
        let coordinator = PurchasesCoordinator(
            serverClient: serverClient,
            storeService: StoreKitServiceStub(
                verifiedTransactions: [makeVerifiedTransaction()]
            )
        )

        let customerInfo = try await coordinator.customerInfo(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
        let receivedPayload = try #require(await serverClient.receivedPayload())

        #expect(customerInfo == expectedCustomerInfo)
        #expect(customerInfo.appTransactionIdentifier == "app-transaction-identifier")
        #expect(receivedPayload.signedAppTransaction == "signed-app-transaction")
        #expect(receivedPayload.signedTransactions == ["signed-transaction"])
        #expect(
            receivedPayload.applicationAccountIdentifier ==
                applicationAccountIdentifier.uuidString.lowercased()
        )
    }

    /// 현재 보유 상품 식별자를 서버 요청 없이 StoreKit 거래에서 반환하는지 확인
    @Test
    func currentEntitlementProductIdentifiersUseStoreKitTransactions() async {
        let serverClient = SequentialPurchasesServerClientSpy(
            customerInfos: [makeCustomerInfo()]
        )
        let coordinator = PurchasesCoordinator(
            serverClient: serverClient,
            storeService: StoreKitServiceStub(
                verifiedTransactions: [
                    makeVerifiedTransaction(
                        productIdentifier: "test.subscription.monthly"
                    )
                ]
            )
        )

        let productIdentifiers = await coordinator
            .currentEntitlementProductIdentifiers()

        #expect(productIdentifiers == ["test.subscription.monthly"])
        #expect(await serverClient.requestCount == 0)
    }

    /// 서버 동기화 실패를 StoreKit 권한으로 대체하지 않는지 확인
    @Test
    func customerInfoPropagatesServerFailure() async {
        let coordinator = PurchasesCoordinator(
            serverClient: NetworkFailurePurchasesServerClient(),
            storeService: StoreKitServiceStub(
                verifiedTransactions: [makeVerifiedTransaction()]
            )
        )

        await #expect(throws: URLError.self) {
            try await coordinator.customerInfo(applicationAccountIdentifier: nil)
        }
    }

    /// StoreKit 전용 모드에서 카탈로그 상품을 권한으로 변환하는지 확인
    @Test
    func customerInfoUsesStoreKitCatalog() async throws {
        let coordinator = PurchasesCoordinator(
            serverClient: NetworkFailurePurchasesServerClient(),
            storeService: StoreKitServiceStub(
                verifiedTransactions: [makeVerifiedTransaction(
                    productIdentifier: "test.subscription.monthly"
                )]
            ),
            purchaseConfiguration: makePurchaseConfiguration(),
            entitlementMode: .storeKit
        )

        let customerInfo = try await coordinator.customerInfo(
            applicationAccountIdentifier: nil
        )

        #expect(customerInfo.source == .storeKit)
        #expect(customerInfo.appTransactionIdentifier == "app-transaction-identifier")
        #expect(customerInfo.customerIdentifier == nil)
        #expect(customerInfo.activeEntitlementIdentifiers == ["plus"])
        #expect(
            customerInfo.entitlements.first?.productIdentifier ==
                "test.subscription.monthly"
        )
    }

    /// StoreKit 전용 모드에서 앱 거래 확인 실패가 권한 조회를 막지 않는지 확인
    @Test
    func customerInfoUsesStoreKitCatalogWhenAppTransactionIsUnavailable() async throws {
        let coordinator = PurchasesCoordinator(
            serverClient: NetworkFailurePurchasesServerClient(),
            storeService: StoreKitServiceStub(
                verifiedTransactions: [makeVerifiedTransaction(
                    productIdentifier: "test.subscription.monthly"
                )],
                appTransactionIdentifier: nil
            ),
            purchaseConfiguration: makePurchaseConfiguration(),
            entitlementMode: .storeKit
        )

        let customerInfo = try await coordinator.customerInfo(
            applicationAccountIdentifier: nil
        )

        #expect(customerInfo.appTransactionIdentifier == nil)
        #expect(customerInfo.activeEntitlementIdentifiers == ["plus"])
    }

    /// 서버 실패 시 StoreKit 카탈로그 권한으로 대체하는지 확인
    @Test
    func customerInfoFallsBackToStoreKit() async throws {
        let storeService = StoreKitServiceUpdateSpy(
            verifiedTransactions: [makeVerifiedTransaction(
                productIdentifier: "test.subscription.yearly"
            )]
        )
        let coordinator = PurchasesCoordinator(
            serverClient: NetworkFailurePurchasesServerClient(),
            storeService: storeService,
            purchaseConfiguration: makePurchaseConfiguration(),
            entitlementMode: .serverWithStoreKitFallback
        )

        let customerInfo = try await coordinator.customerInfo(
            applicationAccountIdentifier: nil
        )

        #expect(customerInfo.source == .storeKit)
        #expect(customerInfo.appTransactionIdentifier == "app-transaction-identifier")
        #expect(await storeService.appTransactionRequestCount == 1)
        #expect(customerInfo.activeEntitlementIdentifiers == ["plus"])
        #expect(
            customerInfo.entitlements.first?.productIdentifier ==
                "test.subscription.yearly"
        )
    }

    /// 고객 정보 스트림이 서버가 확인한 마지막 고객 정보를 전달하는지 확인
    @Test
    func customerInfoStreamProvidesLatestServerCustomerInfo() async throws {
        let expectedCustomerInfo = makeCustomerInfo()
        let customerInfoPublisher = CustomerInfoStreamPublisher()
        let coordinator = PurchasesCoordinator(
            serverClient: PurchasesServerClientSpy(customerInfo: expectedCustomerInfo),
            storeService: StoreKitServiceStub(),
            customerInfoPublisher: customerInfoPublisher
        )

        _ = try await coordinator.customerInfo(applicationAccountIdentifier: nil)
        var customerInfoIterator = customerInfoPublisher.makeStream().makeAsyncIterator()
        let streamedCustomerInfo = await customerInfoIterator.next()

        #expect(streamedCustomerInfo == expectedCustomerInfo)
        #expect(customerInfoPublisher.latestCustomerInfo == expectedCustomerInfo)
    }

    /// StoreKit 거래 변경을 서버에 반영한 뒤 종료하는지 확인
    @Test
    func transactionUpdateFinishesAfterServerSynchronization() async throws {
        let initialCustomerInfo = CustomerInfo(
            customerIdentifier: "customer-identifier",
            entitlements: []
        )
        let updatedCustomerInfo = makeCustomerInfo()
        let serverClient = SequentialPurchasesServerClientSpy(
            customerInfos: [initialCustomerInfo, updatedCustomerInfo]
        )
        let storeService = StoreKitServiceUpdateSpy()
        let customerInfoPublisher = CustomerInfoStreamPublisher()
        let coordinator = PurchasesCoordinator(
            serverClient: serverClient,
            storeService: storeService,
            customerInfoPublisher: customerInfoPublisher
        )

        await coordinator.start()
        _ = try await coordinator.customerInfo(applicationAccountIdentifier: nil)
        var customerInfoIterator = customerInfoPublisher.makeStream().makeAsyncIterator()
        _ = await customerInfoIterator.next()
        let finishRecorder = StoreTransactionFinishRecorder()
        let transaction = makeVerifiedTransaction(
            signedTransaction: "updated-signed-transaction",
            finishOperation: {
                await finishRecorder.recordFinish()
            }
        )

        await storeService.sendTransactionUpdate(transaction)
        let receivedCustomerInfo = await customerInfoIterator.next()
        let lastPayload = try #require(await serverClient.lastPayload())

        #expect(receivedCustomerInfo == updatedCustomerInfo)
        #expect(lastPayload.signedTransactions == ["updated-signed-transaction"])
        #expect(await finishRecorder.finished)
    }

    /// 서버 동기화에 실패한 비소모성 StoreKit 거래를 종료하지 않는지 확인
    @Test
    func transactionUpdateRemainsUnfinishedAfterServerFailure() async {
        let initialCustomerInfo = CustomerInfo(
            customerIdentifier: "customer-identifier",
            entitlements: []
        )
        let serverClient = SequentialPurchasesServerClientSpy(
            customerInfos: [initialCustomerInfo],
            successfulResponseCountBeforeFailure: 1
        )
        let storeService = StoreKitServiceUpdateSpy()
        let coordinator = PurchasesCoordinator(
            serverClient: serverClient,
            storeService: storeService
        )

        await coordinator.start()
        _ = try? await coordinator.customerInfo(applicationAccountIdentifier: nil)
        let finishRecorder = StoreTransactionFinishRecorder()
        let transaction = makeVerifiedTransaction(
            signedTransaction: "failed-signed-transaction",
            finishOperation: {
                await finishRecorder.recordFinish()
            }
        )

        await storeService.sendTransactionUpdate(transaction)

        for _ in 0..<100 where await serverClient.requestCount < 2 {
            await Task.yield()
        }

        #expect(await serverClient.requestCount == 2)
        #expect(await finishRecorder.finished == false)
    }

    /// 지원하지 않는 StoreKit 상품 거래를 동기화하거나 종료하지 않는지 확인
    @Test
    func unsupportedProductTypeTransactionRemainsUnfinished() async {
        let serverClient = SequentialPurchasesServerClientSpy(
            customerInfos: [makeCustomerInfo()]
        )
        let coordinator = PurchasesCoordinator(
            serverClient: serverClient,
            storeService: StoreKitServiceStub()
        )
        let finishRecorder = StoreTransactionFinishRecorder()
        let transaction = makeVerifiedTransaction(
            productType: .consumable,
            finishOperation: {
                await finishRecorder.recordFinish()
            }
        )

        await #expect(throws: PurchasesError.unsupportedProductType) {
            try await coordinator.processTransaction(
                transaction,
                applicationAccountIdentifier: nil
            )
        }

        #expect(await finishRecorder.finished == false)
        #expect(await serverClient.requestCount == 0)
    }

    /// 구매 복원 후 현재 거래를 서버에 다시 전달하는지 확인
    @Test
    func restorePurchasesSynchronizesCurrentTransactions() async throws {
        let applicationAccountIdentifier = UUID(
            uuidString: "2BB0CC5D-B9BF-4E8A-BF23-23A7A8E4DB61"
        )!
        let expectedCustomerInfo = makeCustomerInfo()
        let storeService = StoreKitServiceUpdateSpy(
            verifiedTransactions: [makeVerifiedTransaction()]
        )
        let serverClient = PurchasesServerClientSpy(customerInfo: expectedCustomerInfo)
        let coordinator = PurchasesCoordinator(
            serverClient: serverClient,
            storeService: storeService
        )

        let customerInfo = try await coordinator.restorePurchases(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
        let receivedPayload = try #require(await serverClient.receivedPayload())

        #expect(customerInfo == expectedCustomerInfo)
        #expect(await storeService.synchronizedPurchases)
        #expect(receivedPayload.signedTransactions == ["signed-transaction"])
        #expect(
            receivedPayload.applicationAccountIdentifier ==
                applicationAccountIdentifier.uuidString.lowercased()
        )
    }

    /// App Store 구매 내역 동기화가 서버 고객 정보에 의존하지 않는지 확인
    @Test
    func synchronizePurchasesDoesNotRequestServerCustomerInfo() async throws {
        let serverClient = SequentialPurchasesServerClientSpy(
            customerInfos: [makeCustomerInfo()]
        )
        let storeService = StoreKitServiceUpdateSpy()
        let coordinator = PurchasesCoordinator(
            serverClient: serverClient,
            storeService: storeService
        )

        try await coordinator.synchronizePurchases()

        #expect(await storeService.synchronizedPurchases)
        #expect(await serverClient.requestCount == 0)
    }

    /// 테스트용 검증 StoreKit 거래 생성
    private func makeVerifiedTransaction(
        signedTransaction: String = "signed-transaction",
        transactionIdentifier: UInt64 = 1,
        productIdentifier: String = "",
        productType: Product.ProductType = .autoRenewable,
        purchasedQuantity: Int = 1,
        purchaseDate: Date = Date(timeIntervalSince1970: 1_000),
        finishOperation: @escaping @Sendable () async -> Void = { }
    ) -> VerifiedStoreTransaction {
        VerifiedStoreTransaction(
            signedTransaction: signedTransaction,
            transactionIdentifier: transactionIdentifier,
            originalTransactionIdentifier: 1,
            productIdentifier: productIdentifier,
            productType: productType,
            purchasedQuantity: purchasedQuantity,
            appAccountToken: nil,
            subscriptionGroupIdentifier: "test.subscription",
            ownershipType: .purchased,
            purchaseDate: purchaseDate,
            expirationDate: nil,
            revocationDate: nil,
            isUpgraded: false,
            environment: .sandbox,
            finishOperation: finishOperation
        )
    }

    /// 테스트용 앱 전체 구매 구성 생성
    private func makePurchaseConfiguration() -> PurchaseConfiguration {
        PurchaseConfiguration(
            entitlements: [
                PurchaseEntitlement(
                    identifier: "plus",
                    titleResource: "Plus"
                )
            ],
            products: [
                PurchaseProduct(
                    productIdentifier: "test.subscription.monthly",
                    entitlementIdentifier: "plus",
                    titleResource: "Monthly",
                    descriptionResource: "Renews monthly"
                ),
                PurchaseProduct(
                    productIdentifier: "test.subscription.yearly",
                    entitlementIdentifier: "plus",
                    titleResource: "Yearly",
                    descriptionResource: "Renews yearly"
                )
            ]
        )
    }

    /// 테스트용 고객 정보 생성
    private func makeCustomerInfo() -> CustomerInfo {
        CustomerInfo(
            appTransactionIdentifier: "app-transaction-identifier",
            customerIdentifier: "customer-identifier",
            entitlements: [
                CustomerEntitlement(
                    identifier: "plus",
                    displayName: "Plus",
                    productIdentifier: "test.subscription.monthly",
                    environment: .production,
                    status: .active,
                    active: true,
                    startsAt: nil,
                    expiresAt: nil,
                    revokedAt: nil,
                    lastVerifiedAt: Date(timeIntervalSince1970: 1_000)
                )
            ]
        )
    }
}

/// 거래 변경과 구매 복원 상태를 기록하는 StoreKit 서비스
private actor StoreKitServiceUpdateSpy: StoreKitServiceProtocol {
    /// 거래 변경 스트림
    private nonisolated let updates: AsyncStream<VerifiedStoreTransaction>

    /// 거래 변경 전달자
    private nonisolated let updatesContinuation:
        AsyncStream<VerifiedStoreTransaction>.Continuation

    /// 현재 검증 거래 목록
    private var verifiedTransactions: [VerifiedStoreTransaction]

    /// 앱 시작 시 반환할 미완료 검증 거래 목록
    private let unfinishedTransactions: [VerifiedStoreTransaction]

    /// 구매 복원 호출 여부
    private(set) var synchronizedPurchases = false

    /// 검증 앱 거래 조회 횟수
    private(set) var appTransactionRequestCount = 0

    /// 거래 변경과 구매 복원 상태 기록 서비스 생성
    init(
        verifiedTransactions: [VerifiedStoreTransaction] = [],
        unfinishedTransactions: [VerifiedStoreTransaction] = []
    ) {
        let (updates, updatesContinuation) =
            AsyncStream<VerifiedStoreTransaction>.makeStream()

        self.updates = updates
        self.updatesContinuation = updatesContinuation
        self.verifiedTransactions = verifiedTransactions
        self.unfinishedTransactions = unfinishedTransactions
    }

    /// 테스트에서 사용하지 않는 상품 목록 조회
    func products(for productIdentifiers: [String]) async throws -> [Product] {
        []
    }

    /// 테스트에서 사용하지 않는 상품 구매
    func purchase(
        _ product: Product,
        appAccountToken: UUID?
    ) async throws -> StoreKitPurchaseResult {
        fatalError("이 테스트에서는 상품 구매를 호출하지 않습니다.")
    }

    /// 구매 복원 호출 기록
    func synchronizePurchases() async throws {
        synchronizedPurchases = true
    }

    /// 준비된 검증 앱 거래 반환
    func currentVerifiedAppTransaction() async throws -> VerifiedAppTransaction {
        appTransactionRequestCount += 1

        return VerifiedAppTransaction(
            signedAppTransaction: "signed-app-transaction",
            appTransactionIdentifier: "app-transaction-identifier",
            environment: .sandbox
        )
    }

    /// 현재 권한을 제공하는 검증 거래 목록 반환
    func currentVerifiedEntitlementTransactions() async -> [VerifiedStoreTransaction] {
        verifiedTransactions
    }

    /// 준비된 미완료 검증 거래 목록 반환
    func unfinishedVerifiedTransactions() async -> [VerifiedStoreTransaction] {
        unfinishedTransactions
    }

    /// 준비된 전체 검증 거래 목록 반환
    func allVerifiedTransactions() async -> [VerifiedStoreTransaction] {
        verifiedTransactions
    }

    /// 거래 변경 스트림 반환
    nonisolated func verifiedTransactionUpdates() -> AsyncStream<VerifiedStoreTransaction> {
        updates
    }

    /// 검증 거래를 현재 거래와 변경 스트림에 전달
    func sendTransactionUpdate(_ transaction: VerifiedStoreTransaction) {
        verifiedTransactions = [transaction]
        updatesContinuation.yield(transaction)
    }
}

/// StoreKit 거래 종료 기록기
private actor StoreTransactionFinishRecorder {
    /// 거래 종료 여부
    private(set) var finished = false

    /// 거래 종료 기록
    func recordFinish() {
        finished = true
    }
}

/// 순서대로 고객 정보를 반환하는 서버 요청 기록기
private actor SequentialPurchasesServerClientSpy: PurchasesServerClientProtocol {
    /// 순서대로 반환할 고객 정보
    private let customerInfos: [CustomerInfo]

    /// 네트워크 실패 전 성공 응답 수
    private let successfulResponseCountBeforeFailure: Int?

    /// 수신한 동기화 요청 목록
    private var payloads = [SignedPurchasesPayload]()

    /// 수신한 요청 수
    var requestCount: Int {
        payloads.count
    }

    /// 순차 고객 정보 서버 요청 기록기 생성
    init(
        customerInfos: [CustomerInfo],
        successfulResponseCountBeforeFailure: Int? = nil
    ) {
        self.customerInfos = customerInfos
        self.successfulResponseCountBeforeFailure = successfulResponseCountBeforeFailure
    }

    /// 요청 순서에 맞는 고객 정보 반환
    func synchronizeCustomer(with payload: SignedPurchasesPayload) async throws -> CustomerInfo {
        payloads.append(payload)

        if let successfulResponseCountBeforeFailure,
           payloads.count > successfulResponseCountBeforeFailure {
            throw URLError(.timedOut)
        }

        let customerInfoIndex = min(payloads.count - 1, customerInfos.count - 1)
        return customerInfos[customerInfoIndex]
    }

    /// 마지막으로 수신한 동기화 요청 반환
    func lastPayload() -> SignedPurchasesPayload? {
        payloads.last
    }
}

/// 테스트용 StoreKit 구매 정보 제공 서비스
private struct StoreKitServiceStub: StoreKitServiceProtocol {
    /// 준비된 검증 거래 목록
    let verifiedTransactions: [VerifiedStoreTransaction]

    /// 준비된 검증 앱 거래
    let verifiedAppTransaction: VerifiedAppTransaction?

    /// 테스트용 StoreKit 구매 정보 제공 서비스 생성
    init(
        verifiedTransactions: [VerifiedStoreTransaction] = [],
        appTransactionIdentifier: String? = "app-transaction-identifier"
    ) {
        self.verifiedTransactions = verifiedTransactions
        self.verifiedAppTransaction = appTransactionIdentifier.map { appTransactionIdentifier in
            VerifiedAppTransaction(
                signedAppTransaction: "signed-app-transaction",
                appTransactionIdentifier: appTransactionIdentifier,
                environment: .sandbox
            )
        }
    }

    /// 테스트에서 사용하지 않는 상품 목록 조회
    func products(for productIdentifiers: [String]) async throws -> [Product] {
        []
    }

    /// 테스트에서 사용하지 않는 상품 구매
    func purchase(
        _ product: Product,
        appAccountToken: UUID?
    ) async throws -> StoreKitPurchaseResult {
        fatalError("이 테스트에서는 상품 구매를 호출하지 않습니다.")
    }

    /// 테스트 구매 내역 동기화
    func synchronizePurchases() async throws { }

    /// 준비된 검증 앱 거래 반환
    func currentVerifiedAppTransaction() async throws -> VerifiedAppTransaction {
        guard let verifiedAppTransaction else {
            throw PurchasesError.unverifiedAppTransaction
        }

        return verifiedAppTransaction
    }

    /// 준비된 현재 권한 거래 목록 반환
    func currentVerifiedEntitlementTransactions() async -> [VerifiedStoreTransaction] {
        verifiedTransactions
    }

    /// 테스트에서 사용하지 않는 미완료 검증 거래 목록 반환
    func unfinishedVerifiedTransactions() async -> [VerifiedStoreTransaction] {
        []
    }

    /// 준비된 전체 검증 거래 목록 반환
    func allVerifiedTransactions() async -> [VerifiedStoreTransaction] {
        verifiedTransactions
    }

    /// 즉시 종료되는 거래 변경 스트림 생성
    func verifiedTransactionUpdates() -> AsyncStream<VerifiedStoreTransaction> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

/// 네트워크 실패를 반환하는 서버 요청 대역
private struct NetworkFailurePurchasesServerClient: PurchasesServerClientProtocol {
    /// 네트워크 시간 초과 오류 반환
    func synchronizeCustomer(with payload: SignedPurchasesPayload) async throws -> CustomerInfo {
        throw URLError(.timedOut)
    }

}

/// 테스트용 Purpl 서버 요청 기록기
private actor PurchasesServerClientSpy: PurchasesServerClientProtocol {
    /// 준비된 고객 정보
    private let customerInfo: CustomerInfo

    /// 마지막 동기화 요청
    private var synchronizedPayload: SignedPurchasesPayload?

    /// 테스트용 서버 요청 기록기 생성
    init(customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
    }

    /// 전달받은 StoreKit 정보를 기록하고 준비된 고객 정보 반환
    func synchronizeCustomer(with payload: SignedPurchasesPayload) async throws -> CustomerInfo {
        synchronizedPayload = payload
        return customerInfo
    }

    /// 마지막으로 전달받은 StoreKit 정보 조회
    func receivedPayload() -> SignedPurchasesPayload? {
        synchronizedPayload
    }
}
