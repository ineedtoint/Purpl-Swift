//
//  PaywallView.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import Foundation
import Purpl
import SwiftUI

// 기본 디자인과 사용자 정의 상품 카드를 지원하는 페이월
/// A paywall that supports the default design and custom product cards.
public struct PaywallView<MarketingContent: View, ProductContent: View>: View {
    /// 현재 SwiftUI 로케일
    @Environment(\.locale) private var locale

    /// 기본 페이월 스타일
    private let style: PaywallStyle

    /// 로그인 사용자의 구매 연결 식별자
    private let appAccountToken: UUID?

    /// 앱별 마케팅 콘텐츠
    private let marketingContent: MarketingContent

    /// 앱별 구매 상품 콘텐츠
    private let productContent: (PaywallProductContext) -> ProductContent

    /// 구매 처리 결과 액션
    private let purchaseResultAction: @MainActor (PurchaseResult) -> Void

    /// 구매 처리 실패 액션
    private let purchaseFailureAction: @MainActor (any Error) -> Void

    /// 페이월 상태 모델
    @State private var model: PaywallModel

    // 사용자 정의 상품 카드를 사용하는 페이월 생성
    /// Creates a paywall with custom product cards.
    ///
    /// Call `Purchases.configure` before presenting the paywall.
    ///
    /// The SDK wraps all content returned by `productContent` in a selection button. Don't place nested interactive views, such as buttons or links, inside that content.
    ///
    /// - Parameters:
    ///   - configuration: The paywall configuration.
    ///   - style: The style of the paywall and bottom purchase area.
    ///   - appAccountToken: An optional UUID that links the signed-in user's purchase to an app account.
    ///   - purchaseResultAction: An action that handles the StoreKit purchase result.
    ///   - purchaseFailureAction: An action that handles a StoreKit purchase failure.
    ///   - marketingContent: App-specific marketing content.
    ///   - productContent: Custom content for each purchase product.
    @MainActor
    public init(
        configuration: PaywallConfiguration,
        style: PaywallStyle = PaywallStyle(),
        appAccountToken: UUID? = nil,
        purchaseResultAction: @escaping @MainActor (PurchaseResult) -> Void = { _ in },
        purchaseFailureAction: @escaping @MainActor (any Error) -> Void = { _ in },
        @ViewBuilder marketingContent: () -> MarketingContent,
        @ViewBuilder productContent: @escaping (
            PaywallProductContext
        ) -> ProductContent
    ) {
        self.init(
            model: PaywallModel(configuration: configuration),
            style: style,
            appAccountToken: appAccountToken,
            purchaseResultAction: purchaseResultAction,
            purchaseFailureAction: purchaseFailureAction,
            marketingContent: marketingContent,
            productContent: productContent
        )
    }

    // Purpl 웹에서 구성한 사용자 정의 상품 카드를 사용하는 페이월 생성
    /// Creates a paywall with remote Purpl configuration and custom product cards.
    ///
    /// Call `Purchases.configure` before presenting the paywall.
    ///
    /// - Parameters:
    ///   - paywallIdentifier: The paywall configuration identifier defined in Purpl.
    ///   - fallbackConfiguration: An optional local configuration shown when the remote configuration is unavailable.
    ///   - style: The style of the paywall and bottom purchase area.
    ///   - appAccountToken: An optional UUID that links the signed-in user's purchase to an app account.
    ///   - purchaseResultAction: An action that handles the StoreKit purchase result.
    ///   - purchaseFailureAction: An action that handles a StoreKit purchase failure.
    ///   - marketingContent: App-specific marketing content.
    ///   - productContent: Custom content for each purchase product.
    @MainActor
    public init(
        paywallIdentifier: String,
        fallbackConfiguration: PaywallConfiguration? = nil,
        style: PaywallStyle = PaywallStyle(),
        appAccountToken: UUID? = nil,
        purchaseResultAction: @escaping @MainActor (PurchaseResult) -> Void = { _ in },
        purchaseFailureAction: @escaping @MainActor (any Error) -> Void = { _ in },
        @ViewBuilder marketingContent: () -> MarketingContent,
        @ViewBuilder productContent: @escaping (
            PaywallProductContext
        ) -> ProductContent
    ) {
        self.init(
            model: PaywallModel(
                paywallIdentifier: paywallIdentifier,
                fallbackConfiguration: fallbackConfiguration
            ),
            style: style,
            appAccountToken: appAccountToken,
            purchaseResultAction: purchaseResultAction,
            purchaseFailureAction: purchaseFailureAction,
            marketingContent: marketingContent,
            productContent: productContent
        )
    }

