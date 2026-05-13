import AppKit
import Combine
import Foundation

struct ReleaseVersion: Comparable {
    let components: [Int]

    init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstDigit = trimmed.firstIndex(where: \.isNumber) else { return nil }

        let numericPrefix = trimmed[firstDigit...].prefix { $0.isNumber || $0 == "." }
        let parsedComponents = numericPrefix
            .split(separator: ".")
            .compactMap { Int($0) }

        guard !parsedComponents.isEmpty else { return nil }
        components = parsedComponents
    }

    private init(components: [Int]) {
        self.components = components
    }

    var displayString: String {
        components.map(String.init).joined(separator: ".")
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)

        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0

            if left != right {
                return left < right
            }
        }

        return false
    }

    static func appVersion(shortVersion: String, buildVersion: String?) -> ReleaseVersion? {
        guard let baseVersion = ReleaseVersion(string: shortVersion) else { return nil }

        // GitHub releases use v<marketing>.<build>, while the bundle exposes these separately.
        if baseVersion.components.count == 2,
           let buildVersion,
           let buildNumber = Int(buildVersion) {
            return ReleaseVersion(components: baseVersion.components + [buildNumber])
        }

        return baseVersion
    }
}

struct AppReleaseVersion {
    let version: ReleaseVersion

    init?(shortVersion: String, buildVersion: String?) {
        guard let version = ReleaseVersion.appVersion(shortVersion: shortVersion, buildVersion: buildVersion) else {
            return nil
        }

        self.version = version
    }

    init?(bundle: Bundle) {
        guard let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }

        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        self.init(shortVersion: shortVersion, buildVersion: buildVersion)
    }

    var displayString: String {
        version.displayString
    }
}

enum ReleaseCheckOutcome: Equatable {
    case updateAvailable(currentVersion: String, latestVersion: String, releasePage: URL)
    case upToDate(currentVersion: String)
}

enum ReleaseCheckError: Equatable, LocalizedError {
    case invalidCurrentVersion
    case invalidResponse
    case invalidReleaseVersion(String)
    case httpStatus(Int)
    case noPublishedRelease

    var errorDescription: String? {
        switch self {
        case .invalidCurrentVersion:
            return "This build does not expose a valid app version."
        case .invalidResponse:
            return "GitHub returned an unexpected response."
        case .invalidReleaseVersion(let tag):
            return "The latest release tag \"\(tag)\" is not a version SF Image Maker can compare."
        case .httpStatus(let statusCode):
            return "GitHub returned HTTP \(statusCode) while checking for updates."
        case .noPublishedRelease:
            return "No GitHub release is published yet."
        }
    }
}

protocol ReleaseFetching {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ReleaseFetching {}

struct GitHubReleaseChecker {
    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private let currentVersion: AppReleaseVersion
    private let fetcher: ReleaseFetching
    private let releasesURL: URL

    init(
        currentVersion: AppReleaseVersion,
        fetcher: ReleaseFetching = URLSession.shared,
        releasesURL: URL = URL(string: "https://api.github.com/repos/ciretose-code/SFMaker/releases/latest")!
    ) {
        self.currentVersion = currentVersion
        self.fetcher = fetcher
        self.releasesURL = releasesURL
    }

    init?(bundle: Bundle = .main, fetcher: ReleaseFetching = URLSession.shared) {
        guard let currentVersion = AppReleaseVersion(bundle: bundle) else { return nil }
        self.init(currentVersion: currentVersion, fetcher: fetcher)
    }

    func checkForUpdates() async throws -> ReleaseCheckOutcome {
        var request = URLRequest(url: releasesURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SFMaker/\(currentVersion.displayString)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await fetcher.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReleaseCheckError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw ReleaseCheckError.noPublishedRelease
            }

            throw ReleaseCheckError.httpStatus(httpResponse.statusCode)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let latestVersion = ReleaseVersion(string: release.tagName) else {
            throw ReleaseCheckError.invalidReleaseVersion(release.tagName)
        }

        if latestVersion > currentVersion.version {
            return .updateAvailable(
                currentVersion: currentVersion.displayString,
                latestVersion: latestVersion.displayString,
                releasePage: release.htmlURL
            )
        }

        return .upToDate(currentVersion: currentVersion.displayString)
    }
}

@MainActor
final class ReleaseCheckManager: ObservableObject {
    @Published private(set) var isChecking = false

    private let makeChecker: () -> GitHubReleaseChecker?
    private let openURL: (URL) -> Void

    init(
        makeChecker: @escaping () -> GitHubReleaseChecker? = { GitHubReleaseChecker() },
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.makeChecker = makeChecker
        self.openURL = openURL
    }

    func checkForUpdates() {
        guard !isChecking else { return }
        guard let checker = makeChecker() else {
            presentError(ReleaseCheckError.invalidCurrentVersion)
            return
        }

        isChecking = true

        Task {
            defer { isChecking = false }

            do {
                let outcome = try await checker.checkForUpdates()
                present(outcome)
            } catch {
                presentError(error)
            }
        }
    }

    private func present(_ outcome: ReleaseCheckOutcome) {
        let alert = NSAlert()
        alert.alertStyle = .informational

        switch outcome {
        case .updateAvailable(let currentVersion, let latestVersion, let releasePage):
            alert.messageText = "SF Image Maker \(latestVersion) is available"
            alert.informativeText = "You're currently running \(currentVersion). Open the GitHub release page to download the latest version?"
            alert.addButton(withTitle: "Open Release Page")
            alert.addButton(withTitle: "Not Now")

            if run(alert) == .alertFirstButtonReturn {
                openURL(releasePage)
            }

        case .upToDate(let currentVersion):
            alert.messageText = "You're up to date"
            alert.informativeText = "SF Image Maker \(currentVersion) is the latest release on GitHub."
            alert.addButton(withTitle: "OK")
            _ = run(alert)
        }
    }

    private func presentError(_ error: Error) {
        let nsError = error as NSError
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Unable to Check for Updates"
        alert.informativeText = nsError.localizedDescription
        alert.addButton(withTitle: "OK")
        _ = run(alert)
    }

    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApplication.shared.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
}
