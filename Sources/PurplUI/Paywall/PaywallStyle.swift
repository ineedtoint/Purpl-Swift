//
//  PaywallStyle.swift
//  PurplUI
//
//  Created by Int on 7/28/26.
//

import SwiftUI

/// 페이월 화면과 기본 상품 카드 스타일
public struct PaywallStyle {
    /// 강조 색상
    public let tintColor: Color

    /// 화면 배경 스타일
    public let backgroundStyle: AnyShapeStyle

    /// 기본 상품 카드의 배경 스타일
    public let productCardBackgroundStyle: AnyShapeStyle

    /// 기본 상품 카드의 선택 테두리 스타일
    public let selectedBorderStyle: AnyShapeStyle

    /// 기본 상품 카드의 선택 테두리 두께
    public let selectedBorderLineWidth: CGFloat

    /// 페이월 스타일 생성
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
