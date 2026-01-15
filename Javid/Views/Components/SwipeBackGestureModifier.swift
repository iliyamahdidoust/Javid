import SwiftUI

// Enable swipe-back gesture when navigation bar is hidden
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

// Custom ViewModifier to enable swipe back
struct SwipeBackGesture: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Enable swipe back gesture
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let navigationController = window.rootViewController?.navigationController {
                    navigationController.interactivePopGestureRecognizer?.isEnabled = true
                    navigationController.interactivePopGestureRecognizer?.delegate = navigationController
                }
            }
    }
}

extension View {
    func enableSwipeBack() -> some View {
        modifier(SwipeBackGesture())
    }
}
