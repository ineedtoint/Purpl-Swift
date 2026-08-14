# Purpl Swift

English | [한국어](README.ko.md) | [Docs](https://purpl.sh/en/docs) | [Swift API Reference](https://swift.purpl.sh/)

Purpl is a Swift 6 SDK for StoreKit 2 purchases, entitlement checks, restoration, and SwiftUI paywalls.

You can use every core feature with local configuration, without adopting the Purpl management service. When you connect the service, the same paywall UI can present catalogs configured on the web and customer entitlements can be verified on the server. StoreKit always remains the source of truth for product information, pricing, and purchase availability.

## Requirements

- Swift 6.2+
- iOS 26+
- macOS 26+

## Installation

Add the following repository URL in Xcode under **Package Dependencies**.

```text
https://github.com/ineedtoint/Purpl-Swift.git
```

Link `Purpl` when you only need purchases and entitlement management. Add `PurplUI` when you also want the default SwiftUI paywall.

## Local configuration

Register every product used by your app and the entitlements granted by each product in `PurchaseConfiguration`. Keep discontinued products in this configuration so existing purchases can still be restored and recognized.

```swift
import Purpl

let plusEntitlement = PurchaseEntitlement(identifier: "plus")

let monthlyProduct = PurchaseProduct(
    productIdentifier: "time.plus.monthly",
    entitlementIdentifier: plusEntitlement.identifier
)
let yearlyProduct = PurchaseProduct(
    productIdentifier: "time.plus.yearly",
    entitlementIdentifier: plusEntitlement.identifier
)
let legacyLifetimeProduct = PurchaseProduct(
    productIdentifier: "time.plus.lifetime.legacy",
    entitlementIdentifier: plusEntitlement.identifier
)

let purchaseConfiguration = PurchaseConfiguration(
    entitlements: [plusEntitlement],
    products: [
        monthlyProduct,
        yearlyProduct,
        legacyLifetimeProduct
    ]
)

Purchases.configure(purchaseConfiguration)
```

Define the products shown on a paywall and their display order in a separate `PurchaseCatalog`. Removing a discontinued product from the catalog keeps existing access valid while excluding the product from new sales.

```swift
import Purpl
import PurplUI
import SwiftUI

let standardCatalog = PurchaseCatalog(
    identifier: "standard",
    products: [monthlyProduct, yearlyProduct]
)

PaywallView(
    configuration: PaywallConfiguration(
        catalog: standardCatalog,
        defaultProductIdentifier: yearlyProduct.productIdentifier
    )
) {
    Text("Flow+")
}
```

Read the current customer's entitlements from `CustomerInfo`.

```swift
let customerInfo = try await Purchases.shared.customerInfo()
let hasPlusAccess = customerInfo.isEntitlementActive("plus")
```

## Purpl managed configuration

To manage customer entitlements and paywall catalogs with the Purpl service, configure server mode and pass the paywall identifier defined on the web.

```swift
import Purpl
import PurplUI
import SwiftUI

Purchases.configure(entitlementMode: .server)

PaywallView(paywallIdentifier: "standard") {
    Text("Flow+")
}
```

Remote paywall configuration is resolved using the app's bundle identifier, paywall identifier, and current locale. Purpl supplies localized product content, renewal notices, and policy links, while StoreKit still handles product loading, pricing, availability, and purchases.

To keep a paywall available before the first remote response or during a network failure, provide the app's local purchase configuration and paywall fallback. A cached remote configuration remains the first choice. When no cache exists, the fallback is presented immediately and replaced after a successful remote refresh.

```swift
Purchases.configure(
    purchaseConfiguration,
    entitlementMode: .server
)

PaywallView(
    paywallIdentifier: "standard",
    fallbackConfiguration: PaywallConfiguration(
        catalog: standardCatalog,
        defaultProductIdentifier: yearlyProduct.productIdentifier
    )
) {
    Text("Flow+")
}
```

The paywall fallback only controls presentation. Use `serverWithStoreKitFallback` as the entitlement mode when entitlement checks should also fall back to StoreKit after a server failure.

## API reference

Browse the [Purpl Swift API Reference](https://swift.purpl.sh/) online. Purpl and PurplUI include DocC catalogs, so you can also choose **Product > Build Documentation** in Xcode to browse the complete API reference, platform availability, and deprecation guidance generated from the SDK source.

## Presentation ownership

`PaywallView` owns product presentation and purchase actions. Your app owns `NavigationStack`, tabs, toolbars, and close buttons so it can compose multiple paywalls within the same screen.

## License

Purpl Swift is available under the MIT license. See [LICENSE](LICENSE) for details.
