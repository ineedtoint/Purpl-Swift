//
//  PurchasesServerClient.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

/// Purpl 서버 클라이언트 인터페이스
protocol PurchasesServerClientProtocol: Sendable {
    /// 구매 전 로그인 계정의 관리자 부여 권한 조회
    func identifyAccount(_ identifier: UUID, email: String?, environment: StoreEnvironment) async throws -> [CustomerEntitlement]

    /// 검증된 StoreKit 정보로 현재 고객 동기화
    func synchronizeCustomer(with payload: SignedPurchasesPayload) async throws -> CustomerInfo

    /// 검증된 StoreKit 정보로 현재 권한 웹훅 재전송
    func republishEntitlements(with payload: SignedPurchasesPayload, requestIdentifier: UUID) async throws -> EntitlementSynchronizationResult

    /// 공개 Bundle ID로 원격 페이월 조회
    func paywall(
        paywallIdentifier: String,
        bundleIdentifier: String,
        localeIdentifier: String
    ) async throws -> RemotePaywallResponse

}

extension PurchasesServerClientProtocol {
    /// 재전송을 구현하지 않은 서버 경계의 명시적인 실패
    func republishEntitlements(with payload: SignedPurchasesPayload, requestIdentifier: UUID) async throws -> EntitlementSynchronizationResult {
        throw PurchasesError.invalidServerResponse
    }

    /// 구매 전 계정 조회를 사용하지 않는 테스트 서버의 기본 응답
    func identifyAccount(_ identifier: UUID, email: String?, environment: StoreEnvironment) async throws -> [CustomerEntitlement] { [] }

    /// 원격 페이월을 사용하지 않는 테스트 경계의 기본 동작
    func paywall(
        paywallIdentifier: String,
        bundleIdentifier: String,
        localeIdentifier: String
    ) async throws -> RemotePaywallResponse {
        throw PurchasesError.invalidServerResponse
    }
}

/// Purpl 서버 클라이언트 구현
struct PurchasesServerClient: PurchasesServerClientProtocol {
    private let serverBaseURL: URL
    private let networkTransport: any PurchasesNetworkTransportProtocol

