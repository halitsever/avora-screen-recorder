import Foundation

public struct SpringConfig: Sendable, Equatable {
    public var mass: Double
    public var stiffness: Double
    public var damping: Double

    public init(mass: Double, stiffness: Double, damping: Double) {
        self.mass = mass
        self.stiffness = stiffness
        self.damping = damping
    }

    public static let screen = SpringConfig(mass: 2.25, stiffness: 250, damping: 40)
    public static let cursor = SpringConfig(mass: 3, stiffness: 470, damping: 70)
}

public struct Spring: Sendable, Equatable {
    public var value: Double
    public var velocity: Double

    public init(value: Double, velocity: Double = 0) {
        self.value = value
        self.velocity = velocity
    }

    static let step = 0.001
    static let restThreshold = 0.01

    /// Semi-implicit Euler in 1 ms steps, so results do not depend on how callers slice time.
    public mutating func advance(toward target: Double, by duration: Double, config: SpringConfig) {
        var remaining = duration
        while remaining > 1e-12 {
            let dt = min(Self.step, remaining)
            remaining -= dt

            let displacement = value - target
            let force = -config.stiffness * displacement - damping(for: displacement, config) * velocity
            velocity += force / config.mass * dt
            value += velocity * dt

            if abs(velocity) < Self.restThreshold, abs(value - target) < Self.restThreshold {
                value = target
                velocity = 0
                return
            }
        }
    }

    /// Switches to critical damping once the spring closes in faster than it could stop in time,
    /// which keeps soft springs from overshooting the target.
    private func damping(for displacement: Double, _ config: SpringConfig) -> Double {
        let closingIn = velocity * displacement < 0
        let naturalFrequency = (config.stiffness / config.mass).squareRoot()
        guard closingIn, abs(velocity) > abs(displacement) * naturalFrequency else { return config.damping }
        return max(config.damping, 2 * (config.mass * config.stiffness).squareRoot())
    }
}
