//
//  OpenAIModelsService.swift
//  llh
//

import Foundation

/// Lists available OpenAI models (`GET /v1/models`) for settings UI and API key validation.
struct OpenAIModelsService: Sendable {
    private let httpClient: OpenAIHTTPClient

    init(httpClient: OpenAIHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchModels(apiKey: String) async throws -> [OpenAIModel] {
        let data = try await httpClient.get(path: "/models", apiKey: apiKey)
        let decoded = try httpClient.decode(data, as: OpenAIModelsResponse.self)
        let models = decoded.data
            .map { OpenAIModel(id: $0.id) }
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }

        guard !models.isEmpty else {
            throw OpenAIServiceError.noModelsFound
        }
        return models
    }
}

private struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModelPayload]
}

private struct OpenAIModelPayload: Decodable {
    let id: String
}
