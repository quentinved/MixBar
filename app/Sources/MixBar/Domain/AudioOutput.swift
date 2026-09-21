import Foundation

/// A destination audio can be sent to.
struct AudioOutput: Identifiable, Hashable, Sendable {
    /// What the sound actually comes out of.
    ///
    /// Names alone do not say: "BlackHole 2ch", "Q's AirPods" and "LG HDR 4K"
    /// read as one undifferentiated list. The order of the cases is the order
    /// the sections appear in, nearest thing first.
    enum Kind: CaseIterable, Sendable {
        case builtIn
        case headphones
        case bluetooth
        case airPlay
        case display
        case external
        case virtual

        var title: String {
            switch self {
            case .builtIn: return "Built-in"
            case .headphones: return "Headphones"
            case .bluetooth: return "Bluetooth"
            case .airPlay: return "AirPlay"
            case .display: return "Displays"
            case .external: return "External"
            case .virtual: return "Virtual"
            }
        }
    }

    let id: String
    let name: String
    let kind: Kind

    /// An unrecognised transport is some box plugged into the Mac, which is
    /// what `.external` says and the only honest guess.
    init(id: String, name: String, kind: Kind = .external) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

extension AudioOutput {
    /// A run of devices sharing a kind, as the picker draws them.
    struct Section: Identifiable, Equatable, Sendable {
        let kind: Kind
        let outputs: [AudioOutput]

        var id: Kind { kind }
    }

    /// Groups devices by kind, in `Kind` order, dropping the kinds nobody has.
    static func sections(of outputs: [AudioOutput]) -> [Section] {
        Kind.allCases.compactMap { kind in
            let matching = outputs.filter { $0.kind == kind }
            return matching.isEmpty ? nil : Section(kind: kind, outputs: matching)
        }
    }
}
