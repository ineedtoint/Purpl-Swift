//
//  PaywallStyle.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import SwiftUI

// 페이월 화면과 기본 상품 카드 스타일
/// The visual style of the paywall and its default product cards.
public struct PaywallStyle {
    // 강조 색상
    /// The tint color.
    public let tintColor: Color

    // 화면 배경 스타일
    /// The paywall background style.
    public let backgroundStyle: AnyShapeStyle

    // 기본 상품 카드의 배경 스타일
    /// The background style of the default product card.
    public let productCardBackgroundStyle: AnyShapeStyle

    // 기본 상품 카드의 선택 테두리 스타일
    /// The selected border style of the default product card.
    public let selectedBorderStyle: AnyShapeStyle

    // 기본 상품 카드의 선택 테두리 두께
    /// The selected border width of the default product card.
    public let selectedBorderLineWidth: CGFloat

    // 페이월 스타일 생성
    /// Creates a paywall style.
    public init(
        tintColor: Color = Color.accentColor,
        backgroundStyle: some ShapeStyle = BackgroundStyle.background,
        productCardBackgroundStyle: some ShapeStyle = Color.gray.opacity(0.2),
        selectedBorderStyle: some ShapeStyle = Color.accentColor,
        selectedBorderLineWidth: CGFloat = 1.5
    ) {
        self.tintColor = tintColor
        self.backgroundStyle = AnyShapeStyle(backgroundStyle)
        self.productCardBackgroundStyle = AnyShapeStyle(productCardBackgroundStyle)
        self.selectedBorderStyle = AnyShapeStyle(selectedBorderStyle)
        self.selectedBorderLineWidth = selectedBorderLineWidth
    }
}
