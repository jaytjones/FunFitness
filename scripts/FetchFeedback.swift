// FetchFeedback.swift
// Pulls new TestFlight feedback (screenshot + crash submissions) from the App Store Connect API
// and writes a Markdown report to docs/feedback/YYYYMMDD_feedback.md.
//
// Run via `scripts/feedback` from anywhere in the repo. See scripts/README.md for setup.

import Foundation
import CryptoKit

// MARK: - Errors

struct FeedbackError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// MARK: - Config

/// Lives outside the repo (default ~/.appstoreconnect/funfitness.json) so credentials are never committed.
struct Config: Decodable {
    let keyID: String
    let issuerID: String
    let appID: String
    let keyPath: String

    static func load() throws -> Config {
        let path = ProcessInfo.processInfo.environment["ASC_CONFIG"]
            ?? "\(NSHomeDirectory())/.appstoreconnect/funfitness.json"
        guard let data = FileManager.default.contents(atPath: path) else {
            throw FeedbackError("Config not found at \(path). See scripts/README.md for setup.")
        }
        do {
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            throw FeedbackError("Config at \(path) is invalid: \(error)")
        }
    }
}

// MARK: - API client

struct AppStoreConnect {
    let config: Config
    let privateKey: P256.Signing.PrivateKey
    static let baseURL = "https://api.appstoreconnect.apple.com"

    init(config: Config) throws {
        self.config = config
        let keyPath = (config.keyPath as NSString).expandingTildeInPath
        guard let pem = try? String(contentsOfFile: keyPath, encoding: .utf8) else {
            throw FeedbackError("Could not read private key at \(keyPath).")
        }
        do {
            privateKey = try P256.Signing.PrivateKey(pemRepresentation: pem)
        } catch {
            throw FeedbackError("Private key at \(keyPath) is not a valid .p8 key: \(error)")
        }
    }

    /// Short-lived ES256 JWT. Cheap to sign, so we make a fresh one per request.
    func makeToken() throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": config.keyID, "typ": "JWT"])
        let payload = try JSONSerialization.data(withJSONObject: [
            "iss": config.issuerID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1",
        ])
        let signingInput = base64URL(header) + "." + base64URL(payload)
        // rawRepresentation is the 64-byte r||s form that JWS expects.
        let signature = try privateKey.signature(for: Data(signingInput.utf8)).rawRepresentation
        return signingInput + "." + base64URL(signature)
    }

    /// GET a path ("/v1/...") or an absolute `links.next` URL and return the decoded JSON object.
    func get(_ pathOrURL: String) async throws -> [String: Any] {
        let urlString = pathOrURL.hasPrefix("http") ? pathOrURL : Self.baseURL + pathOrURL
        guard let url = URL(string: urlString) else { throw FeedbackError("Bad URL: \(urlString)") }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try makeToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            let detail = (json["errors"] as? [[String: Any]])?.first.map {
                "\($0["title"] ?? ""): \($0["detail"] ?? "")"
            } ?? String(decoding: data.prefix(500), as: UTF8.self)
            throw FeedbackError("HTTP \(status) for \(url.path): \(detail)")
        }
        return json
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Model

enum Kind: String {
    case screenshot = "betaFeedbackScreenshotSubmissions"
    case crash = "betaFeedbackCrashSubmissions"

    var icon: String { self == .screenshot ? "🖼" : "💥" }
}

struct Submission {
    let id: String
    let kind: Kind
    let attributes: [String: Any]
    let buildID: String?
    let testerID: String?
    let created: Date

