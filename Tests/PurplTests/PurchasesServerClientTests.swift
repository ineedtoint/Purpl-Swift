//
//  PurchasesServerClientTests.swift
//  PurplTests
//
//  Created by Int on 7/26/26.
//

import Foundation
import Testing
@testable import Purpl

/// Purpl 서버 요청 테스트
struct PurchasesServerClientTests {
    /// 공개 Bundle ID와 페이월 및 로케일 식별자로 원격 구매 구성을 조회하는지 확인
    @Test
    func paywall() async throws {
        let responseData = Data(
            """
            {
              "paywallConfiguration": {
                "identifier": "standard",
                "catalogIdentifier": "standard",
                "defaultProductIdentifier": "test.subscription.yearly"
              },
              "catalog": {
                "identifier": "standard",
                "productIdentifiers": [
                  "test.subscription.monthly",
                  "test.subscription.yearly"
                ]
              },
              "purchaseConfiguration": {
                "entitlements": [{ "identifier": "access" }],
                "products": [
                  {
                    "productIdentifier": "test.subscription.monthly",
                    "entitlementIdentifiers": ["access"]
                  },
                  {
                    "productIdentifier": "test.subscription.yearly",
                    "entitlementIdentifiers": ["access"]
                  }
                ]
              },
              "localization": {
                "localeIdentifier": "ko",
                "products": [
                  {
                    "productIdentifier": "test.subscription.yearly",
                    "title": "연간",
                    "description": "프리미엄 기능"
                  }
                ],
                "autoRenewalNotice": "구독은 자동으로 갱신됩니다."
              },
              "policy": {
                "privacyPolicyURL": "https://example.com/privacy",
                "termsOfServiceURL": "https://example.com/terms"
              },
              "updatedAt": "2026-08-11T01:02:03.456Z"
            }
            """.utf8
        )
        let networkTransport = PurchasesNetworkTransportSpy(
            response: PurchasesNetworkResponse(data: responseData, statusCode: 200)
        )
        let serverBaseURL = try #require(URL(string: "https://api.purpl.sh/base"))
        let serverClient = PurchasesServerClient(
            configuration: PurchasesConfiguration(serverBaseURL: serverBaseURL),
            networkTransport: networkTransport
        )

        let paywall = try await serverClient.paywall(
            paywallIdentifier: "standard",
            bundleIdentifier: "com.example.app",
            localeIdentifier: "ko-KR"
        )
        let receivedRequest = try #require(await networkTransport.receivedRequest())
        let queryItems = URLComponents(
            url: try #require(receivedRequest.url),
            resolvingAgainstBaseURL: false
        )?.queryItems

        #expect(receivedRequest.url?.path == "/base/v1/paywalls/apple")
        #expect(receivedRequest.httpMethod == "GET")
        #expect(receivedRequest.httpBody == nil)
        #expect(
            queryItems?.first(where: { $0.name == "bundleIdentifier" })?.value
                == "com.example.app"
        )
        #expect(
            queryItems?.first(where: { $0.name == "paywallIdentifier" })?.value
                == "standard"
        )
        #expect(
            queryItems?.first(where: { $0.name == "localeIdentifier" })?.value
                == "ko-KR"
        )
        #expect(paywall.paywallConfiguration.identifier == "standard")
        #expect(paywall.catalog.productIdentifiers == [
            "test.subscription.monthly",
            "test.subscription.yearly"
        ])
        #expect(
            paywall.purchaseConfiguration.entitlements.map(\.identifier)
                == ["access"]
        )
    }

    /// Apple 고객 동기화 경로와 요청 본문 및 응답 해석 확인
    @Test
    func synchronizeCustomer() async throws {
        let responseData = Data(
            """
            {
              "customerIdentifier": "customer-identifier",
              "entitlements": [
                {
                  "identifier": "access",
                  "displayName": "Access",
                  "productIdentifier": "test.subscription.monthly",
                  "environment": "production",
                  "status": "active",
                  "active": true,
                  "startsAt": "2026-07-26T01:02:03.456Z",
                  "expiresAt": null,
                  "revokedAt": null,
                  "lastVerifiedAt": "2026-07-26T01:02:03Z"
                }
              ]
            }
            """.utf8
        )
        let networkTransport = PurchasesNetworkTransportSpy(
            response: PurchasesNetworkResponse(data: responseData, statusCode: 200)
        )
        let serverBaseURL = try #require(URL(string: "https://purchases.example.com/base"))
        let serverClient = PurchasesServerClient(
            configuration: PurchasesConfiguration(serverBaseURL: serverBaseURL),
            networkTransport: networkTransport
        )
        let payload = SignedPurchasesPayload(
            signedAppTransaction: "signed-app-transaction",
            signedTransactions: ["signed-transaction"],
            applicationAccountIdentifier: "flow-user-identifier"
        )

        let customerInfo = try await serverClient.synchronizeCustomer(with: payload)
        let receivedRequest = try #require(await networkTransport.receivedRequest())
        let requestBodyData = try #require(receivedRequest.httpBody)
        let requestBody = try #require(
            JSONSerialization.jsonObject(with: requestBodyData) as? [String: Any]
        )

        #expect(receivedRequest.url?.path == "/base/v1/customers/apple/synchronize")
        #expect(receivedRequest.httpMethod == "POST")
        #expect(requestBody["signedAppTransaction"] as? String == "signed-app-transaction")
        #expect(requestBody["signedTransactions"] as? [String] == ["signed-transaction"])
        #expect(
            requestBody["applicationAccountIdentifier"] as? String ==
                "flow-user-identifier"
        )
        #expect(customerInfo.customerIdentifier == "customer-identifier")
        #expect(customerInfo.appTransactionIdentifier == nil)
        #expect(customerInfo.source == .server)
        #expect(customerInfo.activeEntitlementIdentifiers == ["access"])
        #expect(
            customerInfo.entitlements.first?.productIdentifier ==
                "test.subscription.monthly"
        )
    }

    /// 서버 실패 응답의 상태 코드와 오류 코드 전달 확인
    @Test
    func unsuccessfulServerResponse() async throws {
        let networkTransport = PurchasesNetworkTransportSpy(
            response: PurchasesNetworkResponse(
                data: Data(#"{"error":"INVALID_REQUEST"}"#.utf8),
                statusCode: 400
            )
        )
        let serverBaseURL = try #require(URL(string: "https://purchases.example.com"))
        let serverClient = PurchasesServerClient(
            configuration: PurchasesConfiguration(serverBaseURL: serverBaseURL),
            networkTransport: networkTransport
        )
        let payload = SignedPurchasesPayload(
            signedAppTransaction: "signed-app-transaction",
            signedTransactions: [],
            applicationAccountIdentifier: nil
        )

        await #expect(throws: PurchasesError.unsuccessfulServerResponse(
            statusCode: 400,
            errorCode: "INVALID_REQUEST"
        )) {
            try await serverClient.synchronizeCustomer(with: payload)
        }
    }
}

/// 테스트용 Purpl 네트워크 요청 기록기
private actor PurchasesNetworkTransportSpy: PurchasesNetworkTransportProtocol {
    private let response: PurchasesNetworkResponse
    private var sentRequest: URLRequest?

    /// 테스트용 네트워크 요청 기록기 생성
    init(response: PurchasesNetworkResponse) {
        self.response = response
    }

    /// 전달받은 요청을 기록하고 준비된 응답 반환
    func send(_ request: URLRequest) async throws -> PurchasesNetworkResponse {
        sentRequest = request
        return response
    }

    /// 마지막으로 전달받은 네트워크 요청 조회
    func receivedRequest() -> URLRequest? {
        sentRequest
    }
}
