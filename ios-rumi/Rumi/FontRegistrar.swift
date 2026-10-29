import CoreText
import Foundation

/// Registers the bundled fonts (Inter Regular/Medium, Fraunces SemiBold,
/// Font Awesome 7 Pro Light for icons)
/// with the process so `Font.custom("Inter-Regular", ...)` etc. resolve.
/// This is the runtime equivalent of listing them under `UIAppFonts` in Info.plist.
enum FontRegistrar {
    static let fontFiles = ["Inter-Regular", "Inter-Medium", "Fraunces-SemiBold", "FontAwesome7Pro-Light"]

    static func registerAll() {
        for name in fontFiles {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Missing bundled font: \(name).ttf")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
