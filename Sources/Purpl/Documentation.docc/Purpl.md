# ``Purpl``

Build StoreKit purchases, customer entitlement checks, restoration, and Purpl service integration with one consistent API.

## Overview

Use Purpl with only a ``PurchaseConfiguration`` defined in your app. Connect the Purpl service to keep the same purchase API while adding server-managed entitlements and remote paywall configuration.

StoreKit always remains authoritative for product information, pricing, and purchase availability.

## Topics

### Purchase Configuration

- ``Purchases``
- ``PurchaseConfiguration``
- ``PurchaseProduct``
- ``PurchaseEntitlement``
- ``PurchaseCatalog``
- ``EntitlementMode``

### Products and Purchases

- ``PurchaseResult``
- ``PurchasesError``

### Customer Entitlements

- ``CustomerInfo``
- ``CustomerEntitlement``
- ``CustomerEntitlementStatus``
- ``CustomerInfoSource``
- ``CustomerInfoTaskState``

### Remote Paywall Configuration

- ``ResolvedPaywallConfiguration``
- ``ResolvedPaywallProductContent``
