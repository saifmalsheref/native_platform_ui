
import Flutter
import UIKit

// Custom UIView subclass to handle didMoveToWindow callback
private class TabBarContainerView: UIView {
    var onDidMoveToWindow: (() -> Void)?
    var onTraitCollectionDidChange: (() -> Void)?
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            // View has entered the window hierarchy
            // This is the perfect time to recalculate layout for Arabic text
            onDidMoveToWindow?()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            onTraitCollectionDidChange?()
        }
    }
}

class NativeIOSBottomNavBarView: NSObject, FlutterPlatformView {
    private var _view: TabBarContainerView
    private var tabBar: UITabBar
    private var methodChannel: FlutterMethodChannel
    private var viewId: Int64
    private var tabBarItems: [UITabBarItem] = []
    private var isUpdatingProgrammatically = false
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        self.viewId = viewId
        self.tabBar = UITabBar()
        
        // Create container view with didMoveToWindow support
        self._view = TabBarContainerView(frame: frame)
        self._view.backgroundColor = .clear
        
        // Set up method channel - unique per view instance
        self.methodChannel = FlutterMethodChannel(
            name: "native_ios_bottom_nav_bar_\(viewId)",
            binaryMessenger: messenger!
        )
        
        super.init()

        // Configure tab bar
        tabBar.delegate = self
        tabBar.isTranslucent = false
        tabBar.frame = _view.bounds
        tabBar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Force RTL layout to ensure items always start from right to left
        tabBar.semanticContentAttribute = .forceRightToLeft
        _view.semanticContentAttribute = .forceRightToLeft
        
        // Ensure equal spacing between items on iPad
        tabBar.itemPositioning = .centered
        tabBar.itemSpacing = 0
        tabBar.itemWidth = 0
        
        _view.addSubview(tabBar)
        
        // Set up didMoveToWindow callback
        // This is CRITICAL: ensures layout recalculation after view enters window hierarchy
        // and Arabic font metrics are ready
        _view.onDidMoveToWindow = { [weak self] in
            guard let self = self else { return }
            // Force layout update after view has moved to window
            // This ensures Arabic text is properly calculated
            DispatchQueue.main.async {
                self.forceLayoutUpdate()
                self.updateForSizeClass()
                let selectedIndex = self.tabBar.selectedItem.flatMap { self.tabBarItems.firstIndex(of: $0) } ?? 0
                self.updateItemColors(selectedIndex: selectedIndex)
            }
        }
        
