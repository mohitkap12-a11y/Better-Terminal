import AppKit

/// Turns a key press into the bytes a terminal sends to the shell. Used to repeat typing in other panes
/// (broadcast). Covers text, return, tab, delete, escape, arrows, home/end, forward delete and ⌃-letters.
/// Anything with ⌘ is a menu shortcut and is never repeated.
enum KeyBytes {
    static func bytes(for event: NSEvent) -> [UInt8]? {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if flags.contains(.command) { return nil }
        let esc: [UInt8] = [0x1B]
        switch event.keyCode {
        case 36, 76: return [0x0D]                                   // return, enter
        case 48: return flags.contains(.shift) ? esc + Array("[Z".utf8) : [0x09]
        case 51: return [0x7F]                                       // delete (backspace)
        case 53: return esc
        case 123: return esc + Array("[D".utf8)                      // arrows
        case 124: return esc + Array("[C".utf8)
        case 125: return esc + Array("[B".utf8)
        case 126: return esc + Array("[A".utf8)
        case 115: return esc + Array("[H".utf8)                      // home
        case 119: return esc + Array("[F".utf8)                      // end
        case 117: return esc + Array("[3~".utf8)                     // forward delete
        default: break
        }
        if flags.contains(.control), let c = event.charactersIgnoringModifiers?.unicodeScalars.first {
            let v = c.value
            if v >= 0x61 && v <= 0x7A { return [UInt8(v - 0x60)] }   // ⌃a…⌃z
            if v >= 0x40 && v <= 0x5F { return [UInt8(v - 0x40)] }
        }
        guard let chars = event.characters, !chars.isEmpty else { return nil }
        // Function keys come as private-use characters; they have no plain bytes.
        if chars.unicodeScalars.contains(where: { (0xF700...0xF8FF).contains($0.value) }) { return nil }
        return Array(chars.utf8)
    }
}
