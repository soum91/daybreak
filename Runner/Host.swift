import UIKit
@main final class RunnerHarness: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let controller = UIViewController()
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.text = "Daybreak Runner\nInstalled version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") (build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"))"
        controller.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: controller.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: controller.view.trailingAnchor, constant: -20)
        ])
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
        return true
    }
}
