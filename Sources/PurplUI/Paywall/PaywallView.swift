//
//  PaywallView.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import Foundation
import Purpl
import SwiftUI

/// 기본 디자인과 사용자 정의 상품 카드를 지원하는 페이월
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

    /// 사용자 정의 상품 카드를 사용하는 페이월 생성
    ///
    /// 앱 실행 중 `Purchases.configure`를 먼저 호출해야 한다.
    ///
    /// `productContent`가 반환하는 콘텐츠 전체를 SDK가 선택 버튼으로 감싼다.
    /// 콘텐츠 안에는 다른 버튼이나 링크처럼 중첩되는 상호작용 뷰를 넣지 않는다.
    ///
    /// - Parameters:
    ///   - configuration: 페이월 구성
    ///   - style: 기본 화면과 하단 구매 영역 스타일
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    ///   - purchaseResultAction: StoreKit 구매 처리 결과 액션
    ///   - purchaseFailureAction: StoreKit 구매 처리 실패 액션
    ///   - marketingContent: 앱별 마케팅 콘텐츠
    ///   - productContent: 구매 상품별 사용자 정의 콘텐츠
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

    /// Purpl 웹에서 구성한 사용자 정의 상품 카드를 사용하는 페이월 생성
    ///
    /// 앱 실행 중 `Purchases.configure`를 먼저 호출해야 한다.
    ///
    /// - Parameters:
    ///   - paywallIdentifier: Purpl 웹에서 정의한 페이월 구성 식별자
    ///   - style: 기본 화면과 하단 구매 영역 스타일
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    ///   - purchaseResultAction: StoreKit 구매 처리 결과 액션
    ///   - purchaseFailureAction: StoreKit 구매 처리 실패 액션
    ///   - marketingContent: 앱별 마케팅 콘텐츠
    ///   - productContent: 구매 상품별 사용자 정의 콘텐츠
    @MainActor
    public init(
        paywallIdentifier: String,
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
            model: PaywallModel(paywallIdentifier: paywallIdentifier),
            style: style,
            appAccountToken: appAccountToken,
            purchaseResultAction: purchaseResultAction,
            purchaseFailureAction: purchaseFailureAction,
            marketingContent: marketingContent,
            productContent: productContent
        )
    }

    /// 지정한 상태 모델과 사용자 정의 상품 카드를 사용하는 페이월 생성
    ///
    /// `productContent`가 반환하는 콘텐츠 전체를 SDK가 선택 버튼으로 감싼다.
    /// 콘텐츠 안에는 다른 버튼이나 링크처럼 중첩되는 상호작용 뷰를 넣지 않는다.
    ///
    /// - Parameters:
    ///   - model: 페이월 구성과 상태를 소유하는 모델
    ///   - style: 기본 화면과 하단 구매 영역 스타일
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    ///   - purchaseResultAction: StoreKit 구매 처리 결과 액션
    ///   - purchaseFailureAction: StoreKit 구매 처리 실패 액션
    ///   - marketingContent: 앱별 마케팅 콘텐츠
    ///   - productContent: 구매 상품별 사용자 정의 콘텐츠
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

    /// 페이월 본문
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
                appAccountToken: appAccountToken,
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
    /// Purpl 기본 상품 카드를 사용하는 페이월 생성
    ///
    /// 앱 실행 중 `Purchases.configure`를 먼저 호출해야 한다.
    ///
    /// - Parameters:
    ///   - configuration: 페이월 구성
    ///   - style: 기본 화면과 상품 카드 스타일
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    ///   - purchaseResultAction: StoreKit 구매 처리 결과 액션
    ///   - purchaseFailureAction: StoreKit 구매 처리 실패 액션
    ///   - marketingContent: 앱별 마케팅 콘텐츠
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

    /// Purpl 웹 구성과 기본 상품 카드를 사용하는 페이월 생성
    ///
    /// 앱 실행 중 `Purchases.configure`를 먼저 호출해야 한다.
    ///
    /// - Parameters:
    ///   - paywallIdentifier: Purpl 웹에서 정의한 페이월 구성 식별자
    ///   - style: 기본 화면과 상품 카드 스타일
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    ///   - purchaseResultAction: StoreKit 구매 처리 결과 액션
    ///   - purchaseFailureAction: StoreKit 구매 처리 실패 액션
    ///   - marketingContent: 앱별 마케팅 콘텐츠
    @MainActor
    init(
        paywallIdentifier: String,
        style: PaywallStyle = PaywallStyle(),
        appAccountToken: UUID? = nil,
        purchaseResultAction: @escaping @MainActor (PurchaseResult) -> Void = { _ in },
        purchaseFailureAction: @escaping @MainActor (any Error) -> Void = { _ in },
        @ViewBuilder marketingContent: () -> MarketingContent
    ) {
        self.init(
            paywallIdentifier: paywallIdentifier,
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

    /// 지정한 상태 모델과 Purpl 기본 상품 카드를 사용하는 페이월 생성
    /// - Parameters:
    ///   - model: 페이월 구성과 상태를 소유하는 모델
    ///   - style: 기본 화면과 상품 카드 스타일
    ///   - appAccountToken: 로그인 사용자의 구매를 앱 계정과 연결할 선택 UUID
    ///   - purchaseResultAction: StoreKit 구매 처리 결과 액션
    ///   - purchaseFailureAction: StoreKit 구매 처리 실패 액션
    ///   - marketingContent: 앱별 마케팅 콘텐츠
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
