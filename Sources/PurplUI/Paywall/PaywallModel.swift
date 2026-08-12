//
//  PaywallModel.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import Foundation
import Purpl
import Observation
import StoreKit

/// 페이월 구매 복원 안내
public enum PaywallRestoreNotice: Equatable, Sendable {
    /// 복원 내역 없음
    case notFound

    /// 복원 성공
    case succeeded

    /// 복원 실패
    case failed

    /// 안내 메시지
    public var messageResource: LocalizedStringResource {
        switch self {
        case .notFound:
            LocalizedStringResource(
                "paywall.notice.restoreNotFound",
                bundle: .module,
                comment: "복원할 구매 내역을 찾지 못했습니다."
            )
        case .succeeded:
            LocalizedStringResource(
                "paywall.notice.restoreSucceeded",
                bundle: .module,
                comment: "구매 내역을 복원했습니다."
            )
        case .failed:
            LocalizedStringResource(
                "paywall.notice.restoreFailed",
                bundle: .module,
                comment: "구매 복원에 실패했습니다."
            )
        }
    }
}

/// 페이월 고객 정보 준비 상태
public enum PaywallCustomerInfoState: Equatable, Sendable {
    /// 고객 정보 조회 전
    case idle

    /// 고객 정보 조회 중
    case loading

    /// 고객 정보 조회 완료
    case loaded

    /// 고객 정보 조회 실패
    case failed
}

/// 페이월 구매 결과 확인 대기 상태
public enum PaywallPurchaseResolutionState: Equatable, Sendable {
    /// 보호자 승인 등 StoreKit 구매 완료 대기
    case pendingApproval
}

/// StoreKit 상품 상태를 기준으로 구매 버튼 활성화를 결정하는 정책
enum PaywallPurchaseAvailabilityPolicy {
    /// 구매 버튼 비활성화 여부 반환
    /// - Parameters:
    ///   - hasSelectedStoreProduct: 선택된 StoreKit 상품 존재 여부
    ///   - isSelectedProductOwned: 선택된 StoreKit 상품 보유 여부
    ///   - isLoadingProducts: StoreKit 상품 조회 진행 여부
    ///   - isProcessing: 구매 또는 복원 처리 진행 여부
    ///   - isAwaitingPurchaseResolution: StoreKit 구매 결과 확인 대기 여부
    /// - Returns: StoreKit 구매를 시작할 수 없으면 `true`
    static func isPurchaseButtonDisabled(
        hasSelectedStoreProduct: Bool,
        isSelectedProductOwned: Bool,
        isLoadingProducts: Bool,
        isProcessing: Bool,
        isAwaitingPurchaseResolution: Bool
    ) -> Bool {
        isSelectedProductOwned ||
            isAwaitingPurchaseResolution ||
            isLoadingProducts ||
            isProcessing ||
            !hasSelectedStoreProduct
    }
}

/// 페이월 상태와 구매 동작 모델
@MainActor
@Observable
public final class PaywallModel {
    // MARK: - 구성

    /// 페이월 구성
    public private(set) var configuration: PaywallConfiguration

    /// 페이월 상품을 해석하는 앱 전체 구매 구성
    public private(set) var purchaseConfiguration: PurchaseConfiguration

    /// 원격 페이월 구성 식별자
    private let remotePaywallIdentifier: String?

    /// 원격 페이월 구성 조회 진행 여부
    public private(set) var isLoadingConfiguration = false

    /// 원격 페이월 구성 조회 완료 여부
    private var hasCompletedConfigurationLoading = false

    /// 마지막으로 원격 구성을 불러온 로케일 식별자
    private var loadedConfigurationLocaleIdentifier: String?

    /// 원격 페이월 구성 조회 오류
    public private(set) var configurationError: (any Error)?

    /// 현재 페이월 상품 목록 순서에 맞는 상품 목록
    private var configuredProducts: [PurchaseProduct] {
        configuration.catalog.products(in: purchaseConfiguration)
    }

    // MARK: - 상품 상태

    /// StoreKit 상품 목록
    public private(set) var products: [Product] = []

    /// 상품 조회 진행 여부
    public private(set) var isLoadingProducts = false

    /// 상품 조회 완료 경험 여부
    public private(set) var hasCompletedProductLoading = false

    /// 구매 진행 중인 StoreKit 상품 식별자
    public private(set) var purchasingProductIdentifier: String?

    /// 구매 복원 진행 여부
    public private(set) var isRestoring = false

    /// 구매 복원을 시작한 앱 계정 변경 순번
    private var restoringAccountRevision: Int?

    /// StoreKit 상품 식별자별 구매 결과 확인 대기 상태
    public private(set) var purchaseResolutionStates =
        [String: PaywallPurchaseResolutionState]()

