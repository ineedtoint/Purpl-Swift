# Purpl Swift

[English](README.md) | 한국어 | [문서](https://purpl.sh/ko/docs) | [Swift API Reference](https://swift.purpl.sh/)

Purpl은 StoreKit 2 구매, 권한 확인, 복원과 SwiftUI 페이월을 제공하는 Swift 6 SDK입니다.

Purpl 관리 서비스를 사용하지 않아도 로컬 구성만으로 모든 핵심 기능을 사용할 수 있습니다. 관리 서비스를 연결하면 웹에서 구성한 카탈로그를 같은 페이월 UI에 표시하고, 서버에서 고객 권한을 확인할 수 있습니다. 실제 상품 정보, 가격과 구매 가능 여부는 항상 StoreKit을 기준으로 합니다.

## 요구 사항

- Swift 6.2+
- iOS 26+
- macOS 26+

## 설치

Xcode의 **Package Dependencies**에 다음 저장소 주소를 추가합니다.

```text
https://github.com/ineedtoint/Purpl-Swift.git
```

구매와 권한 관리만 필요하면 `Purpl`을, 기본 SwiftUI 페이월도 사용하면 `PurplUI`를 함께 연결합니다.

## 로컬 구성

앱 전체에서 사용하는 상품과 각 상품이 제공하는 권한을 `PurchaseConfiguration`에 등록합니다. 판매가 종료된 과거 상품도 기존 구매자의 권한 확인과 복원을 위해 이 구성에는 유지합니다.

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

페이월에서 판매할 상품과 표시 순서는 별도의 `PurchaseCatalog`로 정의합니다. 과거 상품을 이 카탈로그에서 제외하면 기존 권한은 인정하면서 새 판매 화면에는 표시하지 않을 수 있습니다.

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

현재 고객의 권한은 `CustomerInfo`에서 확인합니다.

```swift
let customerInfo = try await Purchases.shared.customerInfo()
let hasPlusAccess = customerInfo.isEntitlementActive("plus")
```

## Purpl 관리 구성

Purpl 관리 서비스에서 고객 권한과 페이월 카탈로그를 관리하려면 서버 모드로 구성하고 웹에서 정의한 페이월 식별자를 전달합니다.

```swift
import Purpl
import PurplUI
import SwiftUI

Purchases.configure(entitlementMode: .server)

PaywallView(paywallIdentifier: "standard") {
    Text("Flow+")
}
```

원격 페이월 구성은 앱의 Bundle ID와 페이월 식별자로 조회합니다. 실제 상품 조회와 구매는 원격 구성에서도 StoreKit이 처리합니다.

첫 원격 응답 전이나 네트워크 장애 중에도 페이월을 제공하려면 앱의 로컬 구매 구성과 페이월 폴백을 함께 전달합니다. 캐시된 원격 구성이 있으면 이를 가장 먼저 사용하고, 캐시가 없으면 로컬 폴백을 즉시 표시한 뒤 원격 조회에 성공하면 화면을 원격 구성으로 교체합니다.

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

페이월 폴백은 표시 구성에만 적용됩니다. 서버 실패 시 고객 권한도 StoreKit으로 확인하려면 권한 확인 방식을 `serverWithStoreKitFallback`으로 구성하세요.

## API 레퍼런스

[Purpl Swift API Reference](https://swift.purpl.sh/)에서 온라인 문서를 확인할 수 있습니다. Purpl과 PurplUI에는 DocC 카탈로그가 포함되어 있으므로 Xcode에서 **Product > Build Documentation**을 선택해 SDK 소스에서 생성한 전체 API, 지원 플랫폼과 Deprecated 안내를 볼 수도 있습니다.

## 표시 영역의 책임

`PaywallView`는 상품 표시와 구매 동작을 담당합니다. `NavigationStack`, 탭, 툴바와 닫기 버튼은 여러 페이월을 한 화면에 배치할 수 있도록 앱이 직접 구성합니다.

## 라이선스

Purpl Swift는 MIT 라이선스로 제공됩니다. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
