# PortlessBar

A lightweight macOS menu bar app for monitoring [Portless](https://github.com/corasan/portless) routes.

## Features

- Lives in the menu bar — no dock icon, no windows
- Shows active route count alongside a network icon
- Displays proxy status (running/stopped)
- Routes grouped by project (detected from process working directory)
- Click a route to open it in your browser
- Right-click to copy URLs or hostnames
- Auto-refreshes when `~/.portless/routes.json` changes (via kqueue file watching)

## How it works

PortlessBar reads from the `~/.portless/` state directory:

| File | Purpose |
|------|---------|
| `routes.json` | Active routes (hostname, port, pid) |
| `proxy.pid` | Proxy process ID |
| `proxy.port` | Proxy listening port |
| `proxy.tls` | Whether TLS is enabled (`1` or `0`) |

## Requirements

- macOS 13+
- Xcode 15+
- [Portless](https://github.com/corasan/portless) running locally

## Building

Open `portlessbar.xcodeproj` in Xcode and build (Cmd+B). The app runs as a menu bar agent with `LSUIElement` enabled.
