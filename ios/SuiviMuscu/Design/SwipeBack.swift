import UIKit

/// Les écrans ont leur propre en-tête (la barre de navigation du système est masquée), ce qui
/// désactive le geste « glisser depuis le bord gauche pour revenir ». On le rétablit ici :
/// c'est le retour le plus naturel sur iPhone, surtout d'une seule main.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
