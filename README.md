# Purpl Swift

English | [한국어](README.ko.md) | [Documentation](https://purpl.sh/en/documentation)

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

Remote paywall configuration is resolved using the app's bundle identifier and the paywall identifier. StoreKit still handles product loading and purchases.

## Presentation ownership

`PaywallView` owns product presentation and purchase actions. Your app owns `NavigationStack`, tabs, toolbars, and close buttons so it can compose multiple paywalls within the same screen.

## License

Purpl Swift is available under the MIT license. See [LICENSE](LICENSE) for details.