    // MARK: - 권한 상태

    /// 활성 StoreKit 상품 식별자 목록
    public private(set) var activeProductIdentifiers = Set<String>()

    /// 활성 구매 권한 식별자 목록
    public private(set) var activeEntitlementIdentifiers = Set<String>()

    /// 고객 정보 준비 상태
    public private(set) var customerInfoState: PaywallCustomerInfoState = .idle

    /// 현재 카탈로그의 활성 구매 권한 보유 여부
    public var hasActiveEntitlement: Bool {
        configuredProducts.contains { product in
            !product.entitlementIdentifiers.isDisjoint(
                with: activeEntitlementIdentifiers
            )
        }
    }

    /// 현재 카탈로그에서 StoreKit이 보유 중이라고 확인한 상품 존재 여부
    public var hasOwnedCatalogProduct: Bool {
        configuredProducts.contains { product in
            activeProductIdentifiers.contains(product.productIdentifier)
        }
    }

    // MARK: - 선택 상태

    /// 선택된 구매 옵션 식별자
    public private(set) var selectedOptionIdentifier: String?

    /// 선택된 구매 상품
    public var selectedCatalogProduct: PurchaseProduct? {
        purchaseConfiguration.product(for: selectedOptionIdentifier)
    }

    /// 선택된 StoreKit 상품
    public var selectedStoreProduct: Product? {
        guard let selectedCatalogProduct else {
            return nil
        }

        return product(for: selectedCatalogProduct)
    }

    /// 선택된 StoreKit 상품 보유 여부
    public var isSelectedProductOwned: Bool {
        guard let selectedCatalogProduct else {
            return false
        }

        return isOwned(selectedCatalogProduct)
    }

    // MARK: - 화면 상태

    /// 화면에 표시할 구매 상품 목록
    public var visibleCatalogProducts: [PurchaseProduct] {
        PaywallProductVisibilityPolicy.visibleProducts(
            configuredProducts: configuredProducts,
            availableProductIdentifiers: availableProductIdentifiers,
            isLoadingProducts: isLoadingProducts,
            hasCompletedProductLoading: hasCompletedProductLoading,
            showsUnavailablePurchaseOptions: configuration.showsUnavailablePurchaseOptions
        )
    }

    /// 구매 또는 복원 처리 진행 여부
    public var isProcessing: Bool {
        purchasingProductIdentifier != nil || isRestoring
    }

    /// 선택된 상품의 구매 버튼 비활성화 여부
    public var isPurchaseButtonDisabled: Bool {
        PaywallPurchaseAvailabilityPolicy.isPurchaseButtonDisabled(
            hasSelectedStoreProduct: selectedStoreProduct != nil,
            isSelectedProductOwned: isSelectedProductOwned,
            isLoadingProducts: isLoadingProducts,
            isProcessing: isProcessing,
            isAwaitingPurchaseResolution: isSelectedPurchaseAwaitingResolution
        )
    }

    /// 사용자에게 표시할 구매 복원 안내
    public private(set) var restoreNotice: PaywallRestoreNotice?

    // MARK: - 의존성

    /// Purpl 서비스 경계
    private let purchaseService: (any PaywallPurchaseServiceProtocol)?

    /// 프리뷰 상태 여부
    private let isPreviewState: Bool

    // MARK: - 작업

    /// 고객 정보 변경 감시 작업
    @ObservationIgnored
    nonisolated(unsafe) private var customerInfoTask: Task<Void, Never>?

    /// 고객 정보 변경 감시 허용 여부
    private var isCustomerInfoObservationEnabled = false

    /// 현재 계정의 고객 정보 조회 작업
    private var customerInfoRefreshTask: Task<Void, Error>?

    /// 고객 정보 조회 작업의 앱 계정 변경 순번
    private var customerInfoRefreshAccountRevision: Int?

    /// 고객 정보 조회 작업 변경 순번
    private var customerInfoRefreshRevision = 0

    /// 마지막으로 현재 페이월에 반영한 고객 정보
    private var lastAppliedCustomerInfo: CustomerInfo?

    /// 상품 조회 작업
    private var productLoadingTask: Task<Void, Never>?

    /// 상품 조회 작업 변경 순번
    private var productLoadingRevision = 0

    /// 마지막으로 고객 정보를 요청한 앱 계정 식별자
    private var applicationAccountIdentifier: UUID?

    /// 앱 계정 식별자 추적 시작 여부
    private var hasApplicationAccountIdentifier = false

    /// 앱 계정 식별자 변경 순번
    private var applicationAccountRevision = 0

    // MARK: - 생성

