# Purpl Example

This example uses Xcode StoreKit Configuration and local Purpl configuration. It doesn't require an Apple Developer account, App Store Connect products, a Purpl account, or a server.

## Run the example

1. Clone the `Purpl-Swift` repository.
2. Open `Examples/PurplExample/PurplExample.xcodeproj` in Xcode.
3. Select the `PurplExample` scheme and an iOS Simulator.
4. Run the app and purchase a monthly, yearly, or lifetime product.
5. Use the paywall restore action to test purchase restoration.

The shared scheme already selects `PurplExample.storekit`. Open **Debug > StoreKit > Manage Transactions** in Xcode to expire, refund, or remove test transactions.

The Xcode project references the package at the repository root, so changes to the local SDK source are reflected immediately.
