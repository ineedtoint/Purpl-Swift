//
//  CustomerInfoTaskTests.swift
//  PurplTests
//
//  Created by Int on 7/27/26.
//

import SwiftUI
import Testing
@testable import Purpl

/// 고객 정보 SwiftUI 작업 테스트
struct CustomerInfoTaskTests {
    /// 고객 정보 작업을 SwiftUI 뷰에 연결할 수 있는지 확인
    @Test @MainActor
    func customerInfoTaskCanBeAppliedToView() {
        let view = EmptyView().customerInfoTask(for: nil) { _ in }

        _ = view
    }
}
