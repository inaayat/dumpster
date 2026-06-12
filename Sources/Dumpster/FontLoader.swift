import AppKit

enum FontLoader {
    static func registerFonts() {
        let fontNames = ["Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold"]
        for name in fontNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
