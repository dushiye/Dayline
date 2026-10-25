import Foundation

@main
struct PlanningTests {
    static func main() {
        var failures = 0
        for (name, run) in PlanningChecks.all {
            do { try run(); print("PASS \(name)") }
            catch { failures += 1; print("FAIL \(name): \(error)") }
        }
        print("\(PlanningChecks.all.count - failures)/\(PlanningChecks.all.count) planning checks passed")
        if failures > 0 { exit(1) }
    }
}
