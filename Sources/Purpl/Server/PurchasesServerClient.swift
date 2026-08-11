//
//  PurchasesServerClient.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

/// Purpl 서버 클라이언트 인터페이스
protocol PurchasesServerClientProtocol: Sendable {
    /// 검증된 StoreKit 정보로 현재 고객 동기화
    func synchronizeCustomer(with payload: SignedPurchasesPayload) async throws -> CustomerInfo

    /// 공개 Bundle ID로 원격 페이월 조회
    func paywall(
        paywallIdentifier: String,
        bundleIdentifier: String
    ) async throws -> RemotePaywallResponse

}

extension PurchasesServerClientProtocol {
    /// 원격 페이월을 사용하지 않는 테스트 경계의 기본 동작
    func paywall(
        paywallIdentifier: String,
        bundleIdentifier: String
    ) async throws -> RemotePaywallResponse {
        throw PurchasesError.invalidServerResponse
    }
}

/// Purpl 서버 클라이언트 구현
struct PurchasesServerClient: PurchasesServerClientProtocol {
    private let serverBaseURL: URL
    private let networkTransport: any PurchasesNetworkTransportProtocol

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

    /// 공개 Bundle ID로 원격 페이월 조회
    func paywall(
        paywallIdentifier: String,
        bundleIdentifier: String
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
