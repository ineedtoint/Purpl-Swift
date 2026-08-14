//
//  PurchaseEntitlement.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

// 앱에서 사용하는 구매 권한
/// A purchase entitlement used by the app.
public struct PurchaseEntitlement: Identifiable, Sendable {
    // 권한 식별자
    /// The entitlement identifier.
    public let identifier: String

    // 목록 식별자
    /// The identifier used for identifiable collections.
    public var id: String {
        identifier
    }

    // 권한 표시 제목
    /// The localized display title for the entitlement.
    public let titleResource: LocalizedStringResource?

    // 구매 권한 생성
    /// Creates a purchase entitlement.
    public init(
        identifier: String,
        titleResource: LocalizedStringResource? = nil
    ) {
        precondition(
            identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            "PurchaseEntitlement의 식별자는 비어 있을 수 없습니다."
        )

        self.identifier = identifier
        self.titleResource = titleResource
    }
}
