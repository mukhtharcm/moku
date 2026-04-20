import Foundation

/// Lightweight PocketBase REST client using URLSession.
/// Handles auth, CRUD, file uploads, and token persistence.
@MainActor
@Observable
final class PocketBaseClient {
    var serverURL: String = ""
    var authToken: String?
    var userId: String?
    var isAuthenticated: Bool { authToken != nil }

    private let session = URLSession.shared

    // MARK: - Auth

    func login(email: String, password: String) async throws {
        let url = apiURL("collections/users/auth-with-password")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "identity": email,
            "password": password,
        ])

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        authToken = json?["token"] as? String
        if let record = json?["record"] as? [String: Any] {
            userId = record["id"] as? String
        }
        saveAuthToKeychain()
    }

    func register(email: String, password: String) async throws {
        let url = apiURL("collections/users/records")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "passwordConfirm": password,
        ])

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        // Auto-login after registration
        try await login(email: email, password: password)
    }

    func logout() {
        authToken = nil
        userId = nil
        removeAuthFromKeychain()
    }

    func restoreAuth() {
        loadAuthFromKeychain()
    }

    // MARK: - CRUD

    func getFullList(collection: String, filter: String? = nil) async throws -> [[String: Any]] {
        var components = URLComponents(url: apiURL("collections/\(collection)/records"), resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "perPage", value: "500")]
        if let filter {
            queryItems.append(URLQueryItem(name: "filter", value: filter))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        addAuth(&request)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]] ?? []

        // Handle pagination — if totalItems > items.count, fetch more pages
        let totalItems = json?["totalItems"] as? Int ?? items.count
        if totalItems > items.count {
            var allItems = items
            let perPage = 500
            let totalPages = (totalItems + perPage - 1) / perPage
            for page in 2...totalPages {
                var pageComponents = components
                var pq = queryItems
                pq.append(URLQueryItem(name: "page", value: "\(page)"))
                pageComponents.queryItems = pq
                var pageRequest = URLRequest(url: pageComponents.url!)
                addAuth(&pageRequest)
                let (pageData, pageResponse) = try await session.data(for: pageRequest)
                try checkResponse(pageResponse, data: pageData)
                let pageJson = try JSONSerialization.jsonObject(with: pageData) as? [String: Any]
                allItems.append(contentsOf: pageJson?["items"] as? [[String: Any]] ?? [])
            }
            return allItems
        }
        return items
    }

    func create(collection: String, body: [String: Any]) async throws -> [String: Any] {
        let url = apiURL("collections/\(collection)/records")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuth(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    func update(collection: String, id: String, body: [String: Any]) async throws -> [String: Any] {
        let url = apiURL("collections/\(collection)/records/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuth(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    /// Create a record with file attachments (multipart/form-data).
    func createWithFiles(
        collection: String,
        body: [String: String],
        files: [(fieldName: String, filePath: String, fileName: String)]
    ) async throws -> [String: Any] {
        let url = apiURL("collections/\(collection)/records")
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        addAuth(&request)

        var formData = Data()
        // Text fields
        for (key, value) in body {
            formData.append("--\(boundary)\r\n".data(using: .utf8)!)
            formData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            formData.append("\(value)\r\n".data(using: .utf8)!)
        }
        // File fields
        for file in files {
            let fileURL = URL(fileURLWithPath: file.filePath)
            guard let fileData = try? Data(contentsOf: fileURL) else { continue }
            formData.append("--\(boundary)\r\n".data(using: .utf8)!)
            formData.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n".data(using: .utf8)!)
            formData.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            formData.append(fileData)
            formData.append("\r\n".data(using: .utf8)!)
        }
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = formData

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    /// Get download URL for a file attached to a record.
    func fileURL(record: [String: Any], filename: String) -> URL? {
        guard let recordId = record["id"] as? String,
              let collectionId = record["collectionId"] as? String else { return nil }
        return URL(string: "\(serverURL)/api/files/\(collectionId)/\(recordId)/\(filename)")
    }

    /// Download a file from the server.
    func downloadFile(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        addAuth(&request)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return data
    }

    // MARK: - Helpers

    private func apiURL(_ path: String) -> URL {
        URL(string: "\(serverURL)/api/\(path)")!
    }

    private func addAuth(_ request: inout URLRequest) {
        if let token = authToken {
            request.addValue(token, forHTTPHeaderField: "Authorization")
        }
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PBError.serverError(statusCode: httpResponse.statusCode, message: body)
        }
    }

    // MARK: - Keychain

    private let keychainService = "com.moku.reader.sync"
    private let keychainTokenKey = "authToken"
    private let keychainUserIdKey = "userId"

    private func saveAuthToKeychain() {
        if let token = authToken {
            setKeychainItem(key: keychainTokenKey, value: token)
        }
        if let id = userId {
            setKeychainItem(key: keychainUserIdKey, value: id)
        }
    }

    private func loadAuthFromKeychain() {
        authToken = getKeychainItem(key: keychainTokenKey)
        userId = getKeychainItem(key: keychainUserIdKey)
    }

    private func removeAuthFromKeychain() {
        deleteKeychainItem(key: keychainTokenKey)
        deleteKeychainItem(key: keychainUserIdKey)
    }

    private func setKeychainItem(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func getKeychainItem(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychainItem(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum PBError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid server response"
        case .serverError(let code, let message): "Server error (\(code)): \(message)"
        }
    }
}
