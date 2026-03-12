import SwiftUI
import AppKit
import Combine

// MARK: - Models

struct PortlessRoute: Identifiable {
    let id: String      // hostname
    let port: Int
    let pid: Int
    let url: String
    let project: String // derived from process cwd

    var displayName: String { id }
    var isAlive: Bool { kill(Int32(pid), 0) == 0 }
}

// MARK: - Routes store

@MainActor
final class PortlessStore: ObservableObject {
    @Published var routes: [PortlessRoute] = []
    @Published var proxyRunning: Bool = false

    /// Routes grouped by project name, sorted alphabetically.
    var groupedRoutes: [(project: String, routes: [PortlessRoute])] {
        let grouped = Dictionary(grouping: routes, by: \.project)
        return grouped.keys.sorted().map { key in
            (project: key, routes: grouped[key]!)
        }
    }

    private let stateDir: URL
    private let routesFile: URL
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        stateDir = home.appendingPathComponent(".portless")
        routesFile = stateDir.appendingPathComponent("routes.json")
        reload()
        startWatching()
    }

    deinit {
        source?.cancel()
        if fd >= 0 { close(fd) }
    }

    func reload() {
        routes = loadRoutes()
        proxyRunning = checkProxy()
    }

    private func loadRoutes() -> [PortlessRoute] {
        guard let data = try? Data(contentsOf: routesFile),
              let entries = try? JSONDecoder().decode([RouteEntry].self, from: data)
        else { return [] }

        let proxyPort = readProxyPort()
        let useTLS = readProxyTLS()
        let scheme = useTLS ? "https" : "http"

        return entries.map { entry in
            let url = "\(scheme)://\(entry.hostname):\(proxyPort)"
            let project = Self.projectName(forPid: entry.pid)
            return PortlessRoute(id: entry.hostname, port: entry.port, pid: entry.pid, url: url, project: project)
        }.sorted { $0.id < $1.id }
    }

    /// Resolve the working directory of a PID via `lsof -p <pid> -Fn` and extract the project folder name.
    private static func projectName(forPid pid: Int) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return "Unknown" }
        task.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // lsof output lines starting with 'n' contain the path
        guard let line = output.components(separatedBy: "\n").first(where: { $0.hasPrefix("n") }) else {
            return "Unknown"
        }
        let path = String(line.dropFirst()) // drop the 'n' prefix
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func readProxyPort() -> Int {
        let portFile = stateDir.appendingPathComponent("proxy.port")
        guard let str = try? String(contentsOf: portFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let port = Int(str)
        else { return 1355 }
        return port
    }

    private func readProxyTLS() -> Bool {
        let tlsFile = stateDir.appendingPathComponent("proxy.tls")
        guard let str = try? String(contentsOf: tlsFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        else { return false }
        return str == "1"
    }

    private func checkProxy() -> Bool {
        let pidFile = stateDir.appendingPathComponent("proxy.pid")
        guard let pidStr = try? String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(pidStr), pid > 0
        else { return false }
        // Use NSRunningApplication lookup instead of kill() which fails in sandbox
        return NSWorkspace.shared.runningApplications.contains { $0.processIdentifier == pid }
            || processExists(pid: pid)
    }

    /// Fallback: shell out to `ps` to check if a PID is alive (works outside sandbox too)
    private func processExists(pid: Int32) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(pid)"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        return (try? task.run()) != nil && { task.waitUntilExit(); return task.terminationStatus == 0 }()
    }

    private func startWatching() {
        fd = open(stateDir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source?.setEventHandler { [weak self] in
            self?.reload()
        }
        source?.resume()
    }

    private struct RouteEntry: Decodable {
        let hostname: String
        let port: Int
        let pid: Int
    }
}

// MARK: - Menu bar entry point

@main
struct PortlessBarApp: App {
    @StateObject private var store = PortlessStore()
    @State private var isPopoverShown = false

    var body: some Scene {
        MenuBarExtra {
            MenuContent(store: store)
        } label: {
            MenuBarLabel(proxyRunning: store.proxyRunning, routeCount: store.routes.count)
        }
        .menuBarExtraStyle(.window)
    }
}
