//
//  DefaultPaywallProductCard.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import Foundation
import StoreKit
import SwiftUI

// Purpl 기본 페이월 상품 카드
/// The default Purpl paywall product card.
public struct DefaultPaywallProductCard: View {
    // 사용자 정의 콘텐츠에 전달되는 상품 상태
    /// The product state provided to custom content.
    public let context: PaywallProductContext

    // 기본 페이월 스타일
    /// The default paywall style.
    public let style: PaywallStyle

    // Purpl 기본 페이월 상품 카드 생성
    /// Creates a default Purpl paywall product card.
    public init(
        context: PaywallProductContext,
        style: PaywallStyle = PaywallStyle()
    ) {
        self.context = context
        self.style = style
    }

    // Purpl 기본 페이월 상품 카드 본문
    /// The content of the default Purpl paywall product card.
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            productTitle

            Spacer(minLength: 0)

            productPrice
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(style.productCardBackgroundStyle)
        )
        .overlay(selectedBorder)
    }

    /// 선택 테두리
    @ViewBuilder
    private var selectedBorder: some View {
        if context.isSelected {
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    style.selectedBorderStyle,
                    lineWidth: style.selectedBorderLineWidth
                )
        }
    }

    /// 상품 제목, 설명과 보유 상태
    private var productTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            productTitleText
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            if context.isOwned {
                Label {
                    Text(LocalizedStringResource(
                        "paywall.product.currentlyInUse",
                        bundle: .module,
                        comment: "현재 이용 중"
                    ))
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
                .font(.caption)
                .foregroundStyle(style.tintColor)
            } else {
                productDescriptionText
            }
        }
    }

    /// 상품 제목 문구
    @ViewBuilder
    private var productTitleText: some View {
        if let displayTitle = context.displayTitle {
            Text(verbatim: displayTitle)
        } else if let titleResource = context.catalogProduct.titleResource {
            Text(titleResource)
        } else if let storeProduct = context.storeProduct {
            Text(verbatim: storeProduct.displayName)
        } else {
            Text(verbatim: context.catalogProduct.productIdentifier)
        }
    }

    /// 상품 설명 문구
    @ViewBuilder
    private var productDescriptionText: some View {
        if let displayDescription = context.displayDescription {
            Text(verbatim: displayDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if context.hasRemoteDisplayContent {
            EmptyView()
        } else if context.catalogProduct.titleResource != nil {
            if let descriptionResource = context.catalogProduct.descriptionResource {
                Text(descriptionResource)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let storeProduct = context.storeProduct,
                  storeProduct.description.isEmpty == false {
            Text(verbatim: storeProduct.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 상품 가격 또는 사용 가능 상태
    @ViewBuilder
    private var productPrice: some View {
        if let storeProduct = context.storeProduct {
            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: storeProduct.displayPrice)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                priceCaption(for: storeProduct)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(productStatusResource)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }

    /// 상품 상태 문구
    private var productStatusResource: LocalizedStringResource {
        switch context.availability {
        case .loading:
            LocalizedStringResource(
                "paywall.product.loading",
                bundle: .module,
                comment: "상품 확인 중"
            )
        case .available, .unavailable:
            LocalizedStringResource(
                "paywall.button.unavailable",
                bundle: .module,
                comment: "구매 불가"
            )
        }
    }

    /// 월 기준 가격 캡션
    /// - Parameter storeProduct: 캡션을 생성할 StoreKit 상품
    /// - Returns: 월 기준 가격이 있는 경우 표시할 캡션
    @ViewBuilder
    private func priceCaption(for storeProduct: Product) -> some View {
        if let formattedMonthlyPrice = formattedMonthlyPrice(for: storeProduct) {
            HStack(spacing: 4) {
                Text(verbatim: formattedMonthlyPrice)
                    .monospacedDigit()
                Text(verbatim: "/")
                Text(LocalizedStringResource(
                    "paywall.price.period.month",
                    bundle: .module,
                    comment: "월"
                ))
            }
        }
    }

    /// StoreKit 상품의 월 기준 가격 반환
    /// - Parameter storeProduct: 월 기준 가격을 계산할 StoreKit 상품
    /// - Returns: 현지화한 월 기준 가격
    private func formattedMonthlyPrice(for storeProduct: Product) -> String? {
        guard
            let subscription = storeProduct.subscription,
            let monthCount = monthCount(for: subscription.subscriptionPeriod)
        else {
            return nil
        }

        let monthlyPrice = storeProduct.price / Decimal(monthCount)
        return monthlyPrice.formatted(storeProduct.priceFormatStyle)
    }

    /// 구독 기간의 월 수 반환
    /// - Parameter subscriptionPeriod: StoreKit 구독 기간
    /// - Returns: 월 단위로 변환할 수 있는 구독 기간
    private func monthCount(
        for subscriptionPeriod: Product.SubscriptionPeriod
    ) -> Int? {
        switch subscriptionPeriod.unit {
        case .month:
            subscriptionPeriod.value
        case .year:
            subscriptionPeriod.value * 12
        default:
            nil
        }
    }
}
