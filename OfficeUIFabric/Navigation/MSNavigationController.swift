//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import UIKit

// MARK: MSNavigationController

/// UINavigationController subclass that supports Large Title presentation and accessory view.
@objcMembers
open class MSNavigationController: UINavigationController {
    static let showsShyHeaderByDefault: Bool = true //will display/hide the shy container header at startup depending on value

    open var msNavigationBar: MSNavigationBar {
        guard let msNavBar = navigationBar as? MSNavigationBar else {
            fatalError("The navigation bar is either not present or not the correct class")
        }
        return msNavBar
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBarStyleFromNavBar()
    }

    private let transitionAnimator = MSNavigationAnimator()

    public convenience init() {
        self.init(navigationBarClass: nil, toolbarClass: nil)
    }

    public override init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: MSNavigationBar.self, toolbarClass: toolbarClass)
    }

    public convenience override init(rootViewController: UIViewController) {
        self.init()
        setViewControllers([rootViewController], animated: false)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        // We tap into the NavController's pop gesture to coordinate our own NavBar's content alongside the native transition
        if let popGesture = interactivePopGestureRecognizer {
            popGesture.delegate = nil
            popGesture.removeTarget(nil, action: nil)
            popGesture.addTarget(self, action: #selector(navigationPopScreenPanGestureRecognizerRecognized))
        }

        delegate = self

        // Allow subviews to display a custom background view
        view.subviews.forEach { $0.clipsToBounds = false }
    }

    open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(wrapViewControllerIfNeeded(viewController), animated: animated)
    }

    open override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        let viewControllers = viewControllers.map { wrapViewControllerIfNeeded($0) }
        super.setViewControllers(viewControllers, animated: animated)
    }

    public func expandNavigationBar(animated: Bool) {
        msNavigationBar.expand(animated)
        (topViewController as? MSShyHeaderController)?.expandAccessory()
    }

    public func contractNavigationBar(animated: Bool) {
        msNavigationBar.contract(animated)
        (topViewController as? MSShyHeaderController)?.contractAccessory()
    }

    private func wrapViewControllerIfNeeded(_ viewController: UIViewController) -> UIViewController {
        if !viewControllerNeedsWrapping(viewController) {
            return viewController
        }
        return MSShyHeaderController(contentVC: viewController)
    }

    private func viewControllerNeedsWrapping(_ viewController: UIViewController) -> Bool {
        if viewController is MSShyHeaderController {
            return false
        }
        if viewController.navigationItem.usesLargeTitle || viewController.navigationItem.accessoryView != nil {
            return true
        }
        return false
    }

    /// Uses the navigationItem property of UIViewController to update the NavigationBar
    ///
    /// - Parameter viewController: the UIViewController instance to be presented
    func updateNavigationBar(using viewController: UIViewController) {
        msNavigationBar.update(with: viewController.navigationItem)
        setNeedsStatusBarAppearanceUpdate()
        transitionAnimator.tintColor = msNavigationBar.backgroundView.backgroundColor!
    }

    open override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        if animated {
            if hidden {
                msNavigationBar.obscureContent()
            } else {
                msNavigationBar.revealContent()
            }
        }

        super.setNavigationBarHidden(hidden, animated: animated)
    }

    /// Secondary target for the default InteractivePopGestureRecognizer
    /// Used to handle the case of a cancelled pop gesture
    ///
    /// - Parameter gesture: the default UIScreenEdgePanGestureRecognizer which powers the standard pop interaction on a UINavigationController
    @objc private func navigationPopScreenPanGestureRecognizerRecognized(gesture: UIScreenEdgePanGestureRecognizer) {
        let percent = gesture.translation(in: gesture.view!).x / gesture.view!.bounds.size.width

        switch gesture.state {
        case .began:
            transitionAnimator.isInteractiveTransition = true
            popViewController(animated: true)
        case .changed:
            transitionAnimator.update(percent)
        case .ended, .cancelled:
            if gesture.state == .ended {
                if percent >= 0.5 {
                    self.transitionAnimator.finish()
                } else if let view = gesture.view, gesture.velocity(in: view).x > CGFloat(250) {
                    // speed to the right is greater than 250 points per second
                    transitionAnimator.finish()
                } else {
                    transitionAnimator.cancel()
                }
            } else {
                transitionAnimator.cancel()
            }

            transitionAnimator.isInteractiveTransition = false
        default:
            return
        }
    }

    /// Call this function from an override of `UIViewController`'s `preferredStatusBarStyle` to set the status bar style dynamically based on the nav bar.
    private func statusBarStyleFromNavBar() -> UIStatusBarStyle {
        return msNavigationBar.style == .system ? .default : .lightContent
    }
}

// MARK: - MSNavigationController: UINavigationControllerDelegate

extension MSNavigationController: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        updateNavigationBar(using: viewController)
    }

    public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if transitionAnimator.isInteractiveTransition {
            return transitionAnimator
        }

        return nil
    }

    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transitionAnimator.navigationController = navigationController
        transitionAnimator.operation = operation
        return transitionAnimator
    }
}