//
//  CustomerInfoTask.swift
//  Purpl
//
//  Created by Int on 7/27/26.
//

import Foundation
import SwiftUI

/// 고객 정보 작업 상태
public enum CustomerInfoTaskState {
    /// 최초 고객 정보 확인 중
    case loading

    /// 고객 정보 확인 성공
    case success(CustomerInfo)

    /// 고객 정보 확인 실패
    case failure(any Error)
}

public extension View {
    /// 뷰가 표시되는 동안 고객 정보를 동기화하고 이후 변경을 전달
    ///
    /// 앱 실행 중 `Purchases.configure`를 먼저 호출해야 한다.
    ///
    /// - Parameters:
    ///   - applicationAccountIdentifier: 현재 앱 사용자를 고객의 추가 신원으로 연결할 선택 UUID
    ///   - priority: 고객 정보 작업 우선순위
    ///   - action: 고객 정보 작업 상태가 변경될 때 실행할 비동기 작업
    /// - Returns: 고객 정보 작업을 연결한 뷰
    func customerInfoTask(
        for applicationAccountIdentifier: UUID?,
        priority: TaskPriority = .medium,
        action: @escaping @MainActor (CustomerInfoTaskState) async -> Void
    ) -> some View {
        task(id: applicationAccountIdentifier, priority: priority) {
            let purchases = Purchases.shared
            var lastDeliveredCustomerInfo = purchases.latestCustomerInfo

            await action(.loading)

            do {
                let customerInfo = try await purchases.customerInfo(
                    applicationAccountIdentifier: applicationAccountIdentifier
                )
                lastDeliveredCustomerInfo = customerInfo
                await action(.success(customerInfo))
            } catch is CancellationError {
                return
            } catch {
                await action(.failure(error))
            }

            // 최초 동기화 결과의 중복 전달을 건너뛰고 이후 변경만 전달한다.
            for await customerInfo in purchases.customerInfoStream {
                guard Task.isCancelled == false else {
                    return
                }
                guard customerInfo != lastDeliveredCustomerInfo else {
                    continue
                }

                lastDeliveredCustomerInfo = customerInfo
                await action(.success(customerInfo))
            }
        }
    }
}
