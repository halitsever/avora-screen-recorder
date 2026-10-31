import Testing
@testable import ZoomEngine

struct SpringTests {
    @Test func settlesOnTarget() {
        var spring = Spring(value: 0)
        spring.advance(toward: 100, by: 3, config: .screen)
        #expect(abs(spring.value - 100) < 0.5)
    }

    @Test func movesGraduallyRatherThanJumping() {
        var spring = Spring(value: 0)
        spring.advance(toward: 100, by: 0.05, config: .screen)
        #expect(spring.value > 0)
        #expect(spring.value < 50)
    }

    @Test func bouncySpringDoesNotOvershoot() {
        let bouncy = SpringConfig(mass: 1.5, stiffness: 125, damping: 12)
        var spring = Spring(value: 0)
        var peak = 0.0
        for _ in 0..<180 {
            spring.advance(toward: 100, by: 1.0 / 60, config: bouncy)
            peak = max(peak, spring.value)
        }
        #expect(peak > 99)
        #expect(peak <= 100.1)
    }

    @Test func restingSpringStaysPut() {
        var spring = Spring(value: 42)
        spring.advance(toward: 42, by: 1, config: .screen)
        #expect(spring.value == 42)
        #expect(spring.velocity == 0)
    }

    @Test func splitStepsMatchOneLongStep() {
        var whole = Spring(value: 0)
        whole.advance(toward: 100, by: 0.5, config: .screen)
        var split = Spring(value: 0)
        for _ in 0..<50 { split.advance(toward: 100, by: 0.01, config: .screen) }
        #expect(whole.value > 10)
        #expect(abs(whole.value - split.value) < 0.01)
    }
}
