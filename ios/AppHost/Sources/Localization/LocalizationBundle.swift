import Foundation

enum LocalizationBundle {
    static var base: Bundle {
#if SWIFT_PACKAGE
        Bundle.module
#else
        Bundle.main
#endif
    }
}