    func string(_ key: String) -> String? {
        guard let value = attributes[key], !(value is NSNull) else { return nil }
        let text = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

/// Tracks which submissions have already been written, and the FB-#### number each one was given.
/// Stored in docs/feedback/.state.json so numbering stays stable across runs.
struct State: Codable {
    var nextNumber = 1
    var ids: [String: String] = [:]
}

// MARK: - Helpers

func parseDate(_ text: String?) -> Date {
    guard let text else { return .distantPast }
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text) ?? .distantPast
}

func formatted(_ date: Date, _ format: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = format
    return formatter.string(from: date)
}

func relationshipID(_ resource: [String: Any], _ name: String) -> String? {
    let relationships = resource["relationships"] as? [String: Any]
    let relationship = relationships?[name] as? [String: Any]
    return (relationship?["data"] as? [String: Any])?["id"] as? String
}

// MARK: - Fetching

/// Fetches every submission of one kind (following pagination) and returns those not yet seen,
/// plus any `included` build/tester resources keyed by "type/id".
func fetchUnseen(_ kind: Kind, api: AppStoreConnect, state: State)
    async throws -> (submissions: [Submission], included: [String: [String: Any]])
{
    var submissions: [Submission] = []
    var included: [String: [String: Any]] = [:]
    var next: String? = "/v1/apps/\(api.config.appID)/\(kind.rawValue)?include=build,tester&limit=200"

    while let url = next {
        let page = try await api.get(url)
        for resource in page["included"] as? [[String: Any]] ?? [] {
            if let type = resource["type"] as? String, let id = resource["id"] as? String {
                included["\(type)/\(id)"] = resource
            }
        }
        for resource in page["data"] as? [[String: Any]] ?? [] {
            guard let id = resource["id"] as? String, state.ids[id] == nil else { continue }
            let attributes = resource["attributes"] as? [String: Any] ?? [:]
            submissions.append(Submission(
                id: id,
                kind: kind,
                attributes: attributes,
                buildID: relationshipID(resource, "build"),
                testerID: relationshipID(resource, "tester"),
                created: parseDate(attributes["createdDate"] as? String)
            ))
        }
        next = (page["links"] as? [String: Any])?["next"] as? String
    }
    return (submissions, included)
}

/// "3.1 (9)" when the marketing version can be looked up, otherwise "(9)".
func buildLabel(buildID: String?, included: [String: [String: Any]], api: AppStoreConnect) async -> String {
    guard let buildID else { return "Unknown build" }
    var number = buildID
    if let build = included["builds/\(buildID)"],
       let version = (build["attributes"] as? [String: Any])?["version"] as? String {
        number = version
    }
    if let pre = try? await api.get("/v1/builds/\(buildID)/preReleaseVersion"),
       let marketing = ((pre["data"] as? [String: Any])?["attributes"] as? [String: Any])?["version"] as? String {
        return "\(marketing) (\(number))"
    }
    return "(\(number))"
}

func testerLabel(_ submission: Submission, included: [String: [String: Any]]) -> String? {
    var name: String?
    var email = submission.string("email")
    if let id = submission.testerID,
       let attributes = included["betaTesters/\(id)"]?["attributes"] as? [String: Any] {
        let parts = [attributes["firstName"], attributes["lastName"]].compactMap { $0 as? String }
        name = parts.isEmpty ? nil : parts.joined(separator: " ")
        email = email ?? attributes["email"] as? String
    }
    switch (name, email) {
    case let (name?, email?): return "\(name) <\(email)>"
    case let (name?, nil): return name
    case let (nil, email?): return email
    default: return nil
    }
}

/// Downloads screenshots (signed URLs that expire) and crash logs into docs/feedback/assets.
/// Returns Markdown lines that link to the saved files.
func saveAssets(for submission: Submission, number: String, api: AppStoreConnect, assetsDir: URL) async -> [String] {
    var lines: [String] = []
    switch submission.kind {
    case .screenshot:
        let screenshots = submission.attributes["screenshots"] as? [[String: Any]] ?? []
        for (index, screenshot) in screenshots.enumerated() {
            guard var urlString = screenshot["url"] as? String else { continue }
            // Image URLs may be templates with {w}/{h}/{f} placeholders.
            urlString = urlString
                .replacingOccurrences(of: "{w}", with: "\(screenshot["width"] ?? 1000)")
                .replacingOccurrences(of: "{h}", with: "\(screenshot["height"] ?? 2000)")
                .replacingOccurrences(of: "{f}", with: "png")
            let base = "\(number)-\(index + 1)"
            guard let url = URL(string: urlString),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200 else {
                lines.append("_Screenshot \(index + 1) could not be downloaded._")
                continue
            }
            let ext = response.mimeType == "image/jpeg" ? "jpg" : "png"
            let file = assetsDir.appendingPathComponent("\(base).\(ext)")
            if (try? data.write(to: file)) != nil {
                lines.append("![\(number) screenshot \(index + 1)](assets/\(base).\(ext))")
            } else {
                lines.append("_Screenshot \(index + 1) could not be saved._")
            }
        }
    case .crash:
        do {
            let log = try await api.get("/v1/betaFeedbackCrashSubmissions/\(submission.id)/crashLog")
            let attributes = (log["data"] as? [String: Any])?["attributes"] as? [String: Any]
            guard let text = attributes?["logText"] as? String else {
                lines.append("_Crash log not available._")
                break
            }
            let file = assetsDir.appendingPathComponent("\(number).crash")
            try text.write(to: file, atomically: true, encoding: .utf8)
            lines.append("Crash log: [\(number).crash](assets/\(number).crash)")
        } catch {
            lines.append("_Crash log could not be fetched: \(error)_")
        }
    }
    return lines
}

// MARK: - Report

func renderEntry(_ submission: Submission, number: String, tester: String?, assetLines: [String]) -> String {
    var header = "### \(submission.kind.icon) \(number) · \(formatted(submission.created, "yyyy-MM-dd HH:mm"))"
    if let device = submission.string("deviceModel") { header += " · \(device)" }
    if let os = submission.string("osVersion") { header += " · iOS \(os)" }

    var lines = [header, ""]
    if let tester { lines.append("**Tester:** \(tester)  ") }

    var details: [String] = []
    if let locale = submission.string("locale") { details.append(locale) }
    if let connection = submission.string("connectionType") { details.append(connection) }
    if let battery = submission.string("batteryPercentage") { details.append("battery \(battery)%") }
    if let uptime = submission.attributes["appUptimeInMilliseconds"] as? Double {
        details.append("app up \(Int(uptime / 60_000)) min")
    }
    if !details.isEmpty { lines.append("**Device:** \(details.joined(separator: " · "))  ") }
    lines.append("")

    let comment = submission.string("comment") ?? "(no comment)"
    lines += comment.components(separatedBy: .newlines).map { "> \($0)" }
    lines.append("")
    if !assetLines.isEmpty { lines += assetLines + [""] }
    lines += ["**Status:** new  ", "**Notes:**", "", ""]
    return lines.joined(separator: "\n")
}

// MARK: - Main

func run() async throws {
    let arguments = Set(CommandLine.arguments.dropFirst())
    if arguments.contains("--help") || arguments.contains("-h") {
        print("""
        Usage: scripts/feedback [--dry-run]

        Fetches new TestFlight feedback and writes docs/feedback/YYYYMMDD_feedback.md.
          --dry-run   Fetch and list new feedback without writing any files.
        """)
        return
    }
    let dryRun = arguments.contains("--dry-run")

    let feedbackDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("docs/feedback")
    let assetsDir = feedbackDir.appendingPathComponent("assets")
    let stateFile = feedbackDir.appendingPathComponent(".state.json")

    var state = (try? JSONDecoder().decode(State.self, from: Data(contentsOf: stateFile))) ?? State()
    let api = try AppStoreConnect(config: Config.load())

    let screenshots = try await fetchUnseen(.screenshot, api: api, state: state)
    let crashes = try await fetchUnseen(.crash, api: api, state: state)
    let included = screenshots.included.merging(crashes.included) { first, _ in first }
    let submissions = (screenshots.submissions + crashes.submissions).sorted { $0.created < $1.created }

    guard !submissions.isEmpty else {
        print("No new feedback.")
        return
    }
    let summary = "\(submissions.count) new (\(screenshots.submissions.count) screenshot, \(crashes.submissions.count) crash)"

    if dryRun {
        print("Dry run: \(summary)")
        for submission in submissions {
            let comment = submission.string("comment").map { String($0.prefix(70)) } ?? "(no comment)"
            print("  \(submission.kind.icon) \(formatted(submission.created, "yyyy-MM-dd HH:mm"))  \(comment)")
        }
        return
    }

    try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

    // Look up a label for each build once, then group entries by build (newest build first).
    var labels: [String: String] = [:]
    for buildID in Set(submissions.map { $0.buildID ?? "" }) {
        labels[buildID] = await buildLabel(buildID: buildID.isEmpty ? nil : buildID, included: included, api: api)
    }
    let groups = Dictionary(grouping: submissions) { $0.buildID ?? "" }
    let orderedBuilds = groups.keys.sorted {
        (groups[$0]?.last?.created ?? .distantPast) > (groups[$1]?.last?.created ?? .distantPast)
    }

    let now = Date()
    var body = "\n## Fetched \(formatted(now, "yyyy-MM-dd HH:mm")) — \(summary)\n\n"
    for buildID in orderedBuilds {
        let entries = groups[buildID] ?? []
        body += "## \(labels[buildID] ?? "Unknown build") — \(entries.count) new\n\n"
        for submission in entries {
            let number = String(format: "FB-%04d", state.nextNumber)
            state.nextNumber += 1
            let assetLines = await saveAssets(for: submission, number: number, api: api, assetsDir: assetsDir)
            body += renderEntry(submission, number: number,
                                tester: testerLabel(submission, included: included),
                                assetLines: assetLines)
            state.ids[submission.id] = number
        }
    }

    // One report per day; later runs on the same day append to it.
    let reportFile = feedbackDir.appendingPathComponent("\(formatted(now, "yyyyMMdd"))_feedback.md")
    if let handle = try? FileHandle(forWritingTo: reportFile) {
        handle.seekToEndOfFile()
        handle.write(Data(body.utf8))
        try handle.close()
    } else {
        let header = """
        # FunFitness — TestFlight Feedback (\(formatted(now, "yyyy-MM-dd")))

        Generated by `scripts/feedback`. Update each **Status** as you triage:
        new · fixed in (N) · won't fix · need info · duplicate of FB-####.

        """
        try (header + body).write(to: reportFile, atomically: true, encoding: .utf8)
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(state).write(to: stateFile)

    print("Fetched \(summary)")
    print("→ docs/feedback/\(reportFile.lastPathComponent)")
}

do {
    try await run()
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
