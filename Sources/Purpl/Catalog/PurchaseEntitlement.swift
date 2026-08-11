//
//  PurchaseEntitlement.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

/// 앱에서 사용하는 구매 권한
public struct PurchaseEntitlement: Identifiable, Sendable {
    /// 권한 식별자
    public let identifier: String

    /// 목록 식별자
    public var id: String {
        identifier
    }

    /// 권한 표시 제목
    public let titleResource: LocalizedStringResource?

    /// 구매 권한 생성
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
