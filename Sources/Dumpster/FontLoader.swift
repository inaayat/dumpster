import AppKit

enum FontLoader {
    static func registerFonts() {
        let fontNames = ["SpaceGrotesk-Regular", "SpaceGrotesk-Medium", "SpaceGrotesk-Bold", "SpaceGrotesk-Light"]
        for name in fontNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
