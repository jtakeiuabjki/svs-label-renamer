import Testing
@testable import SVSLabelRenamer

@Test func filenameWithOptionalBlock() {
    #expect(FilenameBuilder.make(pathology: "K1234", block: "", stain: "CD163") == "K1234_CD163")
    #expect(FilenameBuilder.make(pathology: "K1234", block: "2", stain: "CD68") == "K1234_2_CD68")
}

@Test func unsafeCharactersAreRemoved() {
    #expect(FilenameBuilder.make(pathology: " K 123 ", block: "A/2", stain: "H&E") == "K123_A2_HE")
}

@Test func parsesPathologyBlockAndLongestStain() {
    let parsed = OCRService.parse(["K1234", "2", "CD31"])
    #expect(parsed.pathology == "K1234")
    #expect(parsed.block == "2")
    #expect(parsed.stain == "CD31")
}

@Test func correctsCloseStainAndPrefersShortPathologyIdentifier() {
    let parsed = OCRService.parse(["KP17-99999", "K599", "C0163"])
    #expect(parsed.pathology == "K599")
    #expect(parsed.stain == "CD163")
}

@Test func doesNotTreatHER2AsHE() {
    let parsed = OCRService.parse(["K200", "HER2"])
    #expect(parsed.stain == "HER2")
}
