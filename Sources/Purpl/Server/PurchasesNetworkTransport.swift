//
//  PurchasesNetworkTransport.swift
//  Purpl
//
//  Created by Int on 7/26/26.
//

import Foundation

/// Purpl 네트워크 응답
struct PurchasesNetworkResponse: Sendable {
    /// 응답 본문
    let data: Data
    /// HTTP 상태 코드
    let statusCode: Int
}

/// Purpl 네트워크 전송 인터페이스
protocol PurchasesNetworkTransportProtocol: Sendable {
    /// 네트워크 요청 전송
    func send(_ request: URLRequest) async throws -> PurchasesNetworkResponse
}

/// URLSession 기반 Purpl 네트워크 전송
struct URLSessionPurchasesNetworkTransport: PurchasesNetworkTransportProtocol {
    private let session: URLSession

    /// URLSession 기반 네트워크 전송 생성
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 네트워크 요청 전송
    func send(_ request: URLRequest) async throws -> PurchasesNetworkResponse {
        let (data, response) = try await session.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw PurchasesError.invalidServerResponse
        }

        return PurchasesNetworkResponse(
            data: data,
            statusCode: response.statusCode
        )
    }
}
