//
//  EntitlementSynchronizationResult.swift
//  Purpl
//
//  Created by Int on 11/12/26.
//

import Foundation

/// 현재 권한 웹훅의 전달 상태
public enum EntitlementRepublicationStatus: String, Decodable, Sendable {
    /// 전달 대기 또는 실패 후 재시도 중
    case queued
    /// 모든 목적지에서 성공 응답 수신
    case delivered
    /// 재시도 한도 도달 등으로 전달 실패
    case failed
    /// 서버를 사용하지 않거나 전달할 권한·목적지 없음
    case notRequired = "not_required"
}

/// 웹훅 재전송 접수와 실제 전달 완료를 구분하는 결과
public struct EntitlementRepublication: Decodable, Sendable {
    /// 상태 재확인에 사용하는 원래 또는 병합된 요청 식별자
    public let requestIdentifier: UUID
    /// 웹훅 전달 상태
    public let status: EntitlementRepublicationStatus
    /// 웹훅 전달 작업 수
    public let deliveryCount: Int
}

/// 현재 고객 정보와 권한 웹훅 재전송 결과
public struct EntitlementSynchronizationResult: Decodable, Sendable {
    /// 검증된 최신 고객 정보
    public let customerInfo: CustomerInfo
    /// 웹훅 전달 결과
    public let republication: EntitlementRepublication

    /// 고객 정보와 웹훅 전달 결과 구성
    init(customerInfo: CustomerInfo, republication: EntitlementRepublication) {
        self.customerInfo = customerInfo
        self.republication = republication
    }

    /// 고객 정보와 재전송 결과를 포함한 서버 응답 해석
    public init(from decoder: any Decoder) throws {
        customerInfo = try CustomerInfo(from: decoder)
        republication = try decoder.container(keyedBy: CodingKeys.self)
            .decode(EntitlementRepublication.self, forKey: .republication)
    }

    /// 서버 재전송 응답 키
    private enum CodingKeys: String, CodingKey {
        case republication
    }
}