        // Monitor trait collection changes (for iPad Split View / Slide Over)
        _view.onTraitCollectionDidChange = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.updateForSizeClass()
                let selectedIndex = self.tabBar.selectedItem.flatMap { self.tabBarItems.firstIndex(of: $0) } ?? 0
                self.updateItemColors(selectedIndex: selectedIndex)
            }
        }
        
        // Parse arguments and setup
        if let args = args as? [String: Any] {
            setupTabBar(with: args)
        }
        
        // Set up method channel handler
        setupMethodChannel()
    }
    
    func view() -> UIView {
        return _view
    }

    private func applyMaterialBrightness(from args: [String: Any]) {
        let materialBrightness: Int = {
            if let v = args["materialBrightness"] as? Int { return v }
            if let n = args["materialBrightness"] as? NSNumber { return n.intValue }
            return -1
        }()
        guard #available(iOS 13.0, *) else { return }
        let style: UIUserInterfaceStyle
        switch materialBrightness {
        case 0:
            style = .light
        case 1:
            style = .dark
        default:
            style = .unspecified
        }
        _view.overrideUserInterfaceStyle = style
        tabBar.overrideUserInterfaceStyle = style
    }
    
    private func setupTabBar(with args: [String: Any]) {
        guard let itemsData = args["items"] as? [[String: Any?]] else {
            return
        }
        
        let selectedIndex = args["selectedIndex"] as? Int ?? 0
        let tintColorValue = args["tintColor"] as? Int
        let unselectedTintColorValue = args["unselectedTintColor"] as? Int

        applyMaterialBrightness(from: args)
        
        // Create tab bar items
        tabBarItems = []
        for (index, itemData) in itemsData.enumerated() {
            let title = itemData["title"] as? String ?? ""
            let iconName = itemData["icon"] as? String ?? ""
            let assetImage = itemData["assetImage"] as? String
            let iconType = itemData["iconType"] as? String
            let iconData = itemData["icon"] as? String // May contain base64 data for SVG
            
            let activeIconName = itemData["activeIcon"] as? String
            let activeIconType = itemData["activeIconType"] as? String
            let activeIconData = itemData["activeIcon"] as? String
            
            // Get custom colors for this item
            let activeTextColorValue = itemData["activeTextColor"] as? Int
            let inactiveTextColorValue = itemData["inactiveTextColor"] as? Int
            let activeImageColorValue = itemData["activeImageColor"] as? Int
            let inactiveImageColorValue = itemData["inactiveImageColor"] as? Int
            let iconSize = parseIconSize(itemData["iconSize"])
            let activeIconSize = parseIconSize(itemData["activeIconSize"])

            let tabBarItem = createTabBarItem(
                title: title,
                iconName: iconName,
                assetImage: assetImage,
                index: index,
                iconType: iconType,
                iconData: iconType == "svg" ? iconData : nil,
                activeIconName: activeIconName,
                activeIconType: activeIconType,
                activeIconData: activeIconType == "svg" ? activeIconData : nil,
                iconSize: iconSize,
                activeIconSize: activeIconSize,
                activeTextColor: activeTextColorValue != nil ? UIColor(hex: UInt32(activeTextColorValue!)) : nil,
                inactiveTextColor: inactiveTextColorValue != nil ? UIColor(hex: UInt32(inactiveTextColorValue!)) : nil,
                activeImageColor: activeImageColorValue != nil ? UIColor(hex: UInt32(activeImageColorValue!)) : nil,
                inactiveImageColor: inactiveImageColorValue != nil ? UIColor(hex: UInt32(inactiveImageColorValue!)) : nil
            )
            tabBarItems.append(tabBarItem)
        }
        
        tabBar.items = tabBarItems
        
        // Set selected item
        if selectedIndex >= 0 && selectedIndex < tabBarItems.count {
            isUpdatingProgrammatically = true
            // Let UITabBar handle the selection - it will update the UI automatically
            tabBar.selectedItem = tabBarItems[selectedIndex]
            isUpdatingProgrammatically = false
        }
        
        // Set default tint colors (used as fallback if item-specific colors not provided)
        if let tintColorValue = tintColorValue {
            tabBar.tintColor = UIColor(hex: UInt32(tintColorValue))
        } else {
            tabBar.tintColor = UIColor.systemBlue
        }
        
        if let unselectedTintColorValue = unselectedTintColorValue {
            tabBar.unselectedItemTintColor = UIColor(hex: UInt32(unselectedTintColorValue))
        } else {
            tabBar.unselectedItemTintColor = UIColor.systemGray
        }
        
        // Initial layout setup
        // Note: Final layout recalculation will happen in didMoveToWindow
        // after the view enters the window hierarchy and Arabic font metrics are ready
        forceLayoutUpdate()
        
        // Update for initial size class (must be before applyItemSpecificColors)
        updateForSizeClass()
        
        // Apply item-specific colors using UITabBarAppearance (iOS 13+)
        if #available(iOS 13.0, *) {
            applyItemSpecificColors(selectedIndex: selectedIndex)
        }
        
        // Apply colors after size class update
        updateItemColors(selectedIndex: selectedIndex)
    }
    
    /// iPhone / iPad compact width: stacked icon + title.
    private func regularWidthTabBarTitleFont() -> UIFont? {
        guard _view.traitCollection.horizontalSizeClass == .compact else { return nil }
        let base = UIFont.systemFont(ofSize: 11, weight: .medium)
        return UIFontMetrics.default.scaledFont(for: base, maximumPointSize: 14)
    }
    
    /// iPad regular width (full screen): icons only, no tab titles.
    private var isPadIconsOnlyLayout: Bool {
        _view.traitCollection.horizontalSizeClass != .compact
    }
    
    private func updateForSizeClass() {
        let isCompact = _view.traitCollection.horizontalSizeClass == .compact
        let selectedIndex = tabBar.selectedItem.flatMap { tabBarItems.firstIndex(of: $0) } ?? 0
        
        for (index, item) in tabBarItems.enumerated() {
            if isCompact {
                // iPad Split View / Slide Over (iPhone-style) → ICON + TEXT
                if let normalImage = originalImages[index] {
                    let template = normalImage.withRenderingMode(.alwaysTemplate)
                    item.image = template
                }
                if let selectedImage = originalSelectedImages[index] {
                    let template = selectedImage.withRenderingMode(.alwaysTemplate)
                    item.selectedImage = template
                } else if let normalImage = originalImages[index] {
                    let template = normalImage.withRenderingMode(.alwaysTemplate)
                    item.selectedImage = template
                }
                item.title = originalTitles[index]
                item.titlePositionAdjustment = .zero
            } else {
                // iPad full screen → ICON ONLY (no titles)
                if let normalImage = originalImages[index] {
                    let template = normalImage.withRenderingMode(.alwaysTemplate)
                    item.image = template
                }
                if let selectedImage = originalSelectedImages[index] {
                    let template = selectedImage.withRenderingMode(.alwaysTemplate)
                    item.selectedImage = template
                } else if let normalImage = originalImages[index] {
                    let template = normalImage.withRenderingMode(.alwaysTemplate)
                    item.selectedImage = template
                }
                item.title = nil
                item.titlePositionAdjustment = .zero
            }
        }
        
        forceLayoutUpdate()
        
        // Apply colors after updating size class
        updateItemColors(selectedIndex: selectedIndex)
    }
    
    private func forceLayoutUpdate() {
        // Invalidate intrinsic content size to force recalculation
        tabBar.invalidateIntrinsicContentSize()
        
        // Force constraints update
        tabBar.setNeedsUpdateConstraints()
        tabBar.updateConstraintsIfNeeded()
        
        // Force layout calculation
        tabBar.setNeedsLayout()
        tabBar.layoutIfNeeded()
        
        // Force display refresh
        tabBar.setNeedsDisplay()
        
        // Force parent view to update
        _view.setNeedsUpdateConstraints()
        _view.updateConstraintsIfNeeded()
        _view.setNeedsLayout()
        _view.layoutIfNeeded()
        _view.setNeedsDisplay()
    }
    
    private func loadImage(
        name: String?,
        type: String?,
        data: String?,
        assetImage: String?,
        size: CGFloat? = nil
    ) -> UIImage? {
        let targetSize = size ?? 22

        // SVG from base64
        if let type = type, type == "svg", let data = data,
           let decoded = Data(base64Encoded: data),
           let uiImage = UIImage(data: decoded) {
            return scaleImage(uiImage, to: targetSize)
        }

        // Asset image
        if let type = type, type == "asset", let name = name,
           let image = UIImage(named: name) {
            return scaleImage(image, to: targetSize)
        }

        // SF Symbol
        if let name = name, #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: targetSize, weight: .regular)
            if let sfSymbol = UIImage(systemName: name, withConfiguration: config) {
                return sfSymbol
            }
        }

        // Fallback to assetImage if provided
        if let assetImage = assetImage, let image = UIImage(named: assetImage) {
            return scaleImage(image, to: targetSize)
        }

        // Final fallback
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: targetSize, weight: .regular)
            return UIImage(systemName: "circle", withConfiguration: config)
        } else {
            return UIImage()
        }
    }

    private func scaleImage(_ image: UIImage, to pointSize: CGFloat) -> UIImage {
        let size = CGSize(width: pointSize, height: pointSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func parseIconSize(_ value: Any?) -> CGFloat? {
        if let value = value as? Double {
            return CGFloat(value)
        }
        if let value = value as? NSNumber {
            return CGFloat(value.doubleValue)
        }
        return nil
    }
    
    private func createTabBarItem(
        title: String,
        iconName: String,
        assetImage: String?,
        index: Int,
        iconType: String? = nil,
        iconData: String? = nil,
        activeIconName: String? = nil,
        activeIconType: String? = nil,
        activeIconData: String? = nil,
        iconSize: CGFloat? = nil,
        activeIconSize: CGFloat? = nil,
        activeTextColor: UIColor? = nil,
        inactiveTextColor: UIColor? = nil,
        activeImageColor: UIColor? = nil,
        inactiveImageColor: UIColor? = nil
    ) -> UITabBarItem {
        let normalImage = loadImage(
            name: iconName,
            type: iconType,
            data: iconType == "svg" ? iconData : nil,
            assetImage: assetImage,
            size: iconSize
        )

        let selectedImage = loadImage(
            name: activeIconName,
            type: activeIconType,
            data: activeIconType == "svg" ? activeIconData : nil,
            assetImage: nil,
            size: activeIconSize ?? iconSize
        ) ?? normalImage // Fallback to normal image if activeIcon not provided
        
        // Store original images for tinting later
        if let normalImage = normalImage {
            originalImages[index] = normalImage
        }
        if let selectedImage = selectedImage {
            originalSelectedImages[index] = selectedImage
        }
        
        originalTitles[index] = title
        
        let tabBarItem = UITabBarItem(
            title: title,
            image: normalImage?.withRenderingMode(.alwaysTemplate),
            selectedImage: selectedImage?.withRenderingMode(.alwaysTemplate)
        )
        tabBarItem.tag = index
        
        // Store custom colors
        if activeTextColor != nil || inactiveTextColor != nil || activeImageColor != nil || inactiveImageColor != nil {
            itemColors[index] = ItemColors(
                activeTextColor: activeTextColor,
                inactiveTextColor: inactiveTextColor,
                activeImageColor: activeImageColor,
                inactiveImageColor: inactiveImageColor
            )
        }
        
        return tabBarItem
    }
    
    // Store item-specific colors and original images
    private var itemColors: [Int: ItemColors] = [:]
    private var originalImages: [Int: UIImage] = [:] // Inactive images
    private var originalSelectedImages: [Int: UIImage] = [:] // Active images
    private var originalTitles: [Int: String] = [:]
    
    private struct ItemColors {
        let activeTextColor: UIColor?
        let inactiveTextColor: UIColor?
        let activeImageColor: UIColor?
        let inactiveImageColor: UIColor?
    }
    
    @available(iOS 13.0, *)
    private func applyItemSpecificColors(selectedIndex: Int) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // CRITICAL: Prevent UIKit from applying color blending/vibrancy effects
        // This ensures exact color matching with Flutter
        appearance.backgroundColor = UIColor.systemBackground
        appearance.shadowColor = .clear
        
        let titleFont = regularWidthTabBarTitleFont()
        
        // Apply colors for each item
        for (index, item) in tabBarItems.enumerated() {
            let colors = itemColors[index]
            let isSelected = index == selectedIndex
            
            // Create item appearance
            let itemAppearance = UITabBarItemAppearance()
            
            // Set text colors
            if let textColor = isSelected ? colors?.activeTextColor : colors?.inactiveTextColor {
                var normalAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: textColor]
                var selectedAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: textColor]
                if let titleFont = titleFont {
                    normalAttrs[.font] = titleFont
                    selectedAttrs[.font] = titleFont
                }
                itemAppearance.normal.titleTextAttributes = normalAttrs
                itemAppearance.selected.titleTextAttributes = selectedAttrs
            } else {
                // Use default colors
                var normalAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: tabBar.unselectedItemTintColor ?? UIColor.systemGray
                ]
                var selectedAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: tabBar.tintColor ?? UIColor.systemBlue
                ]
                if let titleFont = titleFont {
                    normalAttrs[.font] = titleFont
                    selectedAttrs[.font] = titleFont
                }
                itemAppearance.normal.titleTextAttributes = normalAttrs
                itemAppearance.selected.titleTextAttributes = selectedAttrs
            }
            
            // Set icon colors using iconColor property
            if let iconColor = isSelected ? colors?.activeImageColor : colors?.inactiveImageColor {
                itemAppearance.normal.iconColor = iconColor
                itemAppearance.selected.iconColor = iconColor
            } else {
                itemAppearance.normal.iconColor = tabBar.unselectedItemTintColor ?? UIColor.systemGray
                itemAppearance.selected.iconColor = tabBar.tintColor ?? UIColor.systemBlue
            }
            
            // iPad regular width uses inline tab layout; stackedLayoutAppearance alone is ignored.
            appearance.stackedLayoutAppearance = itemAppearance
            if #available(iOS 15.0, *) {
                appearance.inlineLayoutAppearance = itemAppearance
                appearance.compactInlineLayoutAppearance = itemAppearance
            }
            
            // Note: UITabBarAppearance applies to all items, so we need a different approach
            // We'll use setTitleTextAttributes and custom icon tinting instead
        }
        
        // Apply appearance
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        
        // Apply item-specific colors manually
        updateItemColors(selectedIndex: selectedIndex)
        
        // Force immediate UI update to prevent rendering issues
        forceLayoutUpdate()
    }
    
    private func updateItemColors(selectedIndex: Int) {
        let isCompact = _view.traitCollection.horizontalSizeClass == .compact
        let iconsOnly = isPadIconsOnlyLayout
        let titleFont = regularWidthTabBarTitleFont()
        
        // Use CATransaction to ensure immediate UI update
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0)
        
        for (index, item) in tabBarItems.enumerated() {
            let colors = itemColors[index]
            let isSelected = index == selectedIndex
            
            // iPad icons-only: hide titles; iPhone / compact iPad: show title styling
            if iconsOnly {
                item.title = nil
                item.setTitleTextAttributes([:], for: .normal)
                item.setTitleTextAttributes([:], for: .selected)
            } else if let textColor = isSelected ? colors?.activeTextColor : colors?.inactiveTextColor {
                var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: textColor]
                if let titleFont = titleFont {
                    attrs[.font] = titleFont
                }
                item.setTitleTextAttributes(attrs, for: .normal)
                item.setTitleTextAttributes(attrs, for: .selected)
            } else {
                if let titleFont = titleFont {
                    item.setTitleTextAttributes(
                        [
                            .foregroundColor: tabBar.unselectedItemTintColor ?? .systemGray,
                            .font: titleFont
                        ],
                        for: .normal
                    )
                    item.setTitleTextAttributes(
                        [
                            .foregroundColor: tabBar.tintColor ?? .systemBlue,
                            .font: titleFont
                        ],
                        for: .selected
                    )
                } else {
                    item.setTitleTextAttributes([:], for: .normal)
                    item.setTitleTextAttributes([:], for: .selected)
                }
            }
            
            // Update icon colors when icons are visible (compact or iPad icons-only)
            if isCompact || iconsOnly {
                // CRITICAL: For custom icon colors, use withTintColor with sRGB color
                // The UIColor(hex:) extension ensures sRGB color space, preventing Display-P3 conversion
                if let iconColor = isSelected ? colors?.activeImageColor : colors?.inactiveImageColor {
                    // Custom color: use withTintColor with sRGB color (from UIColor extension)
                    // Use the appropriate original image (inactive or active)
                    let originalImage = isSelected 
                        ? (originalSelectedImages[index] ?? originalImages[index])
                        : originalImages[index]
                    
                    if let originalImage = originalImage {
                        let tintedImage = originalImage.withTintColor(iconColor, renderingMode: .alwaysOriginal)
                        if isSelected {
                            item.selectedImage = tintedImage
                        } else {
                            item.image = tintedImage
                        }
                    }
                } else {
                    // No custom color: use template mode with tabBar tintColor
                    // This lets UITabBar handle tinting automatically
                    // Keep the original images with template rendering mode
                    if let originalImage = originalImages[index] {
                        item.image = originalImage.withRenderingMode(.alwaysTemplate)
                    }
                    if let originalSelectedImage = originalSelectedImages[index] {
                        item.selectedImage = originalSelectedImage.withRenderingMode(.alwaysTemplate)
                    } else if let originalImage = originalImages[index] {
                        // Fallback to normal image if no selected image
                        item.selectedImage = originalImage.withRenderingMode(.alwaysTemplate)
                    }
                }
            }
        }
        
        // Force immediate UI refresh after updating colors
        forceLayoutUpdate()
        
        CATransaction.commit()
    }
    
    private func setupMethodChannel() {
        methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else {
                result(nil)
                return
            }
            
            switch call.method {
            case "setSelectedIndex":
                if let args = call.arguments as? [String: Any],
                   let index = args["index"] as? Int {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else {
                            result(nil)
                            return
                        }
                        guard index >= 0 && index < self.tabBarItems.count else {
                            result(FlutterError(code: "INVALID_INDEX", message: "Index out of bounds", details: nil))
                            return
                        }
                        
                        let targetItem = self.tabBarItems[index]
                        
                        // Only update if it's different from current selection
                        // This prevents unnecessary updates that might interfere with user taps
                        if self.tabBar.selectedItem != targetItem {
                            // Use CATransaction to ensure immediate, synchronized UI update
                            CATransaction.begin()
                            CATransaction.setDisableActions(false)
                            CATransaction.setAnimationDuration(0)
                            
                            // Set flag to prevent delegate callback during programmatic update
                            self.isUpdatingProgrammatically = true
                            
                            // Set selected item - UITabBar will update UI automatically
                            self.tabBar.selectedItem = targetItem
                            
                            // Update item colors for new selection
                            if #available(iOS 13.0, *) {
                                self.updateItemColors(selectedIndex: index)
                            } else {
                                // Force layout update even on older iOS versions
                                self.forceLayoutUpdate()
                            }
                            
                            CATransaction.commit()
                            
                            // Reset flag after a short delay to ensure UI update completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                                self?.isUpdatingProgrammatically = false
                            }
                        }
                        
                        result(true)
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                }
                
            case "updateItems":
                if let args = call.arguments as? [String: Any],
                   let itemsData = args["items"] as? [[String: Any?]] {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else {
                            result(nil)
                            return
                        }
                        self.updateTabBarItems(itemsData: itemsData)
                        result(true)
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                }

            case "updateChrome":
                if let args = call.arguments as? [String: Any] {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else {
                            result(nil)
                            return
                        }
                        if let tintColorValue = args["tintColor"] as? Int {
                            self.tabBar.tintColor = UIColor(hex: UInt32(tintColorValue))
                        }
                        if let unselectedTintColorValue = args["unselectedTintColor"] as? Int {
                            self.tabBar.unselectedItemTintColor = UIColor(
                                hex: UInt32(unselectedTintColorValue)
                            )
                        }
                        self.applyMaterialBrightness(from: args)
                        let selectedIndex = self.tabBar.selectedItem.flatMap {
                            self.tabBarItems.firstIndex(of: $0)
                        } ?? 0
                        if #available(iOS 13.0, *) {
                            self.applyItemSpecificColors(selectedIndex: selectedIndex)
                        }
                        self.updateItemColors(selectedIndex: selectedIndex)
                        self.forceLayoutUpdate()
                        result(true)
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                }
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func updateTabBarItems(itemsData: [[String: Any?]]) {
        // CRITICAL: Don't reassign tabBar.items - it clears selectedItem!
        // Only update properties of existing items if count matches
        guard itemsData.count == tabBarItems.count else {
            // If count changed, we must recreate - but preserve selection
            let selectedIndex = tabBar.selectedItem.flatMap { tabBarItems.firstIndex(of: $0) }
            
            tabBarItems = []
            for (index, itemData) in itemsData.enumerated() {
                let title = itemData["title"] as? String ?? ""
                let iconName = itemData["icon"] as? String ?? ""
                let assetImage = itemData["assetImage"] as? String
                let iconType = itemData["iconType"] as? String
                let iconData = itemData["icon"] as? String
                
                let activeIconName = itemData["activeIcon"] as? String
                let activeIconType = itemData["activeIconType"] as? String
                let activeIconData = itemData["activeIcon"] as? String
                
                // Get custom colors for this item
                let activeTextColorValue = itemData["activeTextColor"] as? Int
                let inactiveTextColorValue = itemData["inactiveTextColor"] as? Int
                let activeImageColorValue = itemData["activeImageColor"] as? Int
                let inactiveImageColorValue = itemData["inactiveImageColor"] as? Int
                let iconSize = parseIconSize(itemData["iconSize"])
                let activeIconSize = parseIconSize(itemData["activeIconSize"])

                let tabBarItem = createTabBarItem(
                    title: title,
                    iconName: iconName,
                    assetImage: assetImage,
                    index: index,
                    iconType: iconType,
                    iconData: iconType == "svg" ? iconData : nil,
                    activeIconName: activeIconName,
                    activeIconType: activeIconType,
                    activeIconData: activeIconType == "svg" ? activeIconData : nil,
                    iconSize: iconSize,
                    activeIconSize: activeIconSize,
                    activeTextColor: activeTextColorValue != nil ? UIColor(hex: UInt32(activeTextColorValue!)) : nil,
                    inactiveTextColor: inactiveTextColorValue != nil ? UIColor(hex: UInt32(inactiveTextColorValue!)) : nil,
                    activeImageColor: activeImageColorValue != nil ? UIColor(hex: UInt32(activeImageColorValue!)) : nil,
                    inactiveImageColor: inactiveImageColorValue != nil ? UIColor(hex: UInt32(inactiveImageColorValue!)) : nil
                )
                tabBarItems.append(tabBarItem)
            }
            
            tabBar.items = tabBarItems
            
            // Restore selection if possible
            if let index = selectedIndex, index < tabBarItems.count {
                isUpdatingProgrammatically = true
                tabBar.selectedItem = tabBarItems[index]
                if #available(iOS 13.0, *) {
                    updateItemColors(selectedIndex: index)
                } else {
                    forceLayoutUpdate()
                }
                isUpdatingProgrammatically = false
            }
            
            // Force immediate UI update after recreating items
            forceLayoutUpdate()
            
            // Schedule additional update to ensure Arabic text renders correctly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.forceLayoutUpdate()
            }
            return
        }
        
        // Update existing items' properties only - don't reassign items array
        for (index, itemData) in itemsData.enumerated() {
            guard index < tabBarItems.count else { continue }
            
            let item = tabBarItems[index]
            let title = itemData["title"] as? String ?? ""
            let iconName = itemData["icon"] as? String ?? ""
            let assetImage = itemData["assetImage"] as? String
            let iconType = itemData["iconType"] as? String
            let iconData = itemData["icon"] as? String
            
            let activeIconName = itemData["activeIcon"] as? String
            let activeIconType = itemData["activeIconType"] as? String
            let activeIconData = itemData["activeIcon"] as? String
            
            // Update title
            originalTitles[index] = title
            item.title = isPadIconsOnlyLayout ? nil : title

            let activeTextColorValue = itemData["activeTextColor"] as? Int
            let inactiveTextColorValue = itemData["inactiveTextColor"] as? Int
            let activeImageColorValue = itemData["activeImageColor"] as? Int
            let inactiveImageColorValue = itemData["inactiveImageColor"] as? Int
            let iconSize = parseIconSize(itemData["iconSize"])
            let activeIconSize = parseIconSize(itemData["activeIconSize"])

            let newImage = loadImage(
                name: iconName,
                type: iconType,
                data: iconType == "svg" ? iconData : nil,
                assetImage: assetImage,
                size: iconSize
            )

            let newSelectedImage = loadImage(
                name: activeIconName,
                type: activeIconType,
                data: activeIconType == "svg" ? activeIconData : nil,
                assetImage: nil,
                size: activeIconSize ?? iconSize
            ) ?? newImage // Fallback to normal image if activeIcon not provided

            // Store original images for tinting
            if let newImage = newImage {
                originalImages[index] = newImage
            }
            if let newSelectedImage = newSelectedImage {
                originalSelectedImages[index] = newSelectedImage
            }

            // Update item colors
            if activeTextColorValue != nil || inactiveTextColorValue != nil || activeImageColorValue != nil || inactiveImageColorValue != nil {
                itemColors[index] = ItemColors(
                    activeTextColor: activeTextColorValue != nil ? UIColor(hex: UInt32(activeTextColorValue!)) : nil,
                    inactiveTextColor: inactiveTextColorValue != nil ? UIColor(hex: UInt32(inactiveTextColorValue!)) : nil,
                    activeImageColor: activeImageColorValue != nil ? UIColor(hex: UInt32(activeImageColorValue!)) : nil,
                    inactiveImageColor: inactiveImageColorValue != nil ? UIColor(hex: UInt32(inactiveImageColorValue!)) : nil
                )
            }
            
            // Update colors if this item has custom colors
            let colors = itemColors[index]
            let selectedIndex = tabBar.selectedItem.flatMap { tabBarItems.firstIndex(of: $0) } ?? -1
            let isSelected = index == selectedIndex
            
            // Update text color
            if let textColor = isSelected ? colors?.activeTextColor : colors?.inactiveTextColor {
                item.setTitleTextAttributes([.foregroundColor: textColor], for: isSelected ? .selected : .normal)
            } else {
                // Reset to default if no custom color
                item.setTitleTextAttributes([:], for: isSelected ? .selected : .normal)
            }
            
            // Update icon color - use withTintColor with sRGB color (from UIColor extension)
            if let iconColor = isSelected ? colors?.activeImageColor : colors?.inactiveImageColor {
                // Custom color: use withTintColor with sRGB color (from UIColor extension)
                // Use the appropriate original image (inactive or active)
                let originalImage = isSelected 
                    ? (originalSelectedImages[index] ?? originalImages[index])
                    : originalImages[index]
                
                if let originalImage = originalImage {
                    let tintedImage = originalImage.withTintColor(iconColor, renderingMode: .alwaysOriginal)
                    if isSelected {
                        item.selectedImage = tintedImage
                    } else {
                        item.image = tintedImage
                    }
                }
            } else {
                // No custom color: use template mode with tabBar tintColor
                // This lets UITabBar handle tinting automatically
                // Keep the original images with template rendering mode
                if let originalImage = originalImages[index] {
                    item.image = originalImage.withRenderingMode(.alwaysTemplate)
                }
                if let originalSelectedImage = originalSelectedImages[index] {
                    item.selectedImage = originalSelectedImage.withRenderingMode(.alwaysTemplate)
                } else if let originalImage = originalImages[index] {
                    // Fallback to normal image if no selected image
                    item.selectedImage = originalImage.withRenderingMode(.alwaysTemplate)
                }
            }
        }
        
        // DON'T reassign tabBar.items - it clears selectedItem!
        // tabBar.items = tabBarItems  // ❌ REMOVED
        
        // Force immediate UI update after modifying items
        forceLayoutUpdate()
        updateForSizeClass()
        
        // Schedule additional update to ensure Arabic text renders correctly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.forceLayoutUpdate()
            self?.updateForSizeClass()
        }
    }

}