    /// 페이월 모델 생성
    ///
    /// 앱 실행 중 `Purchases.configure`를 먼저 호출해야 한다.
    public convenience init(
        configuration: PaywallConfiguration,
        purchases: Purchases = .shared
    ) {
        guard let purchaseConfiguration = purchases.purchaseConfiguration else {
            preconditionFailure(
                "로컬 페이월을 사용하려면 Purchases.configure에 PurchaseConfiguration을 전달해야 합니다."
            )
        }

        self.init(
            purchaseConfiguration: purchaseConfiguration,
            configuration: configuration,
            remotePaywallIdentifier: nil,
            purchaseService: purchases,
            isPreviewState: false
        )
    }

    /// Purpl 원격 페이월 모델 생성
    ///
    /// 앱 실행 중 `Purchases.configure`를 먼저 호출해야 한다.
    public convenience init(
        paywallIdentifier: String,
        purchases: Purchases = .shared
    ) {
        let purchaseConfiguration = PurchaseConfiguration(products: [])

        self.init(
            purchaseConfiguration: purchaseConfiguration,
            configuration: Self.placeholderConfiguration(
                paywallIdentifier: paywallIdentifier
            ),
            remotePaywallIdentifier: paywallIdentifier,
            purchaseService: purchases,
            isPreviewState: false
        )
    }

    /// 내부 의존성을 지정한 페이월 모델 생성
    init(
        purchaseConfiguration: PurchaseConfiguration,
        configuration: PaywallConfiguration,
        remotePaywallIdentifier: String? = nil,
        purchaseService: (any PaywallPurchaseServiceProtocol)?,
        isPreviewState: Bool = false
    ) {
        Self.validate(
            catalog: configuration.catalog,
            in: purchaseConfiguration
        )

        self.purchaseConfiguration = purchaseConfiguration
        self.configuration = configuration
        self.remotePaywallIdentifier = remotePaywallIdentifier
        self.purchaseService = purchaseService
        self.isPreviewState = isPreviewState
        self.isLoadingConfiguration = remotePaywallIdentifier != nil
        let configuredProducts = configuration.catalog.products(
            in: purchaseConfiguration
        )
        self.selectedOptionIdentifier = configuredProducts.first { product in
            product.id == configuration.defaultProductIdentifier
        }?.id ?? configuredProducts.first?.id
    }

    /// 페이월 모델이 소유한 비동기 작업 정리
    deinit {
        customerInfoTask?.cancel()
    }

    /// 프리뷰용 페이월 모델 반환
    ///
    /// 전달한 구매 구성과 페이월 구성의 기본 선택 상품, 안내 문구와 정책 주소를 그대로
    /// 사용한다. 실제 StoreKit 상품 조회, 결제, 구매 복원과 고객 정보 조회는
    /// 실행하지 않는다.
    ///
    /// - Parameters:
    ///   - purchaseConfiguration: 프리뷰에서 상품 목록을 해석할 앱 전체 구매 구성
    ///   - configuration: 프리뷰에 표시할 페이월 구성
    ///   - activeProductIdentifiers: 구매한 것으로 표시할 `PurchaseProduct.productIdentifier` 목록
    ///   - activeEntitlementIdentifiers: 활성 상태로 표시할 `PurchaseEntitlement.identifier` 목록
    /// - Returns: 지정한 상품 및 권한 상태가 적용된 프리뷰용 페이월 모델
    public static func preview(
        purchaseConfiguration: PurchaseConfiguration,
        configuration: PaywallConfiguration,
        activeProductIdentifiers: Set<String> = [],
        activeEntitlementIdentifiers: Set<String> = []
    ) -> PaywallModel {
        let model = PaywallModel(
            purchaseConfiguration: purchaseConfiguration,
            configuration: configuration,
            remotePaywallIdentifier: nil,
            purchaseService: nil,
            isPreviewState: true
        )
        model.activeProductIdentifiers = activeProductIdentifiers
        model.activeEntitlementIdentifiers = activeEntitlementIdentifiers
        model.customerInfoState = .loaded
        return model
    }

    // MARK: - 생명주기

