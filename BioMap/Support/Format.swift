import Foundation

func formatTimestamp(_ ms: Int64) -> String {
    let date = Date(timeIntervalSince1970: Double(ms) / 1000)
    let f = DateFormatter()
    f.dateFormat = "yyyy.MM.dd HH:mm"
    return f.string(from: date)
}
