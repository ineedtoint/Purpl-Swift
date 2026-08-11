//
//  VerifiedAppTransaction.swift
//  Purpl
//
//  Created by Int on 7/27/26.
//

import StoreKit

/// Apple이 검증한 StoreKit 앱 거래
struct VerifiedAppTransaction: Sendable {
    /// 검증된 AppTransaction JWS
    let signedAppTransaction: String

    /// Apple 앱 거래 식별자
    let appTransactionIdentifier: String

    /// AppTransaction을 발급한 StoreKit 환경
    let environment: AppStore.Environment

    /// 검증된 StoreKit 앱 거래 생성
    init(
        signedAppTransaction: String,
        appTransactionIdentifier: String,
        environment: AppStore.Environment
    ) {
        self.signedAppTransaction = signedAppTransaction
        self.appTransactionIdentifier = appTransactionIdentifier
        self.environment = environment
    }
}
