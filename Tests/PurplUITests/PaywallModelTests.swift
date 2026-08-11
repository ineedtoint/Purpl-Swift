//
//  PaywallModelTests.swift
//  PurplUITests
//
//  Created by Int on 7/28/26.
//

import Foundation
import StoreKit
import SwiftUI
import Testing
@testable import Purpl
@testable import PurplUI

/// 페이월 상태 모델 테스트
@MainActor
struct PaywallModelTests {
    /// 지정한 기본 구매 옵션을 선택하는지 확인
    @Test
    func selectsConfiguredDefaultOption() {
        let configuration = makePaywallConfiguration(
            defaultProductIdentifier: "test.product.yearly"
        )
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )

        #expect(model.selectedOptionIdentifier == "test.product.yearly")
        #expect(model.customerInfoState == .loaded)
    }

    /// 기본 구매 옵션이 없으면 첫 상품을 선택하는지 확인
    @Test
    func selectsFirstOptionWithoutConfiguredDefault() {
        let configuration = makePaywallConfiguration(
            defaultProductIdentifier: nil
        )
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )

        #expect(model.selectedOptionIdentifier == "test.product.monthly")
    }

    /// 사용자 선택을 현재 구매 옵션에 반영하는지 확인
    @Test
    func changesSelectedOption() throws {
        let configuration = makePaywallConfiguration()
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )
        let monthlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.monthly")
        )

        model.select(monthlyProduct)

        #expect(model.selectedOptionIdentifier == "test.product.monthly")
        #expect(model.isSelected(monthlyProduct))
    }

    /// 서버 권한과 StoreKit 상품 보유 상태를 독립적으로 반영하는지 확인
    @Test
    func appliesActiveCustomerEntitlement() throws {
        let configuration = makePaywallConfiguration()
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )
        let yearlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.yearly")
        )
        let monthlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.monthly")
        )

        model.applyCustomerInfo(makeActiveCustomerInfo())

        #expect(model.hasActiveEntitlement)
        #expect(!model.isOwned(yearlyProduct))
        #expect(model.isEntitlementActive(yearlyProduct))
        #expect(model.customerInfoState == .loaded)

        model.applyStoreKitEntitlementProductIdentifiers([
            "test.product.yearly"
        ])

        #expect(model.isOwned(yearlyProduct))
        #expect(model.isSelectedProductOwned)

        model.select(monthlyProduct)

        #expect(!model.isOwned(monthlyProduct))
        #expect(model.isEntitlementActive(monthlyProduct))
        #expect(!model.isSelectedProductOwned)
    }

    /// 구매 완료 후 서버 고객 정보 대기 상태를 만들지 않는지 확인
    @Test
    func doesNotWaitForCustomerInfoAfterCompletedPurchase() throws {
        let configuration = makePaywallConfiguration()
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )
        let monthlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.monthly")
        )
        let yearlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.yearly")
        )

        model.applyPurchaseResult(.completed, catalogProduct: monthlyProduct)

        #expect(!model.isPurchaseAwaitingResolution(monthlyProduct))
        #expect(!model.isPurchaseAwaitingResolution(yearlyProduct))
        #expect(model.purchaseResolutionStates.isEmpty)
    }

    /// 보호자 승인 대기 결과도 같은 권한의 재구매를 차단하는지 확인
    @Test
    func blocksSameEntitlementWhilePurchaseApprovalIsPending() throws {
        let configuration = makePaywallConfiguration()
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )
        let monthlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.monthly")
        )
        let yearlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.yearly")
        )

        model.applyPurchaseResult(.pending, catalogProduct: monthlyProduct)

        #expect(
            model.purchaseResolutionState(for: monthlyProduct) == .pendingApproval
        )
        #expect(
            model.purchaseResolutionState(for: yearlyProduct) == .pendingApproval
        )
        #expect(model.isPurchaseButtonDisabled)
    }

    /// 구매 완료 전 서버 고객 정보가 있어도 대기 상태를 만들지 않는지 확인
    @Test
    func doesNotWaitWhenPurchaseIsAlreadyReflected() throws {
        let configuration = makePaywallConfiguration()
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )
        let monthlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.monthly")
        )

        model.applyCustomerInfo(
            makeActiveCustomerInfo(productIdentifier: "test.product.monthly")
        )
        model.applyPurchaseResult(.completed, catalogProduct: monthlyProduct)

        #expect(model.purchaseResolutionStates.isEmpty)
        #expect(!model.isPurchaseAwaitingResolution(monthlyProduct))
    }

    /// 서버 고객 정보가 StoreKit 상품 보유 상태를 덮어쓰지 않는지 확인
    @Test
    func doesNotDeriveOwnedProductFromCustomerInfo() throws {
        let configuration = makePaywallConfiguration()
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )
        let monthlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.monthly")
        )

        model.applyStoreKitEntitlementProductIdentifiers([
            "test.product.monthly"
        ])
        model.applyCustomerInfo(makeActiveCustomerInfo(productIdentifier: nil))

        #expect(model.isOwned(monthlyProduct))
    }

    /// 검증 시각만 바뀐 동일 권한 정보로 승인 대기를 해제하지 않는지 확인
    @Test
    func keepsPendingApprovalWhenOnlyVerificationDateChanges() throws {
        let configuration = makePaywallConfiguration()
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )
        let monthlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.monthly")
        )

        model.applyCustomerInfo(makeActiveCustomerInfo())
        model.applyPurchaseResult(.pending, catalogProduct: monthlyProduct)
        model.applyCustomerInfo(
            makeActiveCustomerInfo(
                lastVerifiedAt: Date(timeIntervalSince1970: 1)
            )
        )

        #expect(
            model.purchaseResolutionState(for: monthlyProduct) == .pendingApproval
        )
    }

    /// 고객 정보 조회 상태를 독립적으로 추적하는지 확인
    @Test
    func tracksCustomerInfoLoadingState() async throws {
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(delaysOperations: true)
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        #expect(model.customerInfoState == .idle)

        let refreshTask = Task {
            try await model.refreshCustomerInfo()
        }
        while model.customerInfoState != .loading {
            await Task.yield()
        }

        try await refreshTask.value

        #expect(model.customerInfoState == .loaded)
    }

    /// 원격 페이월 구성을 상품 조회 전에 모델에 반영하는지 확인
    @Test
    func preparesRemotePaywallConfiguration() async {
        let remotePurchaseConfiguration = PurchaseConfiguration(
            entitlements: [PurchaseEntitlement(identifier: "access")],
            products: [
                PurchaseProduct(
                    productIdentifier: "test.product.monthly",
                    entitlementIdentifier: "access"
                )
            ]
        )
        let resolvedConfiguration = ResolvedPaywallConfiguration(
            paywallIdentifier: "standard",
            purchaseConfiguration: remotePurchaseConfiguration,
            catalog: PurchaseCatalog(
                identifier: "standard",
                products: remotePurchaseConfiguration.products
            ),
            defaultProductIdentifier: "test.product.monthly",
            updatedAt: Date(timeIntervalSince1970: 1_786_412_800)
        )
        let purchaseService = PaywallPurchaseServiceStub(
            remotePaywallConfiguration: resolvedConfiguration
        )
        let placeholderPurchaseConfiguration = PurchaseConfiguration(products: [])
        let model = PaywallModel(
            purchaseConfiguration: placeholderPurchaseConfiguration,
            configuration: PaywallConfiguration(
                catalog: PurchaseCatalog(
                    identifier: "standard",
                    productIdentifiers: []
                )
            ),
            remotePaywallIdentifier: "standard",
            purchaseService: purchaseService
        )

        await model.prepare()

        #expect(model.configuration.catalog.productIdentifiers == [
            "test.product.monthly"
        ])
        #expect(
            model.purchaseConfiguration.product(for: "test.product.monthly") != nil
        )
        #expect(model.isLoadingConfiguration == false)
        #expect(model.configurationError == nil)
        #expect(await purchaseService.productRequestCount() == 1)
    }

    /// 서버 고객 정보와 무관하게 StoreKit 상태만으로 구매 가능 여부를 결정하는지 확인
    @Test
    func determinesPurchaseAvailabilityFromStoreKitState() {
        #expect(!PaywallPurchaseAvailabilityPolicy.isPurchaseButtonDisabled(
            hasSelectedStoreProduct: true,
            isSelectedProductOwned: false,
            isLoadingProducts: false,
            isProcessing: false,
            isAwaitingPurchaseResolution: false
        ))
        #expect(PaywallPurchaseAvailabilityPolicy.isPurchaseButtonDisabled(
            hasSelectedStoreProduct: false,
            isSelectedProductOwned: false,
            isLoadingProducts: false,
            isProcessing: false,
            isAwaitingPurchaseResolution: false
        ))
        #expect(PaywallPurchaseAvailabilityPolicy.isPurchaseButtonDisabled(
            hasSelectedStoreProduct: true,
            isSelectedProductOwned: false,
            isLoadingProducts: true,
            isProcessing: false,
            isAwaitingPurchaseResolution: false
        ))
        #expect(PaywallPurchaseAvailabilityPolicy.isPurchaseButtonDisabled(
            hasSelectedStoreProduct: true,
            isSelectedProductOwned: false,
            isLoadingProducts: false,
            isProcessing: true,
            isAwaitingPurchaseResolution: false
        ))
        #expect(PaywallPurchaseAvailabilityPolicy.isPurchaseButtonDisabled(
            hasSelectedStoreProduct: true,
            isSelectedProductOwned: false,
            isLoadingProducts: false,
            isProcessing: false,
            isAwaitingPurchaseResolution: true
        ))
        #expect(PaywallPurchaseAvailabilityPolicy.isPurchaseButtonDisabled(
            hasSelectedStoreProduct: true,
            isSelectedProductOwned: true,
            isLoadingProducts: false,
            isProcessing: false,
            isAwaitingPurchaseResolution: false
        ))
    }

    /// StoreKit 보유 상품을 복원하면 성공 안내를 표시하는지 확인
    @Test
    func reportsSuccessfulRestore() async {
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(
            entitlementProductIdentifiers: ["test.product.yearly"]
        )
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        let didSynchronize = await model.restorePurchases()

        #expect(didSynchronize == true)
        #expect(model.restoreNotice == .succeeded)
        #expect(model.customerInfoState == .idle)
        #expect(model.activeProductIdentifiers == ["test.product.yearly"])
        #expect(!model.isRestoring)
    }

    /// StoreKit 보유 상품이 없으면 복원 내역 없음 안내를 표시하는지 확인
    @Test
    func reportsRestoreWithoutEntitlement() async {
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub()
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        let didSynchronize = await model.restorePurchases()

        #expect(didSynchronize == true)
        #expect(model.restoreNotice == .notFound)
        #expect(model.customerInfoState == .idle)
        #expect(!model.isRestoring)
    }

    /// 구매 복원에 실패하면 실패 안내를 표시하는지 확인
    @Test
    func reportsFailedRestore() async {
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(restoreShouldFail: true)
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        let didSynchronize = await model.restorePurchases()

        #expect(didSynchronize == false)
        #expect(model.restoreNotice == .failed)
        #expect(model.customerInfoState == .idle)
        #expect(!model.isRestoring)
    }

    /// 상품 조회가 끝나면 로딩 상태를 사용 불가 상태로 변경하는지 확인
    @Test
    func changesProductContextAfterLoadingCompletes() async throws {
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub()
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )
        let monthlyProduct = try #require(
            makePurchaseConfiguration().product(for: "test.product.monthly")
        )

        #expect(model.context(for: monthlyProduct).availability == .loading)

        await model.loadProductsIfNeeded()

        #expect(model.context(for: monthlyProduct).availability == .unavailable)
        #expect(model.visibleCatalogProducts.isEmpty)
    }

    /// 동시에 요청한 상품 조회를 한 번만 실행하는지 확인
    @Test
    func preventsConcurrentProductLoading() async {
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(delaysOperations: true)
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        let firstLoadingTask = Task {
            await model.loadProductsIfNeeded()
        }
        while !model.isLoadingProducts {
            await Task.yield()
        }

        await model.loadProductsIfNeeded()
        await firstLoadingTask.value

        #expect(await purchaseService.productRequestCount() == 1)
    }

    /// 동시에 요청한 구매 복원을 한 번만 실행하는지 확인
    @Test
    func preventsConcurrentRestore() async {
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(delaysOperations: true)
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        let firstRestoreTask = Task {
            await model.restorePurchases()
        }
        while !model.isRestoring {
            await Task.yield()
        }

        let secondCustomerInfo = await model.restorePurchases()
        _ = await firstRestoreTask.value

        #expect(secondCustomerInfo == nil)
        #expect(await purchaseService.restoreRequestCount() == 1)
    }

    /// 고객 정보 조회와 무관하게 StoreKit 구매 복원을 시작하는지 확인
    @Test
    func preventsRestoreDuringCustomerInfoRefresh() async throws {
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(delaysOperations: true)
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        let refreshTask = Task {
            try await model.refreshCustomerInfo()
        }
        while model.customerInfoState != .loading {
            await Task.yield()
        }

        let didSynchronize = await model.restorePurchases()
        try await refreshTask.value

        #expect(didSynchronize == true)
        #expect(await purchaseService.restoreRequestCount() == 1)
        #expect(model.customerInfoState == .loaded)
    }

    /// 취소된 준비 작업과 새 준비 작업이 같은 상품 조회를 안전하게 공유하는지 확인
    @Test
    func continuesProductLoadingAcrossCancelledPreparation() async {
        let firstApplicationAccountIdentifier = UUID(
            uuidString: "3720ED82-6650-4BE1-B1D3-E26DA837EBF7"
        )!
        let secondApplicationAccountIdentifier = UUID(
            uuidString: "5D9AE280-9423-47EF-BF53-102FA5F1A79D"
        )!
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(delaysOperations: true)
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        let firstPreparationTask = Task {
            await model.prepare(
                applicationAccountIdentifier: firstApplicationAccountIdentifier
            )
        }
        while !model.isLoadingProducts {
            await Task.yield()
        }
        firstPreparationTask.cancel()

        let secondPreparationTask = Task {
            await model.prepare(
                applicationAccountIdentifier: secondApplicationAccountIdentifier
            )
        }
        await secondPreparationTask.value
        await firstPreparationTask.value

        #expect(await purchaseService.productRequestCount() == 1)
        #expect(model.hasCompletedProductLoading)
        #expect(!model.isLoadingProducts)
        #expect(model.customerInfoState == .loaded)
    }

    /// 같은 계정의 취소된 준비 작업과 새 준비 작업이 고객 조회를 공유하는지 확인
    @Test
    func continuesCustomerInfoRefreshAcrossCancelledPreparation() async {
        let applicationAccountIdentifier = UUID(
            uuidString: "81800CEB-A47B-42BE-9EDF-34E7FB02EB77"
        )!
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(delaysOperations: true)
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        let firstPreparationTask = Task {
            await model.prepare(
                applicationAccountIdentifier: applicationAccountIdentifier
            )
        }
        while model.customerInfoState != .loading {
            await Task.yield()
        }
        firstPreparationTask.cancel()

        let secondPreparationTask = Task {
            await model.prepare(
                applicationAccountIdentifier: applicationAccountIdentifier
            )
        }
        await secondPreparationTask.value
        await firstPreparationTask.value

        #expect(await purchaseService.customerInfoRequestCount() == 1)
        #expect(model.customerInfoState == .loaded)
    }

    /// 앱 계정 변경 후 고객 정보 조회가 실패하면 이전 권한을 제거하는지 확인
    @Test
    func clearsPreviousEntitlementWhenAccountChanges() async throws {
        let firstApplicationAccountIdentifier = UUID(
            uuidString: "12584371-8DDA-438D-A791-413F7A86518F"
        )!
        let secondApplicationAccountIdentifier = UUID(
            uuidString: "DF7E9AF8-F34D-4D94-978D-F9BD3D49C2B7"
        )!
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(
            restoredCustomerInfo: makeActiveCustomerInfo(),
            customerInfoShouldFailAfterFirstRequest: true
        )
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        try await model.refreshCustomerInfo(
            applicationAccountIdentifier: firstApplicationAccountIdentifier
        )
        #expect(model.hasActiveEntitlement)

        await #expect(throws: PaywallTestError.self) {
            try await model.refreshCustomerInfo(
                applicationAccountIdentifier: secondApplicationAccountIdentifier
            )
        }

        #expect(!model.hasActiveEntitlement)
        #expect(model.activeProductIdentifiers.isEmpty)
        #expect(model.activeEntitlementIdentifiers.isEmpty)
        #expect(model.customerInfoState == .failed)
    }

    /// 준비 시작 즉시 이전 앱 계정의 권한 상태를 제거하는지 확인
    @Test
    func clearsPreviousAccountBeforeDelayedPreparationCompletes() async throws {
        let firstApplicationAccountIdentifier = UUID(
            uuidString: "C42B33A8-B5A3-4236-B033-88D46BF99075"
        )!
        let secondApplicationAccountIdentifier = UUID(
            uuidString: "01DA0B4B-69ED-415E-A28A-3119D04EC8CB"
        )!
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(
            restoredCustomerInfo: makeActiveCustomerInfo(),
            delaysOperations: true
        )
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        try await model.refreshCustomerInfo(
            applicationAccountIdentifier: firstApplicationAccountIdentifier
        )
        #expect(model.hasActiveEntitlement)

        let preparationTask = Task {
            await model.prepare(
                applicationAccountIdentifier: secondApplicationAccountIdentifier
            )
        }
        while model.customerInfoState != .loading {
            await Task.yield()
        }

        #expect(!model.hasActiveEntitlement)
        #expect(model.activeProductIdentifiers.isEmpty)

        await preparationTask.value
    }

    /// 이전 계정 복원 중 새 계정 준비가 고객 정보를 반드시 조회하는지 확인
    @Test
    func preparesNewAccountDuringPreviousAccountRestore() async throws {
        let firstApplicationAccountIdentifier = UUID(
            uuidString: "E67150BC-A6D2-4F08-9F9F-4320044D5DE9"
        )!
        let secondApplicationAccountIdentifier = UUID(
            uuidString: "F0A36400-3571-4693-96F5-4401B8FB43CC"
        )!
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(
            restoredCustomerInfo: makeActiveCustomerInfo(),
            delaysOperations: true
        )
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        try await model.refreshCustomerInfo(
            applicationAccountIdentifier: firstApplicationAccountIdentifier
        )
        let restoreTask = Task {
            await model.restorePurchases(
                applicationAccountIdentifier: firstApplicationAccountIdentifier
            )
        }
        while !model.isRestoring {
            await Task.yield()
        }

        await model.prepare(
            applicationAccountIdentifier: secondApplicationAccountIdentifier
        )
        let restoredCustomerInfo = await restoreTask.value

        #expect(restoredCustomerInfo == nil)
        #expect(await purchaseService.customerInfoRequestCount() == 2)
        #expect(model.customerInfoState == .loaded)
        #expect(model.hasActiveEntitlement)
    }

    /// 다른 앱 계정 토큰으로 구매를 요청하면 기존 권한 상태를 사용하지 않는지 확인
    @Test
    func resetsCustomerStateForDifferentPurchaseAccountToken() async throws {
        let firstApplicationAccountIdentifier = UUID(
            uuidString: "8516507E-9CFD-43F4-A747-0F7CC7E25C62"
        )!
        let secondApplicationAccountIdentifier = UUID(
            uuidString: "85F8BE05-EB56-4986-A66E-02A552024F44"
        )!
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(
            restoredCustomerInfo: makeActiveCustomerInfo()
        )
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        try await model.refreshCustomerInfo(
            applicationAccountIdentifier: firstApplicationAccountIdentifier
        )
        #expect(model.hasActiveEntitlement)

        let purchaseResult = try await model.purchaseSelectedProduct(
            appAccountToken: secondApplicationAccountIdentifier
        )

        #expect(purchaseResult == nil)
        #expect(!model.hasActiveEntitlement)
        #expect(model.customerInfoState == .idle)
    }

    /// 공유 스트림 변경을 현재 앱 계정 고객 정보로 다시 확인하는지 검증
    @Test
    func revalidatesStreamedCustomerInfoForCurrentAccount() async throws {
        let applicationAccountIdentifier = UUID(
            uuidString: "3E272807-A473-4744-90B7-F27CDB350199"
        )!
        let configuration = makePaywallConfiguration()
        let purchaseService = PaywallPurchaseServiceStub(
            restoredCustomerInfo: makeActiveCustomerInfo(),
            streamedCustomerInfo: CustomerInfo(
                customerIdentifier: "different-customer",
                entitlements: []
            )
        )
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        try await model.refreshCustomerInfo(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
        while await purchaseService.customerInfoRequestCount() < 2 {
            await Task.yield()
        }
        while model.customerInfoState != .loaded {
            await Task.yield()
        }

        #expect(model.hasActiveEntitlement)
        #expect(model.activeProductIdentifiers.isEmpty)
        #expect(model.customerInfoState == .loaded)
        model.stopObservingCustomerInfoUpdates()
    }

    /// 기존 조회 중 도착한 스트림 변경을 후속 조회로 다시 확인하는지 검증
    @Test
    func refreshesAgainAfterStreamUpdateDuringExistingRefresh() async throws {
        let applicationAccountIdentifier = UUID(
            uuidString: "69EB1850-5D9E-4420-B454-EE2E9FC6BB61"
        )!
        let configuration = makePaywallConfiguration()
        let initialCustomerInfo = makeActiveCustomerInfo()
        let updatedCustomerInfo = makeActiveCustomerInfo(
            productIdentifier: "test.product.monthly"
        )
        let purchaseService = PaywallCustomerInfoRaceStub(
            initialCustomerInfo: initialCustomerInfo,
            updatedCustomerInfo: updatedCustomerInfo
        )
        let model = PaywallModel(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration,
            purchaseService: purchaseService
        )

        try await model.refreshCustomerInfo(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
        let refreshTask = Task {
            try await model.refreshCustomerInfo(
                applicationAccountIdentifier: applicationAccountIdentifier
            )
        }
        while model.customerInfoState != .loading {
            await Task.yield()
        }

        purchaseService.sendCustomerInfo(updatedCustomerInfo)
        try await refreshTask.value
        while await purchaseService.customerInfoRequestCount() < 3 ||
                model.customerInfoState != .loaded {
            await Task.yield()
        }

        #expect(model.hasActiveEntitlement)
        #expect(model.activeProductIdentifiers.isEmpty)
        purchaseService.finishCustomerInfoStream()
        model.stopObservingCustomerInfoUpdates()
    }

    /// 프리뷰 모델로 기본 카드와 사용자 정의 카드 페이월을 생성할 수 있는지 확인
    @Test
    func createsDefaultAndCustomPaywallViewsWithPreviewModel() {
        let configuration = makePaywallConfiguration()
        let model = PaywallModel.preview(
            purchaseConfiguration: makePurchaseConfiguration(),
            configuration: configuration
        )
        let style = PaywallStyle(
            productCardBackgroundStyle: Color.primary.opacity(0.08)
        )

        _ = PaywallView(
            model: model,
            style: style
        ) {
            Text(verbatim: "Marketing")
        }

        _ = PaywallView(
            model: model,
            marketingContent: {
                Text(verbatim: "Marketing")
            },
            productContent: { context in
                Text(verbatim: context.catalogProduct.id)
            }
        )
    }

    /// 테스트용 페이월 구성 생성
    /// - Parameters:
    ///   - defaultProductIdentifier: 기본 선택 구매 옵션 식별자
    /// - Returns: 월간과 연간 상품을 포함한 페이월 구성
    private func makePaywallConfiguration(
        defaultProductIdentifier: String? = "test.product.yearly"
    ) -> PaywallConfiguration {
        let purchaseConfiguration = makePurchaseConfiguration()

        return PaywallConfiguration(
            catalog: PurchaseCatalog(
                identifier: "standard",
                products: purchaseConfiguration.products
            ),
            defaultProductIdentifier: defaultProductIdentifier,
            autoRenewalNoticeResource: nil,
            privacyPolicyURL: nil,
            termsOfServiceURL: nil
        )
    }

    /// 테스트용 앱 전체 구매 구성 생성
    /// - Returns: 월간과 연간 상품 및 연결 권한을 포함한 구매 구성
    private func makePurchaseConfiguration() -> PurchaseConfiguration {
        PurchaseConfiguration(
            entitlements: [
                PurchaseEntitlement(
                    identifier: "access",
                    titleResource: LocalizedStringResource(
                        "test.access.title",
                        defaultValue: "Access"
                    )
                )
            ],
            products: [
                makePurchaseProduct(productIdentifier: "test.product.monthly"),
                makePurchaseProduct(productIdentifier: "test.product.yearly")
            ]
        )
    }

    /// 테스트용 구매 상품 생성
    /// - Parameter productIdentifier: StoreKit 상품 식별자
    /// - Returns: 테스트용 구매 상품
    private func makePurchaseProduct(
        productIdentifier: String
    ) -> PurchaseProduct {
        PurchaseProduct(
            productIdentifier: productIdentifier,
            entitlementIdentifier: "access",
            titleResource: LocalizedStringResource(
                "test.product.title",
                defaultValue: "Product"
            ),
            descriptionResource: LocalizedStringResource(
                "test.product.description",
                defaultValue: "Product description"
            )
        )
    }

    /// 테스트용 활성 고객 정보 생성
    /// - Parameter productIdentifier: 권한을 제공한 StoreKit 상품 식별자
    /// - Parameter lastVerifiedAt: 고객 권한을 마지막으로 검증한 시각
    /// - Returns: 지정한 상품으로 구매 권한이 활성화된 고객 정보
    private func makeActiveCustomerInfo(
        productIdentifier: String? = "test.product.yearly",
        lastVerifiedAt: Date = Date(timeIntervalSince1970: 0)
    ) -> CustomerInfo {
        CustomerInfo(
            customerIdentifier: "customer",
            entitlements: [
                CustomerEntitlement(
                    identifier: "access",
                    displayName: "Access",
                    productIdentifier: productIdentifier,
                    environment: .sandbox,
                    status: .active,
                    active: true,
                    startsAt: nil,
                    expiresAt: nil,
                    revokedAt: nil,
                    lastVerifiedAt: lastVerifiedAt
                )
            ]
        )
    }
}

/// 페이월 테스트 오류
private enum PaywallTestError: Error {
    /// 테스트 실패
    case failure
}

/// 고객 정보 조회와 스트림 변경 순서 경합 테스트 대체 객체
private final class PaywallCustomerInfoRaceStub: PaywallPurchaseServiceProtocol {
    /// 고객 정보 스트림
    let customerInfoStream: AsyncStream<CustomerInfo>

    /// 고객 정보 스트림 전달기
    private let customerInfoContinuation: AsyncStream<CustomerInfo>.Continuation

    /// 순서별 고객 정보 기록기
    private let recorder: PaywallCustomerInfoRaceRecorder

    /// 고객 정보 조회와 스트림 변경 순서 경합 테스트 대체 객체 생성
    init(
        initialCustomerInfo: CustomerInfo,
        updatedCustomerInfo: CustomerInfo
    ) {
        let streamPair = AsyncStream<CustomerInfo>.makeStream()
        customerInfoStream = streamPair.stream
        customerInfoContinuation = streamPair.continuation
        recorder = PaywallCustomerInfoRaceRecorder(
            initialCustomerInfo: initialCustomerInfo,
            updatedCustomerInfo: updatedCustomerInfo
        )
    }

    /// 빈 StoreKit 상품 목록 반환
    /// - Parameter productIdentifiers: 조회할 StoreKit 상품 식별자 목록
    /// - Returns: 빈 StoreKit 상품 목록
    func products(for productIdentifiers: [String]) async throws -> [Product] {
        []
    }

    /// 빈 StoreKit 권한 상품 식별자 목록 반환
    /// - Returns: 빈 상품 식별자 목록
    func currentEntitlementProductIdentifiers() async -> Set<String> {
        []
    }

    /// 요청 순서에 맞는 테스트용 고객 정보 반환
    /// - Parameter applicationAccountIdentifier: 현재 앱 사용자를 연결할 선택 UUID
    /// - Returns: 요청 순서에 맞는 고객 정보
    func customerInfo(
        applicationAccountIdentifier: UUID?
    ) async throws -> CustomerInfo {
        await recorder.nextCustomerInfo()
    }

    /// 테스트용 구매 취소 결과 반환
    /// - Parameters:
    ///   - product: 구매할 StoreKit 상품
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    /// - Returns: 구매 취소 결과
    func purchase(
        _ product: Product,
        appAccountToken: UUID?
    ) async throws -> PurchaseResult {
        .cancelled
    }

    /// 테스트용 App Store 구매 내역 동기화
    func synchronizePurchases() async throws {
    }

    /// 고객 정보 스트림 변경 전달
    /// - Parameter customerInfo: 스트림에 전달할 고객 정보
    func sendCustomerInfo(_ customerInfo: CustomerInfo) {
        customerInfoContinuation.yield(customerInfo)
    }

    /// 고객 정보 스트림 종료
    func finishCustomerInfoStream() {
        customerInfoContinuation.finish()
    }

    /// 고객 정보 요청 횟수 반환
    /// - Returns: 기록된 고객 정보 요청 횟수
    func customerInfoRequestCount() async -> Int {
        await recorder.customerInfoRequestCount()
    }
}

/// 고객 정보 조회와 스트림 변경 순서 경합 기록기
private actor PaywallCustomerInfoRaceRecorder {
    /// 처음 두 요청에 반환할 고객 정보
    private let firstCustomerInfo: CustomerInfo

    /// 세 번째 요청부터 반환할 고객 정보
    private let laterCustomerInfo: CustomerInfo

    /// 고객 정보 요청 횟수
    private var requests = 0

    /// 고객 정보 조회와 스트림 변경 순서 경합 기록기 생성
    init(
        initialCustomerInfo: CustomerInfo,
        updatedCustomerInfo: CustomerInfo
    ) {
        firstCustomerInfo = initialCustomerInfo
        laterCustomerInfo = updatedCustomerInfo
    }

    /// 요청 순서에 맞는 고객 정보 반환
    /// - Returns: 처음 두 요청은 초기 정보, 이후 요청은 변경 정보
    func nextCustomerInfo() async -> CustomerInfo {
        requests += 1
        let requestCount = requests

        if requestCount == 2 {
            try? await Task.sleep(for: .milliseconds(50))
        }

        return requestCount < 3 ? firstCustomerInfo : laterCustomerInfo
    }

    /// 초기 고객 정보 반환
    /// - Returns: 처음 두 요청에 사용하는 고객 정보
    func initialCustomerInfo() -> CustomerInfo {
        firstCustomerInfo
    }

    /// 고객 정보 요청 횟수 반환
    /// - Returns: 기록된 고객 정보 요청 횟수
    func customerInfoRequestCount() -> Int {
        requests
    }
}

/// 테스트용 Purpl 기능 대체 객체
private final class PaywallPurchaseServiceStub: PaywallPurchaseServiceProtocol {
    /// 원격 페이월 조회에서 반환할 해석된 구성
    private let remotePaywallConfiguration: ResolvedPaywallConfiguration?

    /// 복원 후 반환할 고객 정보
    private let restoredCustomerInfo: CustomerInfo

    /// StoreKit이 현재 권한으로 반환할 상품 식별자 목록
    private let entitlementProductIdentifiers: Set<String>

    /// 구매 복원 실패 여부
    private let restoreShouldFail: Bool

    /// 비동기 작업 지연 여부
    private let delaysOperations: Bool

    /// 두 번째 고객 정보 요청부터 실패할지 여부
    private let customerInfoShouldFailAfterFirstRequest: Bool

    /// 고객 정보 스트림에서 전달할 선택 고객 정보
    private let streamedCustomerInfo: CustomerInfo?

    /// 요청 횟수 기록기
    private let requestRecorder = PaywallRequestRecorder()

    /// 종료된 고객 정보 스트림
    var customerInfoStream: AsyncStream<CustomerInfo> {
        let streamedCustomerInfo = streamedCustomerInfo
        return AsyncStream { continuation in
            if let streamedCustomerInfo {
                continuation.yield(streamedCustomerInfo)
            }
            continuation.finish()
        }
    }

    /// 테스트용 Purpl 기능 대체 객체 생성
    init(
        remotePaywallConfiguration: ResolvedPaywallConfiguration? = nil,
        restoredCustomerInfo: CustomerInfo = CustomerInfo(
            customerIdentifier: "customer",
            entitlements: []
        ),
        entitlementProductIdentifiers: Set<String> = [],
        restoreShouldFail: Bool = false,
        delaysOperations: Bool = false,
        customerInfoShouldFailAfterFirstRequest: Bool = false,
        streamedCustomerInfo: CustomerInfo? = nil
    ) {
        self.remotePaywallConfiguration = remotePaywallConfiguration
        self.restoredCustomerInfo = restoredCustomerInfo
        self.entitlementProductIdentifiers = entitlementProductIdentifiers
        self.restoreShouldFail = restoreShouldFail
        self.delaysOperations = delaysOperations
        self.customerInfoShouldFailAfterFirstRequest =
            customerInfoShouldFailAfterFirstRequest
        self.streamedCustomerInfo = streamedCustomerInfo
    }

    /// 테스트용 원격 페이월 구매 구성 반환
    /// - Parameter paywallIdentifier: 조회할 페이월 식별자
    /// - Returns: 준비된 원격 구매 구성
    func paywallConfiguration(
        for paywallIdentifier: String
    ) async throws -> ResolvedPaywallConfiguration {
        guard
            let remotePaywallConfiguration,
            remotePaywallConfiguration.paywallIdentifier == paywallIdentifier
        else {
            throw PurchasesError.invalidServerResponse
        }

        return remotePaywallConfiguration
    }

    /// 빈 StoreKit 상품 목록 반환
    /// - Parameter productIdentifiers: 조회할 StoreKit 상품 식별자 목록
    /// - Returns: 빈 StoreKit 상품 목록
    func products(for productIdentifiers: [String]) async throws -> [Product] {
        await requestRecorder.recordProductRequest()
        if delaysOperations {
            try await Task.sleep(for: .milliseconds(50))
        }

        return []
    }

    /// 테스트용 StoreKit 권한 상품 식별자 목록 반환
    /// - Returns: 설정한 현재 권한 상품 식별자 목록
    func currentEntitlementProductIdentifiers() async -> Set<String> {
        entitlementProductIdentifiers
    }

    /// 테스트용 고객 정보 반환
    /// - Parameter applicationAccountIdentifier: 현재 앱 사용자를 연결할 선택 UUID
    /// - Returns: 테스트용 고객 정보
    func customerInfo(
        applicationAccountIdentifier: UUID?
    ) async throws -> CustomerInfo {
        let requestCount = await requestRecorder.recordCustomerInfoRequest()
        if customerInfoShouldFailAfterFirstRequest && requestCount > 1 {
            throw PaywallTestError.failure
        }
        if delaysOperations {
            try await Task.sleep(for: .milliseconds(50))
        }

        return restoredCustomerInfo
    }

    /// 테스트용 구매 취소 결과 반환
    /// - Parameters:
    ///   - product: 구매할 StoreKit 상품
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    /// - Returns: 구매 취소 결과
    func purchase(
        _ product: Product,
        appAccountToken: UUID?
    ) async throws -> PurchaseResult {
        .cancelled
    }

    /// 테스트 설정에 따른 App Store 구매 내역 동기화
    func synchronizePurchases() async throws {
        await requestRecorder.recordRestoreRequest()
        if delaysOperations {
            try await Task.sleep(for: .milliseconds(50))
        }
        if restoreShouldFail {
            throw PaywallTestError.failure
        }
    }

    /// StoreKit 상품 조회 요청 횟수 반환
    /// - Returns: 기록된 StoreKit 상품 조회 요청 횟수
    func productRequestCount() async -> Int {
        await requestRecorder.productRequestCount()
    }

    /// 구매 복원 요청 횟수 반환
    /// - Returns: 기록된 구매 복원 요청 횟수
    func restoreRequestCount() async -> Int {
        await requestRecorder.restoreRequestCount()
    }

    /// 고객 정보 요청 횟수 반환
    /// - Returns: 기록된 고객 정보 요청 횟수
    func customerInfoRequestCount() async -> Int {
        await requestRecorder.customerInfoRequestCount()
    }
}

/// 페이월 테스트 요청 기록기
private actor PaywallRequestRecorder {
    /// StoreKit 상품 조회 요청 횟수
    private var productRequests = 0

    /// 구매 복원 요청 횟수
    private var restoreRequests = 0

    /// 고객 정보 요청 횟수
    private var customerInfoRequests = 0

    /// StoreKit 상품 조회 요청 기록
    func recordProductRequest() {
        productRequests += 1
    }

    /// 구매 복원 요청 기록
    func recordRestoreRequest() {
        restoreRequests += 1
    }

    /// 고객 정보 요청 기록
    /// - Returns: 기록 후 고객 정보 요청 횟수
    func recordCustomerInfoRequest() -> Int {
        customerInfoRequests += 1
        return customerInfoRequests
    }

    /// StoreKit 상품 조회 요청 횟수 반환
    /// - Returns: 기록된 StoreKit 상품 조회 요청 횟수
    func productRequestCount() -> Int {
        productRequests
    }

    /// 구매 복원 요청 횟수 반환
    /// - Returns: 기록된 구매 복원 요청 횟수
    func restoreRequestCount() -> Int {
        restoreRequests
    }

    /// 고객 정보 요청 횟수 반환
    /// - Returns: 기록된 고객 정보 요청 횟수
    func customerInfoRequestCount() -> Int {
        customerInfoRequests
    }
}
