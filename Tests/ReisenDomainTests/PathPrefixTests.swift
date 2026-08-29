import Foundation
import Testing
import ReisenDomain

@Test func pathPrefix_acceptsExactAndChildPaths() {
    #expect(PathPrefix.isUnder("/var/T", root: "/var/T"))
    #expect(PathPrefix.isUnder("/var/T/copy.pdf", root: "/var/T"))
}

@Test func pathPrefix_rejectsSiblingPrefixPaths() {
    #expect(!PathPrefix.isUnder("/var/T2/copy.pdf", root: "/var/T"))
    #expect(!PathPrefix.isUnder("/var/Other/copy.pdf", root: "/var/T"))
}

@Test func pathPrefix_rootSlashMatchesAbsoluteDescendants() {
    #expect(PathPrefix.isUnder("/", root: "/"))
    #expect(PathPrefix.isUnder("/tmp/file", root: "/"))
    #expect(!PathPrefix.isUnder("relative", root: "/"))
}
