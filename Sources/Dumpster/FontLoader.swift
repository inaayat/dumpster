import AppKit

enum FontLoader {
    static func registerFonts() {
        let fontNames = ["Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold"]
        var registered = 0
        for name in fontNames {
            if let url = Bundle.module.url(forResource: name, withExtension: "ttf") {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    registered += 1
                }
            }
        }
        if registered == 0 {
            print("Warning: No Satoshi fonts registered. Falling back to system font.")
        }
    }
}
