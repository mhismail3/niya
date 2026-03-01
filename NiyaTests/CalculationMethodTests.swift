import Foundation
import Testing
@testable import Niya

@Suite("CalculationMethod")
struct CalculationMethodTests {

    @Test func allHaveDisplayName() {
        for method in CalculationMethod.allCases {
            #expect(!method.displayName.isEmpty, "Missing displayName for \(method.rawValue)")
        }
    }

    @Test func allHavePositiveFajrAngle() {
        for method in CalculationMethod.allCases {
            #expect(method.fajrAngle > 0, "fajrAngle <= 0 for \(method.rawValue)")
        }
    }

    @Test func allHaveIshaAngleOrMinutes() {
        for method in CalculationMethod.allCases {
            let hasAngle = method.ishaAngle != nil
            let hasMinutes = method.ishaMinutesAfterMaghrib != nil
            #expect(hasAngle || hasMinutes, "\(method.rawValue) has neither ishaAngle nor ishaMinutesAfterMaghrib")
        }
    }

    @Test func ishaAngleAndMinutesMutuallyExclusive() {
        for method in CalculationMethod.allCases {
            let hasAngle = method.ishaAngle != nil
            let hasMinutes = method.ishaMinutesAfterMaghrib != nil
            #expect(!(hasAngle && hasMinutes), "\(method.rawValue) has both ishaAngle and ishaMinutesAfterMaghrib")
        }
    }

    @Test func codableRoundTrip() throws {
        for method in CalculationMethod.allCases {
            let data = try JSONEncoder().encode(method)
            let decoded = try JSONDecoder().decode(CalculationMethod.self, from: data)
            #expect(decoded == method)
        }
    }

    @Test func isnaDefaults() {
        let isna = CalculationMethod.isna
        #expect(isna.fajrAngle == 15.0)
        #expect(isna.ishaAngle == 15.0)
        #expect(isna.ishaMinutesAfterMaghrib == nil)
    }

    @Test func makkahUsesMinutes() {
        let makkah = CalculationMethod.makkah
        #expect(makkah.ishaAngle == nil)
        #expect(makkah.ishaMinutesAfterMaghrib == 90)
    }
}
