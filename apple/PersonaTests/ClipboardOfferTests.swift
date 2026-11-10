import Foundation
import Testing
@testable import Persona

/// "Send what you just copied to …?" (#3064): when it is offered, and to which computer.
struct ClipboardOfferTests {
    private func machine(_ id: String, online: Bool = true, clipboard: MachineClipboard? = MachineClipboard(supported: true, enabled: true),
                         trust: String? = nil) -> Machine {
        var m = Machine(id: id, name: id, kind: "ssh", online: online)
        m.clipboard = clipboard
        m.trust = trust
        return m
    }

    @Test func offersOnlyWhenOnChangedAndNotEmpty() {
        #expect(ClipboardOffer.shouldOffer(enabled: true, seen: 4, now: 5, hasContent: true))
        #expect(!ClipboardOffer.shouldOffer(enabled: false, seen: 4, now: 5, hasContent: true), "off by default")
        #expect(!ClipboardOffer.shouldOffer(enabled: true, seen: 5, now: 5, hasContent: true), "nothing new was copied")
        #expect(!ClipboardOffer.shouldOffer(enabled: true, seen: 4, now: 5, hasContent: false), "the copy was cleared")
        #expect(!ClipboardOffer.shouldOffer(enabled: true, seen: nil, now: 5, hasContent: true), "no baseline yet")
    }

    @Test func picksTheLastComputerThatCanTakeIt() {
        let off = machine("off", clipboard: MachineClipboard(supported: true, enabled: false))
        let unsupported = machine("linux", clipboard: MachineClipboard(supported: false, enabled: true))
        let asleep = machine("asleep", online: false)
        let pending = machine("pending", trust: "pending")
        let a = machine("a"), b = machine("b")
        let all = [off, unsupported, asleep, pending, machine("old", clipboard: nil), a, b]
        #expect(ClipboardOffer.target(all, preferred: nil)?.id == "a")
        #expect(ClipboardOffer.target(all, preferred: b.ref.path)?.id == "b")
        #expect(ClipboardOffer.target(all, preferred: asleep.ref.path)?.id == "a", "the last one is offline: the first ready one")
        #expect(ClipboardOffer.target([off, unsupported, asleep], preferred: nil) == nil)
    }
}
