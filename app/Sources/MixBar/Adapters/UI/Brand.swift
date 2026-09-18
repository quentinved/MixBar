import SwiftUI

/// The app's own palette, matching the icon exactly so the product reads as one
/// thing rather than a system slider in a window.
enum Brand {
    static let start = Color(red: 0.42, green: 0.36, blue: 0.95)
    static let end = Color(red: 0.62, green: 0.24, blue: 0.89)

    static let fill = LinearGradient(
        colors: [start, end], startPoint: .leading, endPoint: .trailing)

    static let verticalFill = LinearGradient(
        colors: [end, start], startPoint: .bottom, endPoint: .top)
}
