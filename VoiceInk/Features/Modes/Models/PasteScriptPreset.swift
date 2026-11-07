import Foundation

enum PasteScriptPreset: String, CaseIterable, Identifiable {
    case addTrailingPeriod
    case removeTrailingPeriod

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .addTrailingPeriod:
            return String(localized: "Add Trailing Period")
        case .removeTrailingPeriod:
            return String(localized: "Remove Trailing Period")
        }
    }

    var script: String {
        switch self {
        case .addTrailingPeriod:
            return #"""
                perl -0777 -CSD -Mutf8 -pe 's/\h*(?:\.{3}|…)\h+([A-Z])/ \L$1/g;
                s/\h*(?:\.{3}|…)\h+/ /g;
                s/\s*(?:\.{3}|…)\s*$//;
                s/\h*[—–-]+\h+([A-Z])/ \L$1/g;
                s/[—–-]+\s*$//;
                s/\s+$//; $_ .= "." unless /[.!?]["\x27”’]?$/; $_ .= " ";'
                """#
        case .removeTrailingPeriod:
            return #"""
                perl -0777 -CSD -Mutf8 -pe 's/\h*(?:\.{3}|…)\h+([A-Z])/ \L$1/g;
                s/\h*(?:\.{3}|…)\h+/ /g;
                s/\s*(?:\.{3}|…)\s*$//;
                s/\h*[—–-]+\h+([A-Z])/ \L$1/g;
                s/[—–-]+\s*$//;
                s/\s+$//; s/\.$//;'
                """#
        }
    }
}
