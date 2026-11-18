//
//  SignedPurchasesPayload.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

/// 서버에 전달할 검증된 StoreKit 정보
struct SignedPurchasesPayload: Equatable, Sendable {
    /// StoreKit AppTransaction JWS
    let signedAppTransaction: String

    /// 현재 검증된 StoreKit 거래 JWS 목록
    let signedTransactions: [String]

    /// 선택 개발자 앱 내부 계정 식별자
    let applicationAccountIdentifier: String?

    /// 직접 로그인으로 요청한 경우에만 구매 계정 이전
    var transferOnLogin = false
}
