//
//  CustomerInfo.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

// 스토어 환경
/// The store environment associated with a purchase or entitlement.
public enum StoreEnvironment: String, Decodable, Hashable, Sendable {
    // 운영 환경
    /// The production environment.
    case production
    // 샌드박스 환경
    /// The sandbox environment.
    case sandbox
    // Xcode StoreKit Configuration 환경
    /// The Xcode StoreKit Configuration environment.
    case xcode
}

// 고객 권한 상태
/// The current status of a customer entitlement.
public enum CustomerEntitlementStatus: String, Decodable, Hashable, Sendable {
    // 사용 가능한 상태
    /// The entitlement is available for use.
    case active
    // 유예 기간 상태
    /// The entitlement is in a billing grace period.
    case gracePeriod = "grace_period"
    // 결제 재시도 상태
    /// The entitlement is in a billing retry period.
    case billingRetry = "billing_retry"
    // 일시 중지 상태
    /// The entitlement is paused.
    case paused
    // 만료 상태
    /// The entitlement has expired.
    case expired
    // 회수 상태
    /// The entitlement has been revoked.
    case revoked
}

// 고객 정보 확인 출처
/// The source used to resolve customer information.
public enum CustomerInfoSource: Equatable, Sendable {
    // Purpl 서버
    /// The Purpl server.
    case server

    // 현재 기기의 StoreKit
    /// StoreKit on the current device.
    case storeKit
}

// 고객에게 연결된 권한
/// An entitlement associated with a customer.
public struct CustomerEntitlement: Decodable, Equatable, Sendable {
    // 권한 식별자
    /// The entitlement identifier.
    public let identifier: String
    // 권한 표시 이름
    /// The entitlement display name.
    public let displayName: String
    // 권한을 제공한 스토어 상품 식별자
    /// The store product identifier that granted the entitlement.
    public let productIdentifier: String?
    // 권한을 확인한 스토어 환경
    /// The store environment where the entitlement was resolved.
    public let environment: StoreEnvironment
    // 현재 권한 상태
    /// The current entitlement status.
    public let status: CustomerEntitlementStatus
    // 현재 사용 가능 여부
    /// A Boolean value that indicates whether the entitlement is currently available.
    public let active: Bool
    // 권한 시작 시각
    /// The date when the entitlement started.
    public let startsAt: Date?
    // 권한 만료 시각
    /// The date when the entitlement expires.
    public let expiresAt: Date?
    // 권한 회수 시각
    /// The date when the entitlement was revoked.
    public let revokedAt: Date?
    // 마지막 검증 시각
    /// The date when the entitlement was last verified.
    public let lastVerifiedAt: Date

    // 고객 권한 생성
    /// Creates a customer entitlement.
    public init(
        identifier: String,
        displayName: String,
        productIdentifier: String? = nil,
        environment: StoreEnvironment,
        status: CustomerEntitlementStatus,
        active: Bool,
        startsAt: Date?,
        expiresAt: Date?,
        revokedAt: Date?,
        lastVerifiedAt: Date
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.productIdentifier = productIdentifier
        self.environment = environment
        self.status = status
        self.active = active
        self.startsAt = startsAt
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
        self.lastVerifiedAt = lastVerifiedAt
    }
}

// Purpl 고객 정보
/// Information about the current Purpl customer and their entitlements.
public struct CustomerInfo: Decodable, Equatable, Sendable {
    // 고객 정보를 확인한 출처
    /// The source used to resolve the customer information.
    public let source: CustomerInfoSource

    // 현재 Apple 고객을 식별하는 앱 거래 식별자
    /// The app transaction identifier that identifies the current Apple customer.
    public let appTransactionIdentifier: String?

    // Purpl 내부 고객 식별자
    /// The internal Purpl customer identifier.
    public let customerIdentifier: String?
    // 고객에게 연결된 권한 목록
    /// The entitlements associated with the customer.
    public let entitlements: [CustomerEntitlement]

    // 현재 사용 가능한 권한 식별자
    /// The identifiers of entitlements that are currently available.
    public var activeEntitlementIdentifiers: Set<String> {
        Set(entitlements.lazy.filter(\.active).map(\.identifier))
    }

    // Purpl 고객 정보 생성
    /// Creates Purpl customer information.
    /// - Parameters:
    ///   - source: The source used to resolve the customer information.
    ///   - appTransactionIdentifier: The optional app transaction identifier verified by StoreKit.
    ///   - customerIdentifier: The optional internal customer identifier resolved by the server.
    ///   - entitlements: The customer's current entitlements.
    public init(
        source: CustomerInfoSource = .server,
        appTransactionIdentifier: String? = nil,
        customerIdentifier: String?,
        entitlements: [CustomerEntitlement]
    ) {
        self.source = source
        self.appTransactionIdentifier = appTransactionIdentifier
        self.customerIdentifier = customerIdentifier
        self.entitlements = entitlements
    }

    // Purpl 서버 고객 정보 해석
    /// Decodes customer information returned by the Purpl server.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        source = .server
        appTransactionIdentifier = nil
        customerIdentifier = try container.decodeIfPresent(
            String.self,
            forKey: .customerIdentifier
        )
        entitlements = try container.decode(
            [CustomerEntitlement].self,
            forKey: .entitlements
        )
    }

    // 지정한 권한을 현재 사용할 수 있는지 확인
    /// Returns whether the specified entitlement is currently active.
    /// - Parameter identifier: The entitlement identifier to check.
    /// - Returns: `true` when the entitlement is currently active; otherwise, `false`.
    public func isEntitlementActive(_ identifier: String) -> Bool {
        activeEntitlementIdentifiers.contains(identifier)
    }

    /// Purpl 서버 응답 필드
    private enum CodingKeys: String, CodingKey {
        /// Purpl 내부 고객 식별자
        case customerIdentifier

        /// 고객에게 연결된 권한 목록
        case entitlements
    }
}
