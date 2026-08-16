//
//  ExamplePaywallView.swift
//  PurplExample
//
//  Created by Int on 8/17/26.
//

import Purpl
import PurplUI
import SwiftUI

/// 로컬 StoreKit 상품과 현재 권한을 보여주는 예제 페이월
struct ExamplePaywallView: View {
    /// 현재 고객 정보 작업 상태
    @State private var customerInfoState: CustomerInfoTaskState = .loading

    /// 예제 페이월 본문
    var body: some View {
        NavigationStack {
            PaywallView(
                configuration: ExamplePaywallConfiguration.standard
            ) {
                ExampleMarketingContent(
                    customerInfoState: customerInfoState
                )
            }
            .navigationTitle("Purpl Example")
            .navigationBarTitleDisplayMode(.inline)
        }
        .customerInfoTask(for: nil) { state in
            customerInfoState = state
        }
    }
}

/// 예제 페이월의 소개와 권한 상태 콘텐츠
private struct ExampleMarketingContent: View {
    /// 현재 고객 정보 작업 상태
    let customerInfoState: CustomerInfoTaskState

    /// 예제 소개 콘텐츠 본문
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.purple)

            VStack(spacing: 8) {
                Text("Purpl Plus")
                    .font(.largeTitle.bold())

                Text("Try purchases, restoration, and entitlements without an account or server.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }

            entitlementStatus
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    /// 현재 권한 확인 상태
    @ViewBuilder
    private var entitlementStatus: some View {
        switch customerInfoState {
        case .loading:
            Label(
                "Checking entitlement",
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
            )
            .foregroundStyle(Color.secondary)
        case .success(let customerInfo):
            if customerInfo.isEntitlementActive(
                ExamplePurchaseConfiguration.plusEntitlement.identifier
            ) {
                Label(
                    "Purpl Plus is active",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(Color.green)
            } else {
                Label("No active entitlement", systemImage: "circle")
                    .foregroundStyle(Color.secondary)
            }
        case .failure(let error):
            Label(
                error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(Color.red)
        }
    }
}
