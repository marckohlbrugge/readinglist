#if SparkleUpdates
    import Foundation
    import Observation
    import Sparkle

    /// Keeps the app up to date with Sparkle. Each GitHub release publishes a
    /// signed `appcast.xml`; Sparkle checks it daily, then downloads, verifies,
    /// and installs new versions (by default silently, on the next quit).
    @MainActor
    @Observable
    final class AppUpdater {
        private(set) var canCheckForUpdates = false

        var automaticallyChecksForUpdates: Bool {
            didSet { updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
        }

        var automaticallyDownloadsUpdates: Bool {
            didSet { updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates }
        }

        @ObservationIgnored private let controller: SPUStandardUpdaterController
        @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

        private var updater: SPUUpdater { controller.updater }

        init() {
            controller = SPUStandardUpdaterController(
                startingUpdater: false,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
            automaticallyDownloadsUpdates = controller.updater.automaticallyDownloadsUpdates
            canCheckObservation = controller.updater.observe(
                \.canCheckForUpdates,
                options: [.initial, .new]
            ) { [weak self] updater, _ in
                MainActor.assumeIsolated {
                    self?.canCheckForUpdates = updater.canCheckForUpdates
                }
            }
        }

        /// Starts scheduled update checks. Does nothing in development builds,
        /// which have no bundle version or feed to check against.
        func start() {
            guard Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") != nil else {
                return
            }
            controller.startUpdater()
        }

        func checkForUpdates() {
            updater.checkForUpdates()
        }
    }
#endif
