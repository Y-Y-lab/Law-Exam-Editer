import Foundation

enum FileIOError: Error, LocalizedError {
    case unableToCreateDirectory(URL)
    case unableToWrite(URL)
    case unableToRead(URL)
    case invalidJSON(URL)

    var errorDescription: String? {
        switch self {
        case .unableToCreateDirectory(let url):
            return "Failed to create directory: \(url.path)"
        case .unableToWrite(let url):
            return "Failed to write file: \(url.path)"
        case .unableToRead(let url):
            return "Failed to read file: \(url.path)"
        case .invalidJSON(let url):
            return "Invalid JSON in: \(url.path)"
        }
    }
}

enum FileIO {
    static func ensureDirectory(_ url: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw FileIOError.unableToCreateDirectory(url)
            }
        }
    }

    static func atomicWrite(data: Data, to url: URL) throws {
        let tempURL = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tempURL, to: url)
        } catch {
            throw FileIOError.unableToWrite(url)
        }
    }

    static func atomicWrite(text: String, to url: URL) throws {
        guard let data = text.data(using: .utf8) else {
            throw FileIOError.unableToWrite(url)
        }
        try atomicWrite(data: data, to: url)
    }

    static func readText(from url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw FileIOError.unableToRead(url)
        }
    }

    static func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch is DecodingError {
            throw FileIOError.invalidJSON(url)
        } catch {
            throw FileIOError.unableToRead(url)
        }
    }

    static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try atomicWrite(data: data, to: url)
    }
}
