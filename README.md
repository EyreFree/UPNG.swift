# UPNG.swift

[![CI Status](https://img.shields.io/travis/eyrefree/UPNG.swift.svg?style=flat)](https://travis-ci.org/eyrefree/UPNG.swift)
[![Version](https://img.shields.io/cocoapods/v/UPNG.swift.svg?style=flat)](https://cocoapods.org/pods/UPNG.swift)
[![License](https://img.shields.io/cocoapods/l/UPNG.swift.svg?style=flat)](https://cocoapods.org/pods/UPNG.swift)
[![Platform](https://img.shields.io/cocoapods/p/UPNG.swift.svg?style=flat)](https://cocoapods.org/pods/UPNG.swift)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

UPNG.swift is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'UPNG.swift'
```

## Usage

```swift
UPNG.shared.optimize(imageData: pngImageData) { [weak self] data, error in
    guard let self = self else { return }
    
    if let data = data {
        printLog("UPNG.shared.optimize success")
        
        // todo with new png data
    } else {
        printLog("UPNG.shared.optimize error: \(error?.localizedDescription ?? "")")
    }
}
```

## Author

EyreFree, eyrefree@eyrefree.org

## License

UPNG.swift is available under the MIT license. See the LICENSE file for more info.