    /// 앱 범위에서 로그인 계정과 선택 이메일을 등록하고 권한 조회
    func identifyAccount(_ identifier: UUID, email: String?, environment: StoreEnvironment) async throws -> [CustomerEntitlement] {
        guard let bundle = Bundle.main.bundleIdentifier else { throw PurchasesError.invalidServerResponse }
        var body = ["provider": "apple", "storeApplicationIdentifier": bundle,
                    "environment": environment == .production ? "production" : "sandbox",
                    "applicationAccountIdentifier": identifier.uuidString.lowercased()]
        body["email"] = email
        var request = URLRequest(url: serverBaseURL.appending(path: "v1/customers/account/identify"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let response = try await networkTransport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw PurchasesError.unsuccessfulServerResponse(statusCode: response.statusCode, errorCode: nil)
        }
        return try Self.makeResponseDecoder().decode(CustomerInfo.self, from: response.data).entitlements
    }

    /// Purpl 서버 클라이언트 생성
    init(
        configuration: PurchasesConfiguration,
        networkTransport: any PurchasesNetworkTransportProtocol = URLSessionPurchasesNetworkTransport()
    ) {
        serverBaseURL = configuration.serverBaseURL
        self.networkTransport = networkTransport
    }

    /// 검증된 StoreKit 정보로 현재 고객 동기화
    func synchronizeCustomer(with payload: SignedPurchasesPayload) async throws -> CustomerInfo {
        let endpointURL = serverBaseURL
            .appending(path: "v1")
            .appending(path: "customers")
            .appending(path: "apple")
            .appending(path: "synchronize")
        let requestBody = AppleCustomerSynchronizationRequest(
            signedAppTransaction: payload.signedAppTransaction,
            signedTransactions: payload.signedTransactions,
            applicationAccountIdentifier: payload.applicationAccountIdentifier
        )
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let response = try await networkTransport.send(request)

        guard (200..<300).contains(response.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(
                PurchasesServerErrorResponse.self,
                from: response.data
            )
            throw PurchasesError.unsuccessfulServerResponse(
                statusCode: response.statusCode,
                errorCode: errorResponse?.error
            )
        }

        do {
            return try Self.makeResponseDecoder().decode(CustomerInfo.self, from: response.data)
        } catch {
            throw PurchasesError.invalidServerResponse
        }
    }

    /// 별도 복구 API로 현재 권한 웹훅 재전송 접수 또는 상태 재확인
    func republishEntitlements(with payload: SignedPurchasesPayload, requestIdentifier: UUID) async throws -> EntitlementSynchronizationResult {
        var request = URLRequest(url: serverBaseURL.appending(path: "v1/customers/entitlements/republish"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AppleEntitlementRepublicationRequest(
            provider: "apple", requestIdentifier: requestIdentifier.uuidString.lowercased(),
            signedAppTransaction: payload.signedAppTransaction,
            signedTransactions: payload.signedTransactions,
            applicationAccountIdentifier: payload.applicationAccountIdentifier
        ))
        let response = try await networkTransport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(PurchasesServerErrorResponse.self, from: response.data)
            throw PurchasesError.unsuccessfulServerResponse(statusCode: response.statusCode, errorCode: errorResponse?.error)
        }
        do {
            return try Self.makeResponseDecoder().decode(EntitlementSynchronizationResult.self, from: response.data)
        } catch {
            throw PurchasesError.invalidServerResponse
        }
    }

    /// 공개 Bundle ID로 원격 페이월 조회
    func paywall(
        paywallIdentifier: String,
        bundleIdentifier: String,
        localeIdentifier: String = Locale.current.identifier
    ) async throws -> RemotePaywallResponse {
        let endpointURL = serverBaseURL
            .appending(path: "v1")
            .appending(path: "paywalls")
            .appending(path: "apple")
        var endpointComponents = URLComponents(
            url: endpointURL,
            resolvingAgainstBaseURL: false
        )
        endpointComponents?.queryItems = [
            URLQueryItem(
                name: "bundleIdentifier",
                value: bundleIdentifier
            ),
            URLQueryItem(
                name: "paywallIdentifier",
                value: paywallIdentifier
            ),
            URLQueryItem(
                name: "localeIdentifier",
                value: localeIdentifier
            )
        ]

        guard let requestURL = endpointComponents?.url else {
            throw PurchasesError.invalidServerResponse
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"

        let response = try await networkTransport.send(request)

        guard (200..<300).contains(response.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(
                PurchasesServerErrorResponse.self,
                from: response.data
            )
            throw PurchasesError.unsuccessfulServerResponse(
                statusCode: response.statusCode,
                errorCode: errorResponse?.error
            )
        }

        do {
            return try Self.makeResponseDecoder().decode(
                RemotePaywallResponse.self,
                from: response.data
            )
        } catch {
            throw PurchasesError.invalidServerResponse
        }
    }

    /// 서버의 ISO 8601 시각을 처리하는 응답 디코더 생성
    private static func makeResponseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let fractionalSecondsFormatter = ISO8601DateFormatter()
            fractionalSecondsFormatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            if let date = fractionalSecondsFormatter.date(from: dateString) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]

            guard let date = formatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "ISO 8601 시각 형식이 올바르지 않습니다."
                )
            }

            return date
        }
        return decoder
    }
}

/// Apple 고객 동기화 요청 본문
private struct AppleCustomerSynchronizationRequest: Encodable {
    /// StoreKit AppTransaction JWS
    let signedAppTransaction: String
    /// 검증된 StoreKit 거래 JWS 목록
    let signedTransactions: [String]
    /// 선택 개발자 앱 내부 계정 식별자
    let applicationAccountIdentifier: String?
}

/// Purpl 서버 오류 응답
private struct PurchasesServerErrorResponse: Decodable {
    /// 서버 오류 코드
    let error: String
}

/// StoreKit 증빙과 멱등 식별자를 포함한 권한 재전송 요청
private struct AppleEntitlementRepublicationRequest: Encodable {
    /// 스토어 공급자
    let provider: String
    /// 복구 요청 식별자
    let requestIdentifier: String
    /// 검증할 앱 거래
    let signedAppTransaction: String
    /// 검증할 현재 거래 목록
    let signedTransactions: [String]
    /// 연결할 앱 계정 식별자
    let applicationAccountIdentifier: String?
}
