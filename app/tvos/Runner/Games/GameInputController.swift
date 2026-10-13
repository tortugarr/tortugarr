import Foundation
import GameController

// Maps connected GCControllers to per-port RetroPad bitmasks, read lock-free by the
// core's input_state callback on the emulation thread. Button changes are also mirrored
// to Dart so the in-game overlay can be navigated with the same controller.
//
// The Menu button opens that overlay: tvOS reserves it as the pause/back button and the
// system grabs combos like Start+Select before the app sees them, so Menu is the one
// dependable way in. Options maps to RetroPad Start so games are still startable.
final class GameInputController {
    // RetroPad ids (RETRO_DEVICE_ID_JOYPAD_*)
    private enum Pad {
        static let b: UInt16 = 1 << 0
        static let y: UInt16 = 1 << 1
        static let select: UInt16 = 1 << 2
        static let start: UInt16 = 1 << 3
        static let up: UInt16 = 1 << 4
        static let down: UInt16 = 1 << 5
        static let left: UInt16 = 1 << 6
        static let right: UInt16 = 1 << 7
        static let a: UInt16 = 1 << 8
        static let x: UInt16 = 1 << 9
        static let l: UInt16 = 1 << 10
        static let r: UInt16 = 1 << 11
        static let l2: UInt16 = 1 << 12
        static let r2: UInt16 = 1 << 13
        static let l3: UInt16 = 1 << 14
        static let r3: UInt16 = 1 << 15
    }

    // Written on the main queue (GC handlers), read on the emulation thread.
    // UInt16 stores cannot tear on arm64.
    nonisolated(unsafe) private var portMasks = [UInt16](repeating: 0, count: 4)

    // Buttons the overlay pulses (Start/Select), ORed into port 0 at read time so a
    // live controller refresh cannot clear them mid-pulse.
    nonisolated(unsafe) private var pulseMask: UInt16 = 0
    private var pulseWork: [Int: DispatchWorkItem] = [:]

    var onMenuPressed: (() -> Void)?
    var onButton: ((Int, Bool) -> Void)?
    var onControllersChanged: ((Int) -> Void)?

    private var observers: [NSObjectProtocol] = []

    var controllerCount: Int {
        GCController.controllers().filter { $0.extendedGamepad != nil }.count
    }

    func start() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: .GCControllerDidConnect, object: nil, queue: .main
            ) { [weak self] _ in
                self?.attachAll()
                self?.notifyChanged()
            })
        observers.append(
            center.addObserver(
                forName: .GCControllerDidDisconnect, object: nil, queue: .main
            ) { [weak self] _ in
                self?.attachAll()
                self?.notifyChanged()
            })
        attachAll()
        GCController.startWirelessControllerDiscovery()
    }

    func stop() {
        GCController.stopWirelessControllerDiscovery()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        pulseWork.values.forEach { $0.cancel() }
        pulseWork.removeAll()
        pulseMask = 0
        for c in GCController.controllers() {
            c.extendedGamepad?.valueChangedHandler = nil
            c.extendedGamepad?.buttonMenu.pressedChangedHandler = nil
        }
        portMasks = [0, 0, 0, 0]
    }

    nonisolated func mask(forPort port: Int) -> UInt16 {
        guard port >= 0, port < portMasks.count else { return 0 }
        return port == 0 ? portMasks[0] | pulseMask : portMasks[port]
    }

    // Briefly holds a RetroPad button on port 0, for the overlay's Start/Select actions.
    func pulse(index: Int, durationMs: Int) {
        guard index >= 0, index < 16 else { return }
        let bit = UInt16(1) << UInt16(index)
        pulseMask |= bit
        pulseWork[index]?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.pulseMask &= ~bit }
        pulseWork[index] = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Double(durationMs) / 1000.0, execute: work)
    }

    private func notifyChanged() {
        onControllersChanged?(controllerCount)
    }

    private func attachAll() {
        let pads = GCController.controllers().filter { $0.extendedGamepad != nil }
        for (port, controller) in pads.enumerated() where port < portMasks.count {
            controller.playerIndex = GCControllerPlayerIndex(rawValue: port) ?? .indexUnset
            let gamepad = controller.extendedGamepad!
            gamepad.valueChangedHandler = { [weak self] pad, _ in
                self?.refresh(pad: pad, port: port)
            }
            gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.onMenuPressed?() }
            }
        }
        for port in pads.count..<portMasks.count {
            portMasks[port] = 0
        }
    }

    private func refresh(pad: GCExtendedGamepad, port: Int) {
        var mask: UInt16 = 0
        if pad.buttonA.isPressed { mask |= Pad.b }      // GC A (bottom) = RetroPad B
        if pad.buttonB.isPressed { mask |= Pad.a }      // GC B (right)  = RetroPad A
        if pad.buttonX.isPressed { mask |= Pad.y }      // GC X (left)   = RetroPad Y
        if pad.buttonY.isPressed { mask |= Pad.x }      // GC Y (top)    = RetroPad X
        if pad.dpad.up.isPressed || pad.leftThumbstick.up.isPressed { mask |= Pad.up }
        if pad.dpad.down.isPressed || pad.leftThumbstick.down.isPressed { mask |= Pad.down }
        if pad.dpad.left.isPressed || pad.leftThumbstick.left.isPressed { mask |= Pad.left }
        if pad.dpad.right.isPressed || pad.leftThumbstick.right.isPressed { mask |= Pad.right }
        if pad.leftShoulder.isPressed { mask |= Pad.l }
        if pad.rightShoulder.isPressed { mask |= Pad.r }
        if pad.leftTrigger.isPressed { mask |= Pad.l2 }
        if pad.rightTrigger.isPressed { mask |= Pad.r2 }
        if pad.leftThumbstickButton?.isPressed == true { mask |= Pad.l3 }
        if pad.rightThumbstickButton?.isPressed == true { mask |= Pad.r3 }
        if pad.buttonOptions?.isPressed == true { mask |= Pad.start }

        let old = portMasks[port]
        portMasks[port] = mask
        emitDiffs(old: old, new: mask, port: port)
    }

    private func emitDiffs(old: UInt16, new: UInt16, port: Int) {
        guard port == 0, old != new, let onButton else { return }
        for bit in 0..<16 where (old ^ new) & (1 << bit) != 0 {
            onButton(bit, new & (1 << bit) != 0)
        }
    }
}
