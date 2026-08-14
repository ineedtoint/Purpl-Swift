# ``Purpl``

StoreKit 구매, 고객 권한 확인, 복원과 Purpl 서비스 연결을 하나의 일관된 API로 구성합니다.

## Overview

Purpl은 앱에서 직접 정의한 ``PurchaseConfiguration``만으로 사용할 수 있습니다. Purpl 서비스를 연결하면 같은 구매 API를 유지하면서 서버 권한과 원격 페이월 구성을 사용할 수 있습니다.

상품 정보, 가격과 실제 구매 가능 여부는 항상 StoreKit을 기준으로 판단합니다.

## Topics

### 구매 구성

- ``Purchases``
- ``PurchaseConfiguration``
- ``PurchaseProduct``
- ``PurchaseEntitlement``
- ``PurchaseCatalog``
- ``EntitlementMode``

### 상품과 구매

- ``PurchaseResult``
- ``PurchasesError``

### 고객 권한

- ``CustomerInfo``
- ``CustomerEntitlement``
- ``CustomerEntitlementStatus``
- ``CustomerInfoSource``
- ``CustomerInfoTaskState``

### 원격 페이월 구성

- ``ResolvedPaywallConfiguration``
- ``ResolvedPaywallProductContent``
