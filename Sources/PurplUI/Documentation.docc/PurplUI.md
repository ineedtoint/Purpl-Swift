# ``PurplUI``

Present SwiftUI paywalls that work with both local configuration and remote Purpl configuration.

## Overview

``PaywallView`` owns product presentation, selection, purchases, and restoration. Your app owns the surrounding `NavigationStack`, tabs, toolbar, and close button.

Use ``PaywallView/init(paywallIdentifier:fallbackConfiguration:style:appAccountToken:purchaseResultAction:purchaseFailureAction:marketingContent:)`` to provide a local ``PaywallConfiguration`` when neither the remote cache nor server configuration is available.

## Topics

### Paywall Presentation

- ``PaywallView``
- ``PaywallConfiguration``
- ``PaywallStyle``
- ``DefaultPaywallProductCard``

### Paywall State and Product Content

- ``PaywallModel``
- ``PaywallProductContext``
- ``PaywallProductDisplayContent``
- ``PaywallProductAvailability``
- ``PaywallPurchaseResolutionState``
- ``PaywallCustomerInfoState``
- ``PaywallRestoreNotice``