    // 지정한 상태 모델과 사용자 정의 상품 카드를 사용하는 페이월 생성
    /// Creates a paywall with the specified state model and custom product cards.
    ///
    /// The SDK wraps all content returned by `productContent` in a selection button. Don't place nested interactive views, such as buttons or links, inside that content.
    ///
    /// - Parameters:
    ///   - model: The model that owns the paywall configuration and state.
    ///   - style: The style of the paywall and bottom purchase area.
    ///   - appAccountToken: An optional UUID that links the signed-in user's purchase to an app account.
    ///   - purchaseResultAction: An action that handles the StoreKit purchase result.
    ///   - purchaseFailureAction: An action that handles a StoreKit purchase failure.
    ///   - marketingContent: App-specific marketing content.
    ///   - productContent: Custom content for each purchase product.
    @MainActor
    public init(
        model: PaywallModel,
        style: PaywallStyle = PaywallStyle(),
        appAccountToken: UUID? = nil,
        purchaseResultAction: @escaping @MainActor (PurchaseResult) -> Void = { _ in },
        purchaseFailureAction: @escaping @MainActor (any Error) -> Void = { _ in },
        @ViewBuilder marketingContent: () -> MarketingContent,
        @ViewBuilder productContent: @escaping (
            PaywallProductContext
        ) -> ProductContent
    ) {
        self.style = style
        self.appAccountToken = appAccountToken
        self.purchaseResultAction = purchaseResultAction
        self.purchaseFailureAction = purchaseFailureAction
        self.marketingContent = marketingContent()
        self.productContent = productContent
        self._model = State(initialValue: model)
    }

    // 페이월 본문
    /// The paywall content.
    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                marketingContent
                purchaseConfigurationSection

                if model.configuration.autoRenewalNoticeResource != nil
                    || model.configuration.autoRenewalNoticeText != nil {
                    purchasePolicySection
                }
            }
            .padding(.bottom, 32)
        }
        .background(style.backgroundStyle)
        .safeAreaBar(edge: .bottom) {
            PaywallPurchaseBar(
                style: style,
                model: model,
                purchaseResultAction: purchaseResultAction,
                purchaseFailureAction: purchaseFailureAction
            )
        }
        .task(id: "\(appAccountToken?.uuidString ?? "anonymous"):\(locale.identifier)") {
            await model.prepare(
                applicationAccountIdentifier: appAccountToken,
                localeIdentifier: locale.identifier
            )
        }
        .onDisappear {
            model.stopObservingCustomerInfoUpdates()
        }
        .alert(
            Text(LocalizedStringResource(
                "paywall.restore",
                bundle: .module,
                comment: "구매 복원"
            )),
            isPresented: restoreNoticeBinding
        ) {
            Button(role: .cancel) {
                model.clearRestoreNotice()
            } label: {
                Text(LocalizedStringResource(
                    "confirm",
                    bundle: .module,
                    comment: "확인"
                ))
            }
        } message: {
            restoreNoticeMessage
        }
    }

    /// 원격 구성 상태에 맞는 상품 선택 영역
    @ViewBuilder
    private var purchaseConfigurationSection: some View {
        if model.isLoadingConfiguration {
            ProgressView()
                .controlSize(.large)
                .padding(32)
        } else if let configurationError = model.configurationError {
            Text(configurationError.localizedDescription)
                .font(.callout)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(32)
        } else {
            productOptionsSection
        }
    }

    /// 구매 복원 안내 표시 바인딩
    private var restoreNoticeBinding: Binding<Bool> {
        Binding {
            model.restoreNotice != nil
        } set: { isPresented in
            if !isPresented {
                model.clearRestoreNotice()
            }
        }
    }

    /// 구매 복원 안내 메시지
    @ViewBuilder
    private var restoreNoticeMessage: some View {
        if let restoreNotice = model.restoreNotice {
            Text(restoreNotice.messageResource)
        } else {
            EmptyView()
        }
    }

    /// 구매 상품 선택 영역
    private var productOptionsSection: some View {
        VStack(spacing: 16) {
            ForEach(model.visibleCatalogProducts) { catalogProduct in
                catalogProductButton(for: catalogProduct)
            }
        }
        .padding(.horizontal, 16)
    }

    /// 구매 상품 선택 버튼 생성
    /// - Parameter catalogProduct: 표시할 구매 상품
    /// - Returns: SDK가 선택 동작을 관리하는 사용자 정의 상품 콘텐츠
    private func catalogProductButton(
        for catalogProduct: PurchaseProduct
    ) -> some View {
        Button {
            model.select(catalogProduct)
        } label: {
            productContent(model.context(for: catalogProduct))
        }
        .buttonStyle(.plain)
        .disabled(model.isProcessing)
    }

    /// 자동 갱신 안내 영역
    @ViewBuilder
    private var purchasePolicySection: some View {
        if let autoRenewalNoticeResource =
            model.configuration.autoRenewalNoticeResource {
            Text(autoRenewalNoticeResource)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        } else if let autoRenewalNoticeText =
                    model.configuration.autoRenewalNoticeText {
            Text(verbatim: autoRenewalNoticeText)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }
}

