import Foundation

enum PasteScriptPreset: String, CaseIterable, Identifiable {
    case addTerminalPeriod
    case removeTerminalPeriod

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .addTerminalPeriod:
            return String(localized: "Add Terminal Period")
        case .removeTerminalPeriod:
            return String(localized: "Remove Terminal Period")
        }
    }

    var script: String {
        switch self {
        case .addTerminalPeriod:
            return #"""
                perl -0777 -CSD -Mutf8 -pe 's/\h*(?:\.{3}|…)\h+([A-Z])/ \L$1/g;
                s/\h*(?:\.{3}|…)\h+/ /g;
                s/\s*(?:\.{3}|…)\s*$//;
                s/\h*[—–-]+\h+([A-Z])/ \L$1/g;
                s/[—–-]+\s*$//;
                s/\s+$//; $_ .= "." unless /[.!?]["\x27”’]?$/; $_ .= " ";'
                """#
        case .removeTerminalPeriod:
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
