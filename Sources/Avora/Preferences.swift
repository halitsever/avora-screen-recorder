import Foundation

/// User choices that outlive a launch.
final class Preferences: ObservableObject {
    static let backgroundKey = "background"
    static let shared = Preferences(defaults: .standard)

    @Published var backgroundID: String {
        didSet { defaults.set(backgroundID, forKey: Self.backgroundKey) }
    }

    var background: BackgroundPreset { .named(backgroundID) }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        backgroundID = BackgroundPreset.named(defaults.string(forKey: Self.backgroundKey)).id
    }
}
