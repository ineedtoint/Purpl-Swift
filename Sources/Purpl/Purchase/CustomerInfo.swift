//
//  CustomerInfo.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

/// 스토어 환경
public enum StoreEnvironment: String, Decodable, Hashable, Sendable {
    /// 운영 환경
    case production
    /// 샌드박스 환경
    case sandbox
    /// Xcode StoreKit Configuration 환경
    case xcode
}

/// 고객 권한 상태
public enum CustomerEntitlementStatus: String, Decodable, Hashable, Sendable {
    /// 사용 가능한 상태
    case active
    /// 유예 기간 상태
    case gracePeriod = "grace_period"
    /// 결제 재시도 상태
    case billingRetry = "billing_retry"
    /// 일시 중지 상태
    case paused
    /// 만료 상태
    case expired
    /// 회수 상태
    case revoked
}

/// 고객 정보 확인 출처
public enum CustomerInfoSource: Equatable, Sendable {
    /// Purpl 서버
    case server

    /// 현재 기기의 StoreKit
    case storeKit
}

/// 고객에게 연결된 권한
public struct CustomerEntitlement: Decodable, Equatable, Sendable {
    /// 권한 식별자
    public let identifier: String
    /// 권한 표시 이름
    public let displayName: String
    /// 권한을 제공한 스토어 상품 식별자
    public let productIdentifier: String?
    /// 권한을 확인한 스토어 환경
    public let environment: StoreEnvironment
    /// 현재 권한 상태
    public let status: CustomerEntitlementStatus
    /// 현재 사용 가능 여부
    public let active: Bool
    /// 권한 시작 시각
    public let startsAt: Date?
    /// 권한 만료 시각
    public let expiresAt: Date?
    /// 권한 회수 시각
    public let revokedAt: Date?
    /// 마지막 검증 시각
    public let lastVerifiedAt: Date

    /// 고객 권한 생성
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

/// Purpl 고객 정보
public struct CustomerInfo: Decodable, Equatable, Sendable {
    /// 고객 정보를 확인한 출처
    public let source: CustomerInfoSource

    /// 현재 Apple 고객을 식별하는 앱 거래 식별자
    public let appTransactionIdentifier: String?

    /// Purpl 내부 고객 식별자
    public let customerIdentifier: String?
    /// 고객에게 연결된 권한 목록
    public let entitlements: [CustomerEntitlement]

    /// 현재 사용 가능한 권한 식별자
    public var activeEntitlementIdentifiers: Set<String> {
        Set(entitlements.lazy.filter(\.active).map(\.identifier))
    }

    /// Purpl 고객 정보 생성
    /// - Parameters:
    ///   - source: 고객 정보를 확인한 출처
    ///   - appTransactionIdentifier: StoreKit이 확인한 선택 앱 거래 식별자
    ///   - customerIdentifier: 서버가 확인한 선택 내부 고객 식별자
    ///   - entitlements: 고객에게 연결된 현재 권한 목록
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

    /// Purpl 서버 고객 정보 해석
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

    /// 지정한 권한을 현재 사용할 수 있는지 확인
    /// - Parameter identifier: 확인할 권한 식별자
    /// - Returns: 지정한 권한의 현재 사용 가능 여부
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