public extension PaywallView where ProductContent == DefaultPaywallProductCard {
    // Purpl 기본 상품 카드를 사용하는 페이월 생성
    /// Creates a paywall with the default Purpl product cards.
    ///
    /// Call `Purchases.configure` before presenting the paywall.
    ///
    /// - Parameters:
    ///   - configuration: The paywall configuration.
    ///   - style: The style of the paywall and product cards.
    ///   - appAccountToken: An optional UUID that links the signed-in user's purchase to an app account.
    ///   - purchaseResultAction: An action that handles the StoreKit purchase result.
    ///   - purchaseFailureAction: An action that handles a StoreKit purchase failure.
    ///   - marketingContent: App-specific marketing content.
    @MainActor
    init(
        configuration: PaywallConfiguration,
        style: PaywallStyle = PaywallStyle(),
        appAccountToken: UUID? = nil,
        purchaseResultAction: @escaping @MainActor (PurchaseResult) -> Void = { _ in },
        purchaseFailureAction: @escaping @MainActor (any Error) -> Void = { _ in },
        @ViewBuilder marketingContent: () -> MarketingContent
    ) {
        self.init(
            configuration: configuration,
            style: style,
            appAccountToken: appAccountToken,
            purchaseResultAction: purchaseResultAction,
            purchaseFailureAction: purchaseFailureAction,
            marketingContent: marketingContent,
            productContent: { context in
                DefaultPaywallProductCard(
                    context: context,
                    style: style
                )
            }
        )
    }

    // Purpl 웹 구성과 기본 상품 카드를 사용하는 페이월 생성
    /// Creates a paywall with remote Purpl configuration and the default product cards.
    ///
    /// Call `Purchases.configure` before presenting the paywall.
    ///
    /// - Parameters:
    ///   - paywallIdentifier: The paywall configuration identifier defined in Purpl.
    ///   - fallbackConfiguration: An optional local configuration shown when the remote configuration is unavailable.
    ///   - style: The style of the paywall and product cards.
    ///   - appAccountToken: An optional UUID that links the signed-in user's purchase to an app account.
    ///   - purchaseResultAction: An action that handles the StoreKit purchase result.
    ///   - purchaseFailureAction: An action that handles a StoreKit purchase failure.
    ///   - marketingContent: App-specific marketing content.
    @MainActor
    init(
        paywallIdentifier: String,
        fallbackConfiguration: PaywallConfiguration? = nil,
        style: PaywallStyle = PaywallStyle(),
        appAccountToken: UUID? = nil,
        purchaseResultAction: @escaping @MainActor (PurchaseResult) -> Void = { _ in },
        purchaseFailureAction: @escaping @MainActor (any Error) -> Void = { _ in },
        @ViewBuilder marketingContent: () -> MarketingContent
    ) {
        self.init(
            paywallIdentifier: paywallIdentifier,
            fallbackConfiguration: fallbackConfiguration,
            style: style,
            appAccountToken: appAccountToken,
            purchaseResultAction: purchaseResultAction,
            purchaseFailureAction: purchaseFailureAction,
            marketingContent: marketingContent,
            productContent: { context in
                DefaultPaywallProductCard(
                    context: context,
                    style: style
                )
            }
        )
    }

    // 지정한 상태 모델과 Purpl 기본 상품 카드를 사용하는 페이월 생성
    /// Creates a paywall with the specified state model and default Purpl product cards.
    /// - Parameters:
    ///   - model: The model that owns the paywall configuration and state.
    ///   - style: The style of the paywall and product cards.
    ///   - appAccountToken: An optional UUID that links the signed-in user's purchase to an app account.
    ///   - purchaseResultAction: An action that handles the StoreKit purchase result.
    ///   - purchaseFailureAction: An action that handles a StoreKit purchase failure.
    ///   - marketingContent: App-specific marketing content.
    @MainActor
    init(
        model: PaywallModel,
        style: PaywallStyle = PaywallStyle(),
        appAccountToken: UUID? = nil,
        purchaseResultAction: @escaping @MainActor (PurchaseResult) -> Void = { _ in },
        purchaseFailureAction: @escaping @MainActor (any Error) -> Void = { _ in },
        @ViewBuilder marketingContent: () -> MarketingContent
    ) {
        self.init(
            model: model,
            style: style,
            appAccountToken: appAccountToken,
            purchaseResultAction: purchaseResultAction,
            purchaseFailureAction: purchaseFailureAction,
            marketingContent: marketingContent,
            productContent: { context in
                DefaultPaywallProductCard(
                    context: context,
                    style: style
                )
            }
        )
    }
}
