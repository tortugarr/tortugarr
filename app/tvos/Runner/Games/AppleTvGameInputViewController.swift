import GameController
import UIKit

// Transparent controller-capture layer shown over the Flutter view while a game
// runs. With controllerUserInteractionEnabled = false, gamepad input goes to the
// GameController framework (the core) instead of the tvOS focus engine, so
// gameplay does not also drive Flutter focus. Siri-remote presses are forwarded
// to Dart so the overlay can be navigated and Menu can exit (HIG requirement).
final class AppleTvGameInputViewController: GCEventViewController {
    var onRemotePress: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        controllerUserInteractionEnabled = false
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            let key: String?
            switch press.type {
            case .menu: key = "menu"
            case .select: key = "select"
            case .playPause: key = "playPause"
            case .upArrow: key = "up"
            case .downArrow: key = "down"
            case .leftArrow: key = "left"
            case .rightArrow: key = "right"
            default: key = nil
            }
            if let key {
                handled = true
                onRemotePress?(key)
            }
        }
        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }
}
