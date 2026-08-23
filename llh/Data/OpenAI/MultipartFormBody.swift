//
//  MultipartFormBody.swift
//  llh
//

import Foundation

struct MultipartFormField: Sendable {
    enum Body: Sendable {
        case text(String)
        case file(data: Data, filename: String, mimeType: String)
    }

    let name: String
    let body: Body
}

struct MultipartFormBody: Sendable {
    let data: Data
    let contentType: String
    let boundary: String

    static func encode(_ fields: [MultipartFormField], boundary: String = "llh-boundary-\(UUID().uuidString)") -> MultipartFormBody {
        var data = Data()
        for field in fields {
            data.appendUTF8("--\(boundary)\r\n")
            switch field.body {
            case .text(let value):
                data.appendUTF8("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
                data.appendUTF8("\(value)\r\n")
            case let .file(fileData, filename, mimeType):
                data.appendUTF8(
                    "Content-Disposition: form-data; name=\"\(field.name)\"; filename=\"\(filename)\"\r\n"
                )
                data.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
                data.append(fileData)
                data.appendUTF8("\r\n")
            }
        }
        data.appendUTF8("--\(boundary)--\r\n")
        return MultipartFormBody(
            data: data,
            contentType: "multipart/form-data; boundary=\(boundary)",
            boundary: boundary
        )
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}
