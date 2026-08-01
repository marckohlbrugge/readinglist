import Foundation

/// Watches Safari's `Bookmarks.plist` for external changes so the app can
/// refresh automatically. Safari (and this app) replaces the file atomically,
/// which swaps the underlying inode, so the monitor re-arms itself after
/// every event batch.
@MainActor
final class BookmarksFileMonitor {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var source: (any DispatchSourceFileSystemObject)?
    private var debounceTask: Task<Void, Never>?

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        armSource()
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        source?.cancel()
        source = nil
    }

    private func armSource() {
        source?.cancel()
        source = nil

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            return
        }

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        newSource.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.scheduleChangeNotification()
            }
        }
        newSource.setCancelHandler {
            close(descriptor)
        }
        newSource.resume()
        source = newSource
    }

    private func scheduleChangeNotification() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else {
                return
            }
            armSource()
            onChange()
        }
    }

    deinit {
        debounceTask?.cancel()
        source?.cancel()
    }
}
