//
//  RemotePaywallCache.swift
//  Purpl
//
//  Created by Int on 8/11/26.
//

import Foundation

/// 앱 샌드박스에 원격 페이월 응답을 저장하는 캐시
actor RemotePaywallCache {
    /// 캐시 디렉터리 주소
    private let directoryURL: URL

    /// 파일 관리자
    private let fileManager: FileManager

    /// 기본 앱 샌드박스 캐시 생성
    init(fileManager: FileManager = .default) {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        self.init(
            directoryURL: applicationSupportURL
                .appending(path: "Purpl", directoryHint: .isDirectory)
                .appending(path: "Paywalls", directoryHint: .isDirectory),
            fileManager: fileManager
        )
    }

    /// 지정 디렉터리를 사용하는 캐시 생성
    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    /// 페이월과 로케일 식별자의 캐시 조회
    func load(
        paywallIdentifier: String,
        localeIdentifier: String = Locale.current.identifier
    ) -> RemotePaywallResponse? {
        let fileURL = fileURL(
            paywallIdentifier: paywallIdentifier,
            localeIdentifier: localeIdentifier
        )

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        do {
            return try Self.makeDecoder().decode(
                RemotePaywallResponse.self,
                from: data
            )
        } catch {
            // 손상된 캐시가 다음 실행까지 반복 사용되지 않도록 즉시 제거한다.
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }

    /// 원격 페이월 응답 캐시 저장
    func save(
        _ response: RemotePaywallResponse,
        paywallIdentifier: String,
        localeIdentifier: String = Locale.current.identifier
    ) throws {
        try prepareDirectoryIfNeeded()
        let data = try Self.makeEncoder().encode(response)

        // 중간 상태 파일이 남지 않도록 같은 볼륨에서 원자적으로 교체한다.
        try data.write(
            to: fileURL(
                paywallIdentifier: paywallIdentifier,
                localeIdentifier: localeIdentifier
            ),
            options: .atomic
        )
    }

    /// 지정 페이월과 로케일의 원격 응답 캐시 제거
    func remove(
        paywallIdentifier: String,
        localeIdentifier: String = Locale.current.identifier
    ) {
        try? fileManager.removeItem(at: fileURL(
            paywallIdentifier: paywallIdentifier,
            localeIdentifier: localeIdentifier
        ))
    }

    /// 캐시 디렉터리 생성과 백업 제외 설정
    private func prepareDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDirectoryURL = directoryURL
        try mutableDirectoryURL.setResourceValues(resourceValues)
    }

    /// 페이월과 로케일 식별자의 캐시 파일 주소 생성
    private func fileURL(
        paywallIdentifier: String,
        localeIdentifier: String
    ) -> URL {
        let normalizedLocaleIdentifier = localeIdentifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        let cacheIdentifier = "\(paywallIdentifier):\(normalizedLocaleIdentifier)"
        let encodedIdentifier = Data(cacheIdentifier.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")

        return directoryURL.appending(path: "\(encodedIdentifier).json")
    }

    /// 서버 날짜를 처리하는 JSON 디코더 생성
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// 서버 날짜를 보존하는 JSON 인코더 생성
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
