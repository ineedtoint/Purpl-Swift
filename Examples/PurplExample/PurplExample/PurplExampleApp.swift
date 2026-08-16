//
//  PurplExampleApp.swift
//  PurplExample
//
//  Created by Int on 8/17/26.
//

import Purpl
import SwiftUI

/// Purpl 로컬 구매 예제 앱
@main
struct PurplExampleApp: App {
    /// 로컬 StoreKit 권한 확인을 사용하는 예제 앱 생성
    init() {
        Purchases.configure(ExamplePurchaseConfiguration.default)
    }

    /// 예제 앱 화면 구성
    var body: some Scene {
        WindowGroup {
            ExamplePaywallView()
        }
    }
}
