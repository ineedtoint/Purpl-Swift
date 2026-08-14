//
//  PurchasesError.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

// Purpl 처리 오류
/// An error produced while Purpl processes a request.
public enum PurchasesError: LocalizedError, Equatable, Sendable {
    // 현재 기능에 필요한 구매 카탈로그가 설정되지 않음
    /// The purchase configuration required by the current operation is missing.
    case missingPurchaseConfiguration
    // Purpl에서 지원하지 않는 StoreKit 상품 유형
    /// The StoreKit product type isn't supported by Purpl.
    case unsupportedProductType
    // AppTransaction 검증 실패
    /// AppTransaction verification failed.
    case unverifiedAppTransaction
    // StoreKit 거래 검증 실패
    /// StoreKit transaction verification failed.
    case unverifiedTransaction
    // 현재 SDK에서 알 수 없는 StoreKit 구매 결과
    /// StoreKit returned a purchase result that this SDK doesn't recognize.
    case unknownPurchaseResult
    // 서버가 올바른 HTTP 응답을 반환하지 않음
    /// The server didn't return a valid HTTP response.
    case invalidServerResponse
    // 서버 응답 상태 코드가 성공 범위가 아님
    /// The server response status code isn't in the successful range.
    case unsuccessfulServerResponse(statusCode: Int, errorCode: String?)

    // 개발자 로그에 표시할 현지화 오류 설명
    /// A localized error description for developer logs.
    public var errorDescription: String? {
        switch self {
        case .missingPurchaseConfiguration:
            return String(
                localized: "purchases.error.missingPurchaseConfiguration",
                bundle: .module,
                comment: "구매 카탈로그가 설정되지 않았습니다."
            )

        case .unsupportedProductType:
            return String(
                localized: "purchases.error.unsupportedProductType",
                bundle: .module,
                comment: "Purpl에서 지원하지 않는 StoreKit 상품 유형입니다."
            )

        case .unverifiedAppTransaction:
            return String(
                localized: "purchases.error.unverifiedAppTransaction",
                bundle: .module,
                comment: "AppTransaction 검증에 실패했습니다."
            )

        case .unverifiedTransaction:
            return String(
                localized: "purchases.error.unverifiedTransaction",
                bundle: .module,
                comment: "StoreKit 거래 검증에 실패했습니다."
            )

        case .unknownPurchaseResult:
            return String(
                localized: "purchases.error.unknownPurchaseResult",
                bundle: .module,
                comment: "알 수 없는 StoreKit 구매 결과를 받았습니다."
            )

        case .invalidServerResponse:
            return String(
                localized: "purchases.error.invalidServerResponse",
                bundle: .module,
                comment: "Purpl 서버 응답을 해석하지 못했습니다."
            )

        case .unsuccessfulServerResponse(let statusCode, let errorCode):
            let messageFormat = String(
                localized: "purchases.error.unsuccessfulServerResponse",
                defaultValue: "Purpl 서버 요청 실패: HTTP %1$lld, %2$@",
                bundle: .module,
                comment: "Purpl 서버 요청 실패: HTTP 상태 코드, 서버 오류 코드"
            )

            return String(
                format: messageFormat,
                locale: .current,
                statusCode,
                errorCode ?? "UNKNOWN_SERVER_ERROR"
            )
        }
    }
}
