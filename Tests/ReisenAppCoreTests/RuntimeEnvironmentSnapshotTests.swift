import Darwin
import Testing
@testable import ReisenAppCore

@Test func runtimeEnvironmentSnapshot_liveAlwaysHasPhysicalMemoryAndArchitecture() {
    let snap = RuntimeEnvironmentSnapshot.live()
    #expect(snap.physicalMemoryBytes > 0)
    #expect(snap.architecture == "arm64" || snap.architecture == "x86_64")
    #expect(
        snap.thermalState == "nominal"
            || snap.thermalState == "fair"
            || snap.thermalState == "serious"
            || snap.thermalState == "critical"
            || snap.thermalState == "nicht verfügbar"
    )
}

@Test func runtimeEnvironmentSnapshot_kernFailureYieldsNilFootprint() {
    #expect(RuntimeEnvironmentSnapshot.footprintBytes(kernReturn: KERN_FAILURE, physFootprint: 99) == nil)
    #expect(RuntimeEnvironmentSnapshot.footprintBytes(kernReturn: KERN_SUCCESS, physFootprint: 99) == 99)
}

@Test func runtimeEnvironmentSnapshot_missingVolumeCapacityIsNil() {
    #expect(RuntimeEnvironmentSnapshot.volumeBytes(importantUsage: nil) == nil)
    #expect(RuntimeEnvironmentSnapshot.volumeBytes(importantUsage: 5) == 5)
}
