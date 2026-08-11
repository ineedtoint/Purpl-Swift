//
//  CustomerInfoStreamPublisher.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation
import Synchronization

/// 최신 고객 정보와 구독자를 관리하는 스트림 발행기
final class CustomerInfoStreamPublisher: Sendable {
    /// 고객 정보 스트림 공유 상태
    private struct State: Sendable {
        /// 마지막으로 전달한 고객 정보
        var latestCustomerInfo: CustomerInfo?
        /// 고객 정보 구독자
        var continuations: [UUID: AsyncStream<CustomerInfo>.Continuation] = [:]
    }

    /// 고객 정보 스트림 공유 상태
    private let state = Mutex(State())

    /// 마지막으로 전달한 고객 정보
    var latestCustomerInfo: CustomerInfo? {
        state.withLock(\.latestCustomerInfo)
    }

    /// 현재 고객 정보부터 전달하는 새 스트림 생성
    func makeStream() -> AsyncStream<CustomerInfo> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let continuationIdentifier = UUID()

            state.withLock { state in
                state.continuations[continuationIdentifier] = continuation

                if let latestCustomerInfo = state.latestCustomerInfo {
                    continuation.yield(latestCustomerInfo)
                }
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                self?.removeContinuation(continuationIdentifier)
            }
        }
    }

    /// 변경된 고객 정보를 모든 구독자에게 전달
    func publish(_ customerInfo: CustomerInfo) {
        let continuations = state.withLock { state in
            guard state.latestCustomerInfo != customerInfo else {
                return [AsyncStream<CustomerInfo>.Continuation]()
            }

            state.latestCustomerInfo = customerInfo
            return Array(state.continuations.values)
        }

        for continuation in continuations {
            continuation.yield(customerInfo)
        }
    }

    /// 종료한 고객 정보 구독자 제거
    private func removeContinuation(_ continuationIdentifier: UUID) {
        _ = state.withLock { state in
            state.continuations.removeValue(forKey: continuationIdentifier)
        }
    }
}
