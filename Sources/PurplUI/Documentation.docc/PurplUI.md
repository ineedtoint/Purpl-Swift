# ``PurplUI``

로컬 구성과 Purpl 원격 구성이 함께 사용할 수 있는 SwiftUI 페이월을 제공합니다.

## Overview

``PaywallView``는 상품 표시, 선택, 구매와 복원 흐름을 소유합니다. 앱은 페이월을 담는 `NavigationStack`, 탭, 툴바와 닫기 버튼을 구성합니다.

원격 페이월에 ``PaywallView/init(paywallIdentifier:fallbackConfiguration:style:appAccountToken:purchaseResultAction:purchaseFailureAction:marketingContent:)``을 사용하면 캐시와 서버 구성을 사용할 수 없을 때 앱의 로컬 ``PaywallConfiguration``을 표시할 수 있습니다.

## Topics

### 페이월 표시

- ``PaywallView``
- ``PaywallConfiguration``
- ``PaywallStyle``
- ``DefaultPaywallProductCard``

### 페이월 상태와 상품 콘텐츠

- ``PaywallModel``
- ``PaywallProductContext``
- ``PaywallProductDisplayContent``
- ``PaywallProductAvailability``
- ``PaywallPurchaseResolutionState``
- ``PaywallCustomerInfoState``
- ``PaywallRestoreNotice``
