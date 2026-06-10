import Foundation

/// Reads health signal directly from a repo's `.git` directory by shelling out to
/// `/usr/bin/git`. No auth, no API, no network — just filesystem + Process.
///
/// **Sandbox note:** Process is blocked under macOS sandbox. The app currently
/// ships unsandboxed (personal use). When sandboxing is restored for MAS, this
/// feature needs a different transport (read packed-refs / HEAD / logs/HEAD
/// directly instead of invoking git binary).
struct RepoHealthReport: Equatable {
    let path: String
    let lastCommitDate: Date?
    let lastCommitMessage: String?
    let lastCommitAuthor: String?
    let branchCount: Int
    let uncommittedFiles: Int
    let ahead: Int
    let behind: Int
    let error: String?

    var hasUpstream: Bool { ahead >= 0 && behind >= 0 }

    /// Days since the last commit on the current branch, or nil if no commit was found.
    var daysSinceLastCommit: Int? {
        guard let date = lastCommitDate else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }
}

enum GitInspector {
    static func inspect(repoPath: String) async -> RepoHealthReport? {
        let expanded = (repoPath as NSString).expandingTildeInPath
        let gitDir = expanded + "/.git"
        guard FileManager.default.fileExists(atPath: gitDir) else {
            return RepoHealthReport(
                path: expanded,
                lastCommitDate: nil,
                lastCommitMessage: nil,
                lastCommitAuthor: nil,
                branchCount: 0,
                uncommittedFiles: 0,
                ahead: -1,
                behind: -1,
                error: "No .git found at this path"
            )
        }

        async let lastCommitTask = runGit(in: expanded, args: ["log", "-1", "--format=%cI%x09%an%x09%s"])
        async let branchTask = runGit(in: expanded, args: ["for-each-ref", "--format=%(refname:short)", "refs/heads/"])
        async let statusTask = runGit(in: expanded, args: ["status", "--porcelain"])
        async let upstreamTask = runGit(in: expanded, args: ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"])

        let lastCommit = await lastCommitTask
        let branches = await branchTask
        let status = await statusTask
        let upstream = await upstreamTask

        let (date, author, message) = parseLastCommit(lastCommit)
        let branchCount = branches?.split(separator: "\n").count ?? 0
        let uncommitted = status?.split(separator: "\n").count ?? 0
        let (ahead, behind) = parseAheadBehind(upstream)

        return RepoHealthReport(
            path: expanded,
            lastCommitDate: date,
            lastCommitMessage: message,
            lastCommitAuthor: author,
            branchCount: branchCount,
            uncommittedFiles: uncommitted,
            ahead: ahead,
            behind: behind,
            error: nil
        )
    }

    private static func parseLastCommit(_ output: String?) -> (Date?, String?, String?) {
        guard let line = output?.split(separator: "\n").first else { return (nil, nil, nil) }
        let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { return (nil, nil, nil) }
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: parts[0])
        return (date, parts[1], parts[2])
    }

    private static func parseAheadBehind(_ output: String?) -> (Int, Int) {
        guard let line = output?.trimmingCharacters(in: .whitespacesAndNewlines) else { return (-1, -1) }
        let parts = line.split(separator: "\t").map(String.init)
        guard parts.count == 2,
              let ahead = Int(parts[0]),
              let behind = Int(parts[1]) else {
            return (-1, -1)
        }
        return (ahead, behind)
    }

    private static func runGit(in path: String, args: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                task.arguments = args
                task.currentDirectoryURL = URL(fileURLWithPath: path)
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = Pipe()
                do {
                    try task.run()
                    task.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let str = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: str)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
