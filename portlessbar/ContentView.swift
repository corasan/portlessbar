import SwiftUI
import AppKit

// MARK: - Menu bar icon

struct MenuBarLabel: View {
    let proxyRunning: Bool
    let routeCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "network")
                .symbolRenderingMode(.hierarchical)
            if routeCount > 0 {
                Text("\(routeCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
        .foregroundStyle(proxyRunning ? .primary : .secondary)
    }
}

// MARK: - Popover content

struct MenuContent: View {
    @ObservedObject var store: PortlessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Portless")
                        .font(.headline)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.proxyRunning ? Color.green : Color.secondary)
                            .frame(width: 7, height: 7)
                        Text(store.proxyRunning ? "Proxy running" : "Proxy stopped")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    store.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Refresh routes")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if store.routes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No active routes")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Run portless run <cmd> in a project")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.groupedRoutes, id: \.project) { group in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(group.project)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                ForEach(group.routes) { route in
                                    RouteRow(route: route)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 320)
            }

            Divider()

            // Footer actions
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Open Terminal") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 300)
    }
}

// MARK: - Route row

struct RouteRow: View {
    let route: PortlessRoute
    @State private var isHovered = false

    var body: some View {
        Button {
            if let url = URL(string: route.url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                // Status dot
                Circle()
                    .fill(route.isAlive ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(route.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(route.url)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(route.url, forType: .string)
            }
            Button("Copy name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(route.displayName, forType: .string)
            }
            Divider()
            Button("Open in browser") {
                if let url = URL(string: route.url) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