    /// 페이월에 필요한 상품과 고객 정보 준비
    /// - Parameters:
    ///   - applicationAccountIdentifier: 현재 앱 사용자를 연결할 선택 UUID
    ///   - localeIdentifier: 페이월 표시 문구에 사용할 현재 로케일 식별자
    public func prepare(
        applicationAccountIdentifier: UUID? = nil,
        localeIdentifier: String = Locale.current.identifier
    ) async {
        guard !isPreviewState else {
            return
        }

        guard await loadRemoteConfigurationIfNeeded(
            localeIdentifier: localeIdentifier
        ) else {
            return
        }

        isCustomerInfoObservationEnabled = true
        // 계정 전환 직후 이전 고객 상태가 화면에 남지 않게 먼저 반영한다.
        _ = updateApplicationAccountIdentifier(applicationAccountIdentifier)
        let currentProductLoadingTask = startProductLoadingIfNeeded()
        await refreshStoreKitEntitlementProducts()
        try? await refreshCustomerInfo(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
        await currentProductLoadingTask?.value
    }

    /// 원격 페이월 구성이 필요하면 조회하고 현재 모델에 반영
    /// - Returns: 로컬 또는 원격 페이월 구성을 사용할 수 있는지 여부
    private func loadRemoteConfigurationIfNeeded(
        localeIdentifier: String
    ) async -> Bool {
        guard let remotePaywallIdentifier else {
            return configurationError == nil
        }

        if hasCompletedConfigurationLoading,
           loadedConfigurationLocaleIdentifier == localeIdentifier {
            return configurationError == nil
        }

        guard let purchaseService else {
            configurationError = PurchasesError.invalidServerResponse
            return false
        }

        isLoadingConfiguration = true
        configurationError = nil

        do {
            let resolvedConfiguration = try await purchaseService
                .paywallConfiguration(
                    for: remotePaywallIdentifier,
                    localeIdentifier: localeIdentifier
                )
            let paywallConfiguration = PaywallConfiguration(
                catalog: resolvedConfiguration.catalog,
                defaultProductIdentifier:
                    resolvedConfiguration.defaultProductIdentifier,
                autoRenewalNoticeResource: nil,
                autoRenewalNoticeText:
                    resolvedConfiguration.autoRenewalNotice,
                productDisplayContents:
                    resolvedConfiguration.productContents.map { content in
                        PaywallProductDisplayContent(
                            productIdentifier: content.productIdentifier,
                            title: content.title,
                            description: content.description
                        )
                    },
                privacyPolicyURL: resolvedConfiguration.privacyPolicyURL,
                termsOfServiceURL: resolvedConfiguration.termsOfServiceURL
            )

            purchaseConfiguration =
                resolvedConfiguration.purchaseConfiguration
            configuration = paywallConfiguration
            let configuredProducts = paywallConfiguration.catalog.products(
                in: resolvedConfiguration.purchaseConfiguration
            )
            selectedOptionIdentifier = configuredProducts.first { product in
                product.id == paywallConfiguration.defaultProductIdentifier
            }?.id ?? configuredProducts.first?.id
            hasCompletedConfigurationLoading = true
            loadedConfigurationLocaleIdentifier = localeIdentifier
            isLoadingConfiguration = false
            return true
        } catch {
            configurationError = error
            hasCompletedConfigurationLoading = true
            loadedConfigurationLocaleIdentifier = localeIdentifier
            isLoadingConfiguration = false
            return false
        }
    }

    /// 원격 조회 전 화면에 사용하는 빈 페이월 구성 생성
    private static func placeholderConfiguration(
        paywallIdentifier: String
    ) -> PaywallConfiguration {
        return PaywallConfiguration(
            catalog: PurchaseCatalog(
                identifier: paywallIdentifier,
                productIdentifiers: []
            ),
            defaultProductIdentifier: nil,
            autoRenewalNoticeResource: nil,
            privacyPolicyURL: nil,
            termsOfServiceURL: nil
        )
    }

    /// 구매 카탈로그의 상품이 전체 구매 구성에 등록되어 있는지 확인
    /// - Parameters:
    ///   - catalog: 검증할 구매 카탈로그
    ///   - purchaseConfiguration: 앱 전체 구매 구성
    private static func validate(
        catalog: PurchaseCatalog,
        in purchaseConfiguration: PurchaseConfiguration
    ) {
        let knownProductIdentifiers = Set(purchaseConfiguration.productIdentifiers)

        precondition(
            Set(catalog.productIdentifiers).isSubset(
                of: knownProductIdentifiers
            ),
            "PurchaseCatalog의 상품은 PurchaseConfiguration에 등록되어야 합니다."
        )
    }

    /// 고객 정보 변경 감시 중단
    public func stopObservingCustomerInfoUpdates() {
        isCustomerInfoObservationEnabled = false
        customerInfoTask?.cancel()
        customerInfoTask = nil
    }

    // MARK: - 복원 안내

    /// 표시 중인 구매 복원 안내 제거
    public func clearRestoreNotice() {
        restoreNotice = nil
    }

    // MARK: - 상품 조회

    /// 구매 상품에 맞는 StoreKit 상품 반환
    /// - Parameter catalogProduct: 앱에서 구성한 구매 상품
    /// - Returns: StoreKit에서 불러온 상품
    public func product(for catalogProduct: PurchaseProduct) -> Product? {
        products.first { product in
            product.id == catalogProduct.productIdentifier
        }
    }

    /// 사용자 정의 상품 콘텐츠에 전달할 상태 반환
    /// - Parameter catalogProduct: 앱에서 구성한 구매 상품
    /// - Returns: 상품 표시와 선택 상태
    public func context(for catalogProduct: PurchaseProduct) -> PaywallProductContext {
        let storeProduct = product(for: catalogProduct)
        let displayContent = configuration.productDisplayContents.first { content in
            content.productIdentifier == catalogProduct.productIdentifier
        }
        let availability: PaywallProductAvailability

        if storeProduct != nil {
            availability = .available
        } else if isLoadingProducts || !hasCompletedProductLoading {
            availability = .loading
        } else {
            availability = .unavailable
        }

        return PaywallProductContext(
            catalogProduct: catalogProduct,
            storeProduct: storeProduct,
            displayTitle: displayContent?.title,
            displayDescription: displayContent?.description,
            availability: availability,
            isSelected: isSelected(catalogProduct),
            isOwned: isOwned(catalogProduct),
            isEntitlementActive: isEntitlementActive(catalogProduct),
            purchaseResolutionState: purchaseResolutionState(for: catalogProduct)
        )
    }

    /// StoreKit 상품 목록을 필요한 경우에만 조회
    public func loadProductsIfNeeded() async {
        let currentProductLoadingTask = startProductLoadingIfNeeded()
        await currentProductLoadingTask?.value
    }

    /// 현재 StoreKit 권한 상품 상태 갱신
    public func refreshStoreKitEntitlementProducts() async {
        guard let purchaseService else {
            return
        }

        let productIdentifiers = await purchaseService
            .currentEntitlementProductIdentifiers()
        applyStoreKitEntitlementProductIdentifiers(productIdentifiers)
    }

    /// StoreKit이 확인한 현재 권한 상품 식별자 반영
    /// - Parameter productIdentifiers: 현재 권한을 제공하는 StoreKit 상품 식별자 목록
    func applyStoreKitEntitlementProductIdentifiers(
        _ productIdentifiers: Set<String>
    ) {
        activeProductIdentifiers = productIdentifiers
        resolvePendingPurchaseStates(with: productIdentifiers)
    }

    /// 필요한 경우 모델이 소유하는 StoreKit 상품 조회 작업 시작
    /// - Returns: 실행 중이거나 새로 시작한 상품 조회 작업
    private func startProductLoadingIfNeeded() -> Task<Void, Never>? {
        guard let purchaseService else {
            return nil
        }
        guard products.isEmpty else {
            hasCompletedProductLoading = true
            return nil
        }
        if let productLoadingTask {
            return productLoadingTask
        }

        isLoadingProducts = true
        productLoadingRevision += 1
        let requestedProductLoadingRevision = productLoadingRevision
        let productIdentifiers = configuration.catalog.productIdentifiers
        let productLoadingTask = Task { [weak self, purchaseService] in
            let loadedProducts: [Product]

            do {
                loadedProducts = try await purchaseService.products(
                    for: productIdentifiers
                )
            } catch {
                loadedProducts = []
            }

            guard let self else {
                return
            }

            finishProductLoading(
                loadedProducts,
                requestedProductLoadingRevision: requestedProductLoadingRevision
            )
        }
        self.productLoadingTask = productLoadingTask
        return productLoadingTask
    }

    /// StoreKit 상품 조회 결과 반영
    /// - Parameters:
    ///   - loadedProducts: StoreKit에서 불러온 상품 목록
    ///   - requestedProductLoadingRevision: 결과를 만든 상품 조회 작업 순번
    private func finishProductLoading(
        _ loadedProducts: [Product],
        requestedProductLoadingRevision: Int
    ) {
        guard requestedProductLoadingRevision == productLoadingRevision else {
            return
        }

        products = loadedProducts
        selectAvailableProductIfNeeded()
        isLoadingProducts = false
        hasCompletedProductLoading = true
        productLoadingTask = nil
    }

    // MARK: - 상품 선택

    /// 구매 상품 선택
    /// - Parameter catalogProduct: 선택할 구매 상품
    public func select(_ catalogProduct: PurchaseProduct) {
        guard !isProcessing else {
            return
        }

        selectedOptionIdentifier = catalogProduct.id
    }

    /// 구매 상품 선택 여부 반환
    /// - Parameter catalogProduct: 확인할 구매 상품
    /// - Returns: 현재 선택 여부
    public func isSelected(_ catalogProduct: PurchaseProduct) -> Bool {
        selectedOptionIdentifier == catalogProduct.id
    }

    /// StoreKit 상품 보유 여부 반환
    /// - Parameter catalogProduct: 확인할 구매 상품
    /// - Returns: 현재 상품 보유 여부
    public func isOwned(_ catalogProduct: PurchaseProduct) -> Bool {
        activeProductIdentifiers.contains(catalogProduct.productIdentifier)
    }

    /// 구매 상품의 권한 활성 여부 반환
    /// - Parameter catalogProduct: 확인할 구매 상품
    /// - Returns: 연결된 구매 권한 활성 여부
    public func isEntitlementActive(_ catalogProduct: PurchaseProduct) -> Bool {
        !catalogProduct.entitlementIdentifiers.isDisjoint(
            with: activeEntitlementIdentifiers
        )
    }

    /// 구매 결과 확인 대기 상태 반환
    /// - Parameter catalogProduct: 확인할 구매 상품
    /// - Returns: 같은 권한 상품의 구매 결과 확인 대기 상태
    public func purchaseResolutionState(
        for catalogProduct: PurchaseProduct
    ) -> PaywallPurchaseResolutionState? {
        configuredProducts.lazy
            .filter { configuredProduct in
                if !catalogProduct.entitlementIdentifiers.isEmpty {
                    return !configuredProduct.entitlementIdentifiers.isDisjoint(
                        with: catalogProduct.entitlementIdentifiers
                    )
                }

                return configuredProduct.id == catalogProduct.id
            }
            .compactMap { configuredProduct in
                self.purchaseResolutionStates[configuredProduct.productIdentifier]
            }
            .first
    }

    /// 구매 결과 확인 대기 여부 반환
    /// - Parameter catalogProduct: 확인할 구매 상품
    /// - Returns: 같은 권한 상품의 구매 결과를 기다리는지 여부
    public func isPurchaseAwaitingResolution(
        _ catalogProduct: PurchaseProduct
    ) -> Bool {
        purchaseResolutionState(for: catalogProduct) != nil
    }

    /// 선택된 상품의 구매 결과 확인 대기 상태
    public var selectedPurchaseResolutionState: PaywallPurchaseResolutionState? {
        guard let selectedCatalogProduct else {
            return nil
        }

        return purchaseResolutionState(for: selectedCatalogProduct)
    }

    /// 선택된 상품의 구매 결과 확인 대기 여부
    public var isSelectedPurchaseAwaitingResolution: Bool {
        selectedPurchaseResolutionState != nil
    }

    // MARK: - 구매

    /// 선택된 StoreKit 상품 구매
    /// - Parameter appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    /// - Returns: 구매를 시작하지 못하면 `nil`, 그 외 StoreKit 구매 처리 상태
    public func purchaseSelectedProduct(
        appAccountToken: UUID? = nil
    ) async throws -> PurchaseResult? {
        let requestedAccountRevision = updateApplicationAccountIdentifier(
            appAccountToken
        )

        // StoreKit 상품 준비 상태와 중복 요청 여부만 구매 조건으로 확인한다.
        guard
            !isPurchaseButtonDisabled,
            let purchaseService,
            let selectedCatalogProduct,
            let selectedStoreProduct
        else {
            return nil
        }

        purchasingProductIdentifier = selectedStoreProduct.id
        defer {
            purchasingProductIdentifier = nil
        }

        let purchaseResult = try await purchaseService.purchase(
            selectedStoreProduct,
            appAccountToken: appAccountToken
        )
        guard requestedAccountRevision == applicationAccountRevision else {
            return purchaseResult
        }

        applyPurchaseResult(
            purchaseResult,
            catalogProduct: selectedCatalogProduct
        )
        if purchaseResult == .completed {
            await refreshStoreKitEntitlementProducts()
        }
        return purchaseResult
    }

    /// StoreKit 구매 결과를 페이월 상태에 반영
    /// - Parameters:
    ///   - purchaseResult: StoreKit 구매 처리 결과
    ///   - catalogProduct: 구매를 요청한 앱 구매 상품
    func applyPurchaseResult(
        _ purchaseResult: PurchaseResult,
        catalogProduct: PurchaseProduct
    ) {
        switch purchaseResult {
        case .completed:
            purchaseResolutionStates.removeValue(
                forKey: catalogProduct.productIdentifier
            )
        case .pending:
            purchaseResolutionStates[catalogProduct.productIdentifier] =
                .pendingApproval
        case .cancelled:
            purchaseResolutionStates.removeValue(
                forKey: catalogProduct.productIdentifier
            )
        }
    }

    // MARK: - 구매 복원

    /// App Store 구매 내역 복원
    /// - Parameter applicationAccountIdentifier: 현재 앱 사용자를 연결할 선택 UUID
    /// - Returns: 복원을 시작하지 못하면 `nil`, StoreKit 동기화 성공 여부
    @discardableResult
    public func restorePurchases(
        applicationAccountIdentifier: UUID? = nil
    ) async -> Bool? {
        guard let purchaseService else {
            return nil
        }

        let requestedAccountRevision = updateApplicationAccountIdentifier(
            applicationAccountIdentifier
        )
        isCustomerInfoObservationEnabled = true

        // 구매 또는 다른 복원 작업과 동시에 App Store 동기화를 시작하지 않는다.
        guard !isProcessing else {
            return nil
        }

        clearRestoreNotice()
        isRestoring = true
        restoringAccountRevision = requestedAccountRevision
        defer {
            if restoringAccountRevision == requestedAccountRevision {
                isRestoring = false
                restoringAccountRevision = nil
            }
        }

        do {
            try await purchaseService.synchronizePurchases()
            guard requestedAccountRevision == applicationAccountRevision else {
                return nil
            }

            await refreshStoreKitEntitlementProducts()
            restoreNotice = hasOwnedCatalogProduct ? .succeeded : .notFound
            return true
        } catch {
            guard requestedAccountRevision == applicationAccountRevision else {
                return nil
            }

            restoreNotice = .failed
            return false
        }
    }

    // MARK: - 고객 정보

    /// 최신 고객 정보 조회와 권한 상태 반영
    /// - Parameter applicationAccountIdentifier: 현재 앱 사용자를 연결할 선택 UUID
    public func refreshCustomerInfo(
        applicationAccountIdentifier: UUID? = nil
    ) async throws {
        guard let purchaseService else {
            return
        }

        let requestedAccountRevision = updateApplicationAccountIdentifier(
            applicationAccountIdentifier
        )
        isCustomerInfoObservationEnabled = true
        let isRestoringCurrentAccount = isRestoring &&
            restoringAccountRevision == requestedAccountRevision
        if let customerInfoRefreshTask,
           customerInfoRefreshAccountRevision == requestedAccountRevision {
            try await customerInfoRefreshTask.value
            return
        }
        guard !isRestoringCurrentAccount else {
            return
        }

        customerInfoState = .loading
        customerInfoRefreshRevision += 1
        let requestedCustomerInfoRefreshRevision = customerInfoRefreshRevision
        let customerInfoRefreshTask = Task { [weak self, purchaseService] in
            do {
                let customerInfo = try await purchaseService.customerInfo(
                    applicationAccountIdentifier: applicationAccountIdentifier
                )
                guard let self else {
                    return
                }

                finishCustomerInfoRefresh(
                    customerInfo,
                    requestedAccountRevision: requestedAccountRevision,
                    requestedCustomerInfoRefreshRevision:
                        requestedCustomerInfoRefreshRevision
                )
            } catch {
                guard let self else {
                    throw error
                }

                finishCustomerInfoRefreshFailure(
                    requestedAccountRevision: requestedAccountRevision,
                    requestedCustomerInfoRefreshRevision:
                        requestedCustomerInfoRefreshRevision
                )
                throw error
            }
        }
        self.customerInfoRefreshTask = customerInfoRefreshTask
        customerInfoRefreshAccountRevision = requestedAccountRevision
        try await customerInfoRefreshTask.value
    }

    /// 고객 정보 조회 성공 결과 반영
    /// - Parameters:
    ///   - customerInfo: 새로 확인한 현재 고객 정보
    ///   - requestedAccountRevision: 조회를 시작한 계정 변경 순번
    ///   - requestedCustomerInfoRefreshRevision: 조회 작업 변경 순번
    private func finishCustomerInfoRefresh(
        _ customerInfo: CustomerInfo,
        requestedAccountRevision: Int,
        requestedCustomerInfoRefreshRevision: Int
    ) {
        guard
            requestedAccountRevision == applicationAccountRevision,
            requestedCustomerInfoRefreshRevision == customerInfoRefreshRevision
        else {
            return
        }

        customerInfoRefreshTask = nil
        customerInfoRefreshAccountRevision = nil
        applyCustomerInfo(customerInfo)
        startObservingCustomerInfoUpdates()
    }

    /// 고객 정보 조회 실패 상태 반영
    /// - Parameters:
    ///   - requestedAccountRevision: 조회를 시작한 계정 변경 순번
    ///   - requestedCustomerInfoRefreshRevision: 조회 작업 변경 순번
    private func finishCustomerInfoRefreshFailure(
        requestedAccountRevision: Int,
        requestedCustomerInfoRefreshRevision: Int
    ) {
        guard
            requestedAccountRevision == applicationAccountRevision,
            requestedCustomerInfoRefreshRevision == customerInfoRefreshRevision
        else {
            return
        }

        customerInfoRefreshTask = nil
        customerInfoRefreshAccountRevision = nil
        customerInfoState = .failed
    }

    /// 고객 정보의 활성 권한 상태 반영
    /// - Parameter customerInfo: 반영할 최신 고객 정보
    func applyCustomerInfo(_ customerInfo: CustomerInfo) {
        lastAppliedCustomerInfo = customerInfo
        activeEntitlementIdentifiers = customerInfo.activeEntitlementIdentifiers
        customerInfoState = .loaded
    }

    /// StoreKit 현재 권한으로 확인이 끝난 구매 대기 상태 제거
    /// - Parameter productIdentifiers: 현재 권한을 제공하는 StoreKit 상품 식별자 목록
    private func resolvePendingPurchaseStates(
        with productIdentifiers: Set<String>
    ) {
        for productIdentifier in Array(purchaseResolutionStates.keys) {
            guard productIdentifiers.contains(productIdentifier) else {
                continue
            }

            purchaseResolutionStates.removeValue(forKey: productIdentifier)
        }
    }

    /// 고객 정보 변경 감시 시작
    private func startObservingCustomerInfoUpdates() {
        guard
            isCustomerInfoObservationEnabled,
            let purchaseService,
            customerInfoTask == nil
        else {
            return
        }

        let observedAccountIdentifier = applicationAccountIdentifier
        let observedAccountRevision = applicationAccountRevision

        customerInfoTask = Task { [weak self, purchaseService] in
            for await customerInfo in purchaseService.customerInfoStream {
                guard !Task.isCancelled else {
                    return
                }
                guard let self else {
                    return
                }
                guard observedAccountRevision == applicationAccountRevision else {
                    return
                }
                guard customerInfo != lastAppliedCustomerInfo else {
                    continue
                }

                await refreshCustomerInfoForObservedUpdate(
                    applicationAccountIdentifier: observedAccountIdentifier,
                    requestedAccountRevision: observedAccountRevision
                )
            }
        }
    }

    /// 고객 정보 스트림 변경을 현재 앱 계정 기준으로 다시 확인
    /// - Parameters:
    ///   - applicationAccountIdentifier: 감시를 시작한 앱 계정 식별자
    ///   - requestedAccountRevision: 감시를 시작한 계정 변경 순번
    private func refreshCustomerInfoForObservedUpdate(
        applicationAccountIdentifier: UUID?,
        requestedAccountRevision: Int
    ) async {
        guard
            !Task.isCancelled,
            isCustomerInfoObservationEnabled,
            requestedAccountRevision == applicationAccountRevision
        else {
            return
        }

        let joinsExistingCustomerInfoRefresh = customerInfoRefreshTask != nil &&
            customerInfoRefreshAccountRevision == requestedAccountRevision
        // 공유 스트림은 계정을 구분하지 않으므로 현재 계정으로 다시 조회한다.
        try? await refreshCustomerInfo(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
        guard
            joinsExistingCustomerInfoRefresh,
            !Task.isCancelled,
            isCustomerInfoObservationEnabled,
            requestedAccountRevision == applicationAccountRevision
        else {
            return
        }

        // 기존 조회 중 도착한 스트림 변경은 조회가 끝난 뒤 한 번 더 확인한다.
        try? await refreshCustomerInfo(
            applicationAccountIdentifier: applicationAccountIdentifier
        )
    }

    /// 사용 가능한 상품이 있으면 현재 선택 상태 보정
    private func selectAvailableProductIfNeeded() {
        selectedOptionIdentifier = PaywallProductVisibilityPolicy.selectedOptionIdentifier(
            currentOptionIdentifier: selectedOptionIdentifier,
            configuredProducts: configuredProducts,
            availableProductIdentifiers: availableProductIdentifiers
        )
    }

    /// StoreKit에서 불러온 상품 식별자 목록
    private var availableProductIdentifiers: Set<String> {
        Set(products.map(\.id))
    }

    /// 고객 정보를 요청할 앱 계정 식별자 반영
    /// - Parameter applicationAccountIdentifier: 새 앱 계정 식별자
    /// - Returns: 요청 결과 유효성 확인에 사용할 계정 변경 순번
    private func updateApplicationAccountIdentifier(
        _ applicationAccountIdentifier: UUID?
    ) -> Int {
        if !hasApplicationAccountIdentifier ||
            self.applicationAccountIdentifier != applicationAccountIdentifier {
            if hasApplicationAccountIdentifier {
                stopObservingCustomerInfoUpdates()
                resetCustomerState()
            }

            self.applicationAccountIdentifier = applicationAccountIdentifier
            hasApplicationAccountIdentifier = true
            applicationAccountRevision += 1
        }

        return applicationAccountRevision
    }

    /// 이전 앱 계정의 고객 상태 제거
    private func resetCustomerState() {
        customerInfoRefreshRevision += 1
        customerInfoRefreshTask = nil
        customerInfoRefreshAccountRevision = nil
        lastAppliedCustomerInfo = nil
        activeProductIdentifiers.removeAll()
        activeEntitlementIdentifiers.removeAll()
        purchaseResolutionStates.removeAll()
        customerInfoState = .idle
        restoreNotice = nil
    }
}
