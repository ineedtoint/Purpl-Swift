//
//  PaywallPurchaseBar.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import Foundation
import Purpl
import SwiftUI

/// 페이월 하단 구매 영역
struct PaywallPurchaseBar: View {
    /// 기본 페이월 스타일
    let style: PaywallStyle

    /// 페이월 상태 모델
    let model: PaywallModel

    /// 구매 처리 결과 액션
    let purchaseResultAction: @MainActor (PurchaseResult) -> Void

    /// 구매 처리 실패 액션
    let purchaseFailureAction: @MainActor (any Error) -> Void

    /// 페이월 하단 구매 영역 본문
    var body: some View {
        VStack(spacing: 16) {
            purchaseButton
            purchaseFooterActions
        }
        .padding(.horizontal, 8)
        .padding(8)
    }

    /// 통합 구매 버튼
    private var purchaseButton: some View {
        Button {
            Task {
                await purchaseSelectedProduct()
            }
        } label: {
            HStack {
                purchaseButtonTitle
            }
            .padding(8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(style.tintColor)
        .disabled(model.isPurchaseButtonDisabled)
    }

    /// 선택된 상품 구매
    private func purchaseSelectedProduct() async {
        do {
            guard let purchaseResult = try await model
                .purchaseSelectedProduct() else {
                return
            }

            purchaseResultAction(purchaseResult)
        } catch {
            purchaseFailureAction(error)
        }
    }

    /// 구매 복원 버튼
    private var restoreButton: some View {
        Button {
            Task {
                await model.restorePurchases()
            }
        } label: {
            if model.isRestoring {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Text(LocalizedStringResource(
                    "paywall.restore",
                    bundle: .module,
                    comment: "구매 복원"
                ))
            }
        }
        .disabled(model.isProcessing || model.customerInfoState == .loading)
    }

    /// 하단 구매 보조 액션
    private var purchaseFooterActions: some View {
        HStack(spacing: 16) {
            restoreButton

            if let termsOfServiceURL = model.configuration.termsOfServiceURL {
                Link(destination: termsOfServiceURL) {
                    Text(LocalizedStringResource(
                        "paywall.policy.termsOfService",
                        bundle: .module,
                        comment: "서비스 약관"
                    ))
                }
            }

            if let privacyPolicyURL = model.configuration.privacyPolicyURL {
                Link(destination: privacyPolicyURL) {
                    Text(LocalizedStringResource(
                        "paywall.policy.privacyPolicy",
                        bundle: .module,
                        comment: "개인정보 처리방침"
                    ))
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    /// 구매 버튼 제목
    @ViewBuilder
    private var purchaseButtonTitle: some View {
        if model.isSelectedProductOwned {
            Text(LocalizedStringResource(
                "paywall.product.currentlyInUse",
                bundle: .module,
                comment: "현재 이용 중"
            ))
            .fontWeight(.semibold)
        } else if model.selectedPurchaseResolutionState == .pendingApproval {
            Text(LocalizedStringResource(
                "paywall.product.loading",
                bundle: .module,
                comment: "상품 확인 중"
            ))
            .fontWeight(.semibold)
        } else if model.selectedStoreProduct != nil {
            Text(LocalizedStringResource(
                "paywall.button.pay",
                bundle: .module,
                comment: "결제"
            ))
            .fontWeight(.semibold)
        } else if model.isLoadingProducts || !model.hasCompletedProductLoading {
            Text(LocalizedStringResource(
                "paywall.product.loading",
                bundle: .module,
                comment: "상품 확인 중"
            ))
            .fontWeight(.semibold)
        } else {
            Text(LocalizedStringResource(
                "paywall.button.unavailable",
                bundle: .module,
                comment: "구매 불가"
            ))
            .fontWeight(.semibold)
        }
    }
}
