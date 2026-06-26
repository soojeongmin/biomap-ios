import Foundation
import ImageIO
import UIKit

struct ImageMeta {
    var captureDate: Date?
    var latitude: Double?
    var longitude: Double?
}

func readImageMeta(_ data: Data) -> ImageMeta {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
        return ImageMeta()
    }
    var meta = ImageMeta()
    let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
    let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
    let dateString = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
        ?? (exif?[kCGImagePropertyExifDateTimeDigitized] as? String)
        ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)
    if let s = dateString {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        meta.captureDate = f.date(from: s)
    }
    if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
        if let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           let ref = gps[kCGImagePropertyGPSLatitudeRef] as? String {
            meta.latitude = (ref == "S") ? -lat : lat
        }
        if let lng = gps[kCGImagePropertyGPSLongitude] as? Double,
           let ref = gps[kCGImagePropertyGPSLongitudeRef] as? String {
            meta.longitude = (ref == "W") ? -lng : lng
        }
    }
    return meta
}

func freshnessValue(captureDate: Date?, fromCamera: Bool) -> String {
    if fromCamera { return "fresh" }
    guard let captureDate else { return "none" }
    return Date().timeIntervalSince(captureDate) <= 24 * 3600 ? "fresh" : "old"
}

func compressForUpload(_ image: UIImage, side: CGFloat = 1080) -> Data? {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
    let square = renderer.image { _ in
        let shortest = min(image.size.width, image.size.height)
        let scale = side / shortest
        let w = image.size.width * scale
        let h = image.size.height * scale
        image.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
    }
    return square.jpegData(compressionQuality: 0.8)
}
