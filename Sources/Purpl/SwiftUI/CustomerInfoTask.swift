//
//  CustomerInfoTask.swift
//  Purpl
//
//  Created by Int on 7/27/26.
//

import Foundation
import SwiftUI

// 고객 정보 작업 상태
/// The state of a customer information task.
public enum CustomerInfoTaskState {
    // 최초 고객 정보 확인 중
    /// The task is loading the initial customer information.
    case loading

    // 고객 정보 확인 성공
    /// The task loaded customer information successfully.
    case success(CustomerInfo)

    // 고객 정보 확인 실패
    /// The task failed to load customer information.
    case failure(any Error)
}

public extension View {
    // 뷰가 표시되는 동안 고객 정보를 동기화하고 이후 변경을 전달
    /// Synchronizes customer information while the view is visible and delivers subsequent updates.
    ///
    /// Call ``Purchases/configure(_:)`` or ``Purchases/configure(_:entitlementMode:)`` before using this modifier.
    ///
    /// - Parameters:
    ///   - applicationAccountIdentifier: An optional UUID that links the current app user as an additional customer identity.
    ///   - priority: The priority of the customer information task.
    ///   - action: An asynchronous action that runs when the customer information task state changes.
    /// - Returns: A view with the customer information task attached.
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