// MARK: - UITabBarDelegate
extension NativeIOSBottomNavBarView: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, shouldSelect item: UITabBarItem) -> Bool {
        // This is called for ALL taps, including already selected items
        // We use it ONLY to notify Flutter when tapping the same item
        // We don't interfere with UITabBar's selection behavior
        
        guard !isUpdatingProgrammatically else { return true }
        
        guard let index = tabBarItems.firstIndex(of: item) else { return true }
        
        // If tapping the same item that's already selected, notify Flutter
        // didSelect won't be called in this case, so we notify here
        if tabBar.selectedItem == item {
            methodChannel.invokeMethod("onItemSelected", arguments: index, result: { _ in })
            // Still allow selection to ensure UI is updated
            return true
        }
        
        // For different items, ensure selection happens
        // UITabBar will handle the UI update automatically
        return true
    }
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        // Ignore delegate callbacks when updating programmatically
        guard !isUpdatingProgrammatically else { return }
        
        guard let index = tabBarItems.firstIndex(of: item) else { return }
        
        // UITabBar already selected the item and updated the UI
        // Update item colors for new selection
        if #available(iOS 13.0, *) {
            updateItemColors(selectedIndex: index)
        }
        
        // We just need to notify Flutter
        // Don't interfere with UITabBar's selection - it's already done
        
        // Channel is unique per view, so no need to pass viewId
        methodChannel.invokeMethod("onItemSelected", arguments: index, result: { _ in })
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hex: UInt32) {
        // Flutter Color.value is in ARGB format: 0xAARRGGBB
        let a = CGFloat((hex >> 24) & 0xFF) / 255.0
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        
        // CRITICAL: Force sRGB color space to prevent Display-P3 conversion
        // This ensures exact color matching with Flutter
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let components: [CGFloat] = [r, g, b, a > 0 ? a : 1.0]
        
        self.init(
            cgColor: CGColor(
                colorSpace: srgb,
                components: components
            )!
        )
    }
}
