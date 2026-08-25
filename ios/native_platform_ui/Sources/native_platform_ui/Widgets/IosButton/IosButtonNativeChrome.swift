import UIKit

@available(iOS 15.0, *)
enum IosButtonNativeChrome {
    static let horizontalInset: CGFloat = 12

    static func borderlessConfiguration(
        cornerRadius: CGFloat,
        inGlassContainer: Bool = true
    ) -> UIButton.Configuration {
        var config = UIButton.Configuration.borderless()
        config.background.backgroundColor = .clear
        config.cornerStyle = .fixed
        config.background.cornerRadius = inGlassContainer ? 0 : cornerRadius
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: horizontalInset,
            bottom: 0,
            trailing: horizontalInset
        )
        return config
    }
}
