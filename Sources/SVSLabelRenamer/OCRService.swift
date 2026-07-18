import CoreGraphics
import Foundation
import Vision

struct ParsedLabel: Sendable {
    var pathology = ""
    var block = ""
    var stain = ""
    var raw = ""
}

enum OCRServiceError: LocalizedError {
    case noResult

    var errorDescription: String? { "ラベルの文字を読み取れませんでした" }
}

struct OCRService {
    private struct Recognition: Sendable {
        let text: String
        let confidence: Float
    }

    private struct StainMatch {
        let index: Int
        let name: String
        let distance: Int
    }

    private static let knownStains = [
        "HE", "H&E", "CD3", "CD4", "CD8", "CD20", "CD31", "CD34", "CD56", "CD68",
        "CD163", "KI67", "KI-67", "P53", "AE1AE3", "AE1/AE3", "SMA", "DESMIN",
        "S100", "SOX10", "ER", "PR", "HER2", "PD-L1", "PDL1"
    ]

    static func recognize(_ image: CGImage) throws -> ParsedLabel {
        var best: [Recognition] = []
        var lastError: Error?
        for orientation in [CGImagePropertyOrientation.up, .right, .down, .left] {
            do {
                let observations = try recognize(image, orientation: orientation)
                if score(observations) > score(best) { best = observations }
            } catch {
                lastError = error
            }
        }
        if best.isEmpty { throw lastError ?? OCRServiceError.noResult }
        let lines = best.map(\.text)
        return parse(lines)
    }

    private static func recognize(
        _ image: CGImage, orientation: CGImagePropertyOrientation
    ) throws -> [Recognition] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)
        try handler.perform([request])
        let observations = request.results ?? []
        return observations.compactMap { observation -> Recognition? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return Recognition(text: candidate.string, confidence: candidate.confidence)
        }
    }

    private static func score(_ observations: [Recognition]) -> Float {
        let text = observations.map(\.text)
        let parsed = parse(text)
        let structureBonus: Float = (parsed.pathology.isEmpty ? 0 : 2) + (parsed.stain.isEmpty ? 0 : 3)
        return observations.map(\.confidence).reduce(0, +) + structureBonus
    }

    static func parse(_ lines: [String]) -> ParsedLabel {
        let normalized = lines.map { $0.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        let candidates = normalized.flatMap { line in
            line.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
        }.filter { !$0.isEmpty }

        var stainMatches: [StainMatch] = []
        for (index, token) in candidates.enumerated() {
            let cleaned = stainKey(token)
            var tokenMatches: [(String, Int)] = []
            for known in knownStains {
                let distance = editDistance(cleaned, stainKey(known))
                if distance <= (cleaned.count >= 5 ? 1 : 0) {
                    tokenMatches.append((known, distance))
                }
            }
            tokenMatches.sort {
                $0.1 == $1.1 ? stainKey($0.0).count > stainKey($1.0).count : $0.1 < $1.1
            }
            if let match = tokenMatches.first {
                stainMatches.append(StainMatch(index: index, name: canonicalStain(match.0), distance: match.1))
            }
        }
        stainMatches.sort {
            $0.distance == $1.distance ? $0.name.count > $1.name.count : $0.distance < $1.distance
        }
        let stainMatch = stainMatches.first

        let pathologyMatches = candidates.enumerated().filter { index, token in
            index != stainMatch?.index &&
            token.range(of: #"^[A-Z]{1,3}[A-Z0-9-]*[0-9][A-Z0-9-]*$"#, options: .regularExpression) != nil
        }.sorted { pathologyScore($0.element) > pathologyScore($1.element) }
        let pathologyMatch = pathologyMatches.first

        var block = ""
        if let pathologyIndex = pathologyMatch?.offset, let stainIndex = stainMatch?.index,
           pathologyIndex < stainIndex {
            block = candidates[(pathologyIndex + 1)..<stainIndex].first {
                $0.range(of: #"^(?:[A-Z]{1,2}|[A-Z]?[0-9]{1,2})$"#, options: .regularExpression) != nil
            } ?? ""
        }

        return ParsedLabel(
            pathology: pathologyMatch?.element ?? "",
            block: block,
            stain: stainMatch?.name ?? "",
            raw: lines.joined(separator: " | ")
        )
    }

    private static func pathologyScore(_ token: String) -> Int {
        var score = 0
        if token.hasPrefix("K") { score += 6 }
        if !token.contains("-") { score += 4 }
        if (3...8).contains(token.count) { score += 3 }
        if token.count > 10 { score -= 5 }
        return score
    }

    private static func stainKey(_ value: String) -> String {
        String(value.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func canonicalStain(_ value: String) -> String {
        switch stainKey(value) {
        case "HE": return "HE"
        case "KI67": return "Ki-67"
        case "PDL1": return "PD-L1"
        default: return value.uppercased()
        }
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1]
            for (j, right) in b.enumerated() {
                let insertion = current[j] + 1
                let deletion = previous[j + 1] + 1
                let substitution = previous[j] + (left == right ? 0 : 1)
                current.append(min(min(insertion, deletion), substitution))
            }
            previous = current
        }
        return previous[b.count]
    }
}
