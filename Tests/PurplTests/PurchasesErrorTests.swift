//
//  PurchasesErrorTests.swift
//  PurplTests
//
//  Created by Int on 7/27/26.
//

import Foundation
import Testing
@testable import Purpl

/// Purpl 오류 설명 테스트
struct PurchasesErrorTests {
    /// 지원하지 않는 StoreKit 상품 유형에 전용 오류 설명을 제공하는지 확인
    @Test
    func unsupportedProductTypeDescription() throws {
        let errorDescription = try #require(
            PurchasesError.unsupportedProductType.errorDescription
        )

        #expect(errorDescription.isEmpty == false)
        #expect(
            PurchasesError.unsupportedProductType.localizedDescription ==
                errorDescription
        )
    }

    /// 알 수 없는 StoreKit 구매 결과에 전용 오류 설명을 제공하는지 확인
    @Test
    func unknownPurchaseResultDescription() throws {
        let errorDescription = try #require(
            PurchasesError.unknownPurchaseResult.errorDescription
        )

        #expect(errorDescription.isEmpty == false)
        #expect(PurchasesError.unknownPurchaseResult.localizedDescription == errorDescription)
    }

    /// 서버 실패 응답 설명에 HTTP 상태와 오류 코드가 포함되는지 확인
    @Test
    func unsuccessfulServerResponseDescription() throws {
        let error = PurchasesError.unsuccessfulServerResponse(
            statusCode: 409,
            errorCode: "CUSTOMER_IDENTITY_CONFLICT"
        )
        let errorDescription = try #require(error.errorDescription)

        #expect(errorDescription.contains("409"))
        #expect(errorDescription.contains("CUSTOMER_IDENTITY_CONFLICT"))
        #expect(error.localizedDescription == errorDescription)
    }

    /// 서버 오류 코드가 없을 때 대체 코드가 표시되는지 확인
    @Test
    func unknownServerErrorCodeDescription() throws {
        let error = PurchasesError.unsuccessfulServerResponse(
            statusCode: 503,
            errorCode: nil
        )
        let errorDescription = try #require(error.errorDescription)

        #expect(errorDescription.contains("503"))
        #expect(errorDescription.contains("UNKNOWN_SERVER_ERROR"))
    }
}
