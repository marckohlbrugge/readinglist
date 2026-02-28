import Foundation
import Nuke
import NukeUI
import SwiftUI

enum FaviconPipelineConfiguration {
    static func configureSharedPipeline() {
        _ = didConfigure
    }

    private static let didConfigure: Void = {
        var configuration = ImagePipeline.Configuration.withDataCache(
            name: "ReadLaterFaviconDataCache",
            sizeLimit: 100 * 1024 * 1024
        )
        configuration.imageCache = ImageCache.shared
        configuration.dataCachePolicy = .storeOriginalData

        ImagePipeline.shared = ImagePipeline(configuration: configuration)
    }()
}

struct FaviconImage: View {
    let hostname: String
    let size: CGFloat
    private static let requestedPixelSize = 128

    var body: some View {
        Group {
            if let request = currentRequest {
                LazyImage(request: request) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        placeholder
                    }
                }
                .pipeline(.shared)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var placeholder: some View {
        Image(systemName: "globe")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary)
            .padding(size * 0.2)
    }

    private var currentRequest: ImageRequest? {
        guard let url = faviconURL(for: hostname) else {
            return nil
        }
        return ImageRequest(url: url)
    }

    private func faviconURL(for hostname: String) -> URL? {
        let host = hostname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty, host != "(no host)" else {
            return nil
        }

        if var components = URLComponents(string: "https://www.google.com/s2/favicons") {
            components.queryItems = [
                URLQueryItem(name: "domain", value: host),
                URLQueryItem(name: "sz", value: "\(Self.requestedPixelSize)"),
            ]
            if let url = components.url {
                return url
            }
        }

        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }
}
