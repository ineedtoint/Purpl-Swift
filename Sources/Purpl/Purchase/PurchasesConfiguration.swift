//
//  PurchasesConfiguration.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

// 고객 권한을 확인하는 방식
/// The method used to resolve customer entitlements.
public enum EntitlementMode: Equatable, Sendable {
    // Purpl 서버 권한 사용
    /// Uses entitlements from the Purpl server.
    case server

    // Purpl 서버를 우선하고 실패하면 StoreKit 권한 사용
    /// Uses the Purpl server first and falls back to StoreKit when the server request fails.
    case serverWithStoreKitFallback

    // Purpl 서버 없이 StoreKit 권한만 사용
    /// Uses only StoreKit entitlements without the Purpl server.
    case storeKit
}

/// Purpl 내부 실행 설정
struct PurchasesConfiguration: Sendable {
    /// 운영 Purpl 서버 기준 주소
    static let productionServerBaseURL = URL(
        string: "https://api.purpl.sh"
    )!

    /// Purpl 서버 기준 주소
    let serverBaseURL: URL

    /// 앱 전체 구매 구성
    let purchaseConfiguration: PurchaseConfiguration?

    /// 고객 권한 확인 방식
    let entitlementMode: EntitlementMode

    /// Purpl 서버 연결 설정 생성
    init(
        serverBaseURL: URL = Self.productionServerBaseURL,
        purchaseConfiguration: PurchaseConfiguration? = nil,
        entitlementMode: EntitlementMode = .server
    ) {
        self.serverBaseURL = serverBaseURL
        self.purchaseConfiguration = purchaseConfiguration
        self.entitlementMode = entitlementMode
    }
}
