import AVFoundation
import FlutterMacOS
import Foundation
import ImageIO

/// Generates bounded image and video previews without decoding source media in
/// Flutter's UI isolate.
final class ThumbnailHandler: NSObject {
    init(accessRegistry: SecurityScopedAccessRegistry) {
        self.accessRegistry = accessRegistry
        super.init()
    }

    private let accessRegistry: SecurityScopedAccessRegistry
    private let imageQueue = DispatchQueue(
        label: "com.joaquinmx.media_fast_view.thumbnail-images",
        qos: .utility,
        attributes: .concurrent
    )
    private let generatorLock = NSLock()
    private var videoGenerators: [String: AVAssetImageGenerator] = [:]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "generateThumbnail":
            generateThumbnail(call, result: result)
        case "cancelThumbnail":
            cancelThumbnail(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func generateThumbnail(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let requestId = arguments["requestId"] as? String,
              let path = arguments["path"] as? String,
              let mediaType = arguments["mediaType"] as? String,
              let requestedMaxPixelSize = arguments["maxPixelSize"] as? Int else {
            result(invalidArgumentsError())
            return
        }

        let maxPixelSize = min(max(requestedMaxPixelSize, 64), 2048)
        let bookmarkData = arguments["bookmarkData"] as? String

        switch mediaType {
        case "image":
            generateImageThumbnail(
                requestId: requestId,
                path: path,
                maxPixelSize: maxPixelSize,
                bookmarkData: bookmarkData,
                result: result
            )
        case "video":
            generateVideoThumbnail(
                requestId: requestId,
                path: path,
                maxPixelSize: maxPixelSize,
                bookmarkData: bookmarkData,
                result: result
            )
        default:
            result(FlutterError(
                code: "UNSUPPORTED_MEDIA_TYPE",
                message: "Only image and video thumbnails are supported",
                details: mediaType
            ))
        }
    }

    private func generateImageThumbnail(
        requestId: String,
        path: String,
        maxPixelSize: Int,
        bookmarkData: String?,
        result: @escaping FlutterResult
    ) {
        imageQueue.async { [weak self] in
            guard let self else { return }

            do {
                let acquiredBookmark = try self.acquire(bookmarkData)
                defer { self.release(acquiredBookmark) }

                guard FileManager.default.fileExists(atPath: path) else {
                    throw ThumbnailGenerationError.fileNotFound(path)
                }

                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    kCGImageSourceShouldCacheImmediately: false,
                ]
                guard let source = CGImageSourceCreateWithURL(
                    URL(fileURLWithPath: path) as CFURL,
                    nil
                ), let image = CGImageSourceCreateThumbnailAtIndex(
                    source,
                    0,
                    options as CFDictionary
                ) else {
                    throw ThumbnailGenerationError.decodeFailed(path)
                }

                let data = try self.encode(
                    image,
                    type: "public.jpeg" as CFString,
                    quality: 0.82
                )
                self.finish(result, payload: self.payload(data, extension: "jpg"))
            } catch {
                self.finish(result, error: error)
            }
        }
    }

    private func generateVideoThumbnail(
        requestId: String,
        path: String,
        maxPixelSize: Int,
        bookmarkData: String?,
        result: @escaping FlutterResult
    ) {
        do {
            let acquiredBookmark = try acquire(bookmarkData)
            guard FileManager.default.fileExists(atPath: path) else {
                release(acquiredBookmark)
                result(flutterError(for: ThumbnailGenerationError.fileNotFound(path)))
                return
            }

            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

            let durationSeconds = CMTimeGetSeconds(asset.duration)
            let requestedSeconds: Double
            if durationSeconds.isFinite && durationSeconds > 0 {
                requestedSeconds = min(max(durationSeconds * 0.1, 0), max(durationSeconds - 0.05, 0))
            } else {
                requestedSeconds = 0
            }
            let requestedTime = CMTime(seconds: requestedSeconds, preferredTimescale: 600)

            setGenerator(generator, for: requestId)
            generator.generateCGImagesAsynchronously(
                forTimes: [NSValue(time: requestedTime)]
            ) { [weak self] _, image, _, generationResult, error in
                guard let self else { return }
                self.removeGenerator(for: requestId)
                defer { self.release(acquiredBookmark) }

                if generationResult == .cancelled {
                    self.finish(result, error: ThumbnailGenerationError.cancelled)
                    return
                }
                if let error {
                    self.finish(result, error: error)
                    return
                }
                guard let image else {
                    self.finish(result, error: ThumbnailGenerationError.decodeFailed(path))
                    return
                }

                do {
                    let data = try self.encode(
                        image,
                        type: "public.jpeg" as CFString,
                        quality: 0.82
                    )
                    self.finish(result, payload: self.payload(data, extension: "jpg"))
                } catch {
                    self.finish(result, error: error)
                }
            }
        } catch {
            result(flutterError(for: error))
        }
    }

    private func cancelThumbnail(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let requestId = arguments["requestId"] as? String else {
            result(invalidArgumentsError())
            return
        }

        generatorLock.lock()
        let generator = videoGenerators[requestId]
        generatorLock.unlock()
        generator?.cancelAllCGImageGeneration()
        result(nil)
    }

    private func acquire(_ bookmarkData: String?) throws -> String? {
        guard let bookmarkData, !bookmarkData.isEmpty else { return nil }
        _ = try accessRegistry.acquire(bookmarkData)
        return bookmarkData
    }

    private func release(_ bookmarkData: String?) {
        guard let bookmarkData else { return }
        accessRegistry.release(bookmarkData)
    }

    private func setGenerator(_ generator: AVAssetImageGenerator, for requestId: String) {
        generatorLock.lock()
        videoGenerators[requestId] = generator
        generatorLock.unlock()
    }

    private func removeGenerator(for requestId: String) {
        generatorLock.lock()
        videoGenerators.removeValue(forKey: requestId)
        generatorLock.unlock()
    }

    private func encode(_ image: CGImage, type: CFString, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            type,
            1,
            nil
        ) else {
            throw ThumbnailGenerationError.encodeFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ThumbnailGenerationError.encodeFailed
        }
        return data as Data
    }

    private func payload(_ data: Data, extension fileExtension: String) -> [String: Any] {
        return [
            "bytes": FlutterStandardTypedData(bytes: data),
            "extension": fileExtension,
        ]
    }

    private func finish(_ result: @escaping FlutterResult, payload: [String: Any]) {
        DispatchQueue.main.async { result(payload) }
    }

    private func finish(_ result: @escaping FlutterResult, error: Error) {
        DispatchQueue.main.async { result(self.flutterError(for: error)) }
    }

    private func invalidArgumentsError() -> FlutterError {
        return FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "requestId, path, mediaType, and maxPixelSize are required",
            details: nil
        )
    }

    private func flutterError(for error: Error) -> FlutterError {
        if case ThumbnailGenerationError.cancelled = error {
            return FlutterError(code: "CANCELLED", message: "Thumbnail generation was cancelled", details: nil)
        }
        return FlutterError(
            code: "THUMBNAIL_GENERATION_FAILED",
            message: error.localizedDescription,
            details: nil
        )
    }
}

private enum ThumbnailGenerationError: LocalizedError {
    case cancelled
    case decodeFailed(String)
    case encodeFailed
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Thumbnail generation was cancelled"
        case .decodeFailed(let path):
            return "Could not decode media at \(path)"
        case .encodeFailed:
            return "Could not encode the generated thumbnail"
        case .fileNotFound(let path):
            return "Media file does not exist at \(path)"
        }
    }
}
