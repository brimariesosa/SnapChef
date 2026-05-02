//
//  DemoLibrary.swift
//  SnapChef
//
//  In-app demo photos that map directly to recipes in `sampleRecipes`.
//  Two ways to use them:
//    1. The Snap screen's built-in "Demo Library" picker
//    2. A one-tap "Seed Demo Photos" action that writes the rendered
//       images into the device/simulator Photos app, so you can pick
//       them through the regular photo library during a demo.
//

import SwiftUI
import Photos
import UIKit

struct DemoRecipePhoto: Identifiable, Hashable {
    let id = UUID()
    let recipeTitle: String
    let symbol: String
    let gradient: [Color]
}

enum DemoLibrary {
    static let photos: [DemoRecipePhoto] = [
        DemoRecipePhoto(
            recipeTitle: "Garlic Herb Chicken",
            symbol: "fork.knife.circle.fill",
            gradient: [Color(red: 0.85, green: 0.45, blue: 0.30),
                       Color(red: 0.55, green: 0.20, blue: 0.10)]
        ),
        DemoRecipePhoto(
            recipeTitle: "Spinach Tomato Omelette",
            symbol: "circle.circle.fill",
            gradient: [Color(red: 0.95, green: 0.75, blue: 0.30),
                       Color(red: 0.45, green: 0.65, blue: 0.30)]
        ),
        DemoRecipePhoto(
            recipeTitle: "Roasted Veggie Bowl",
            symbol: "leaf.circle.fill",
            gradient: [Color(red: 0.60, green: 0.80, blue: 0.40),
                       Color(red: 0.20, green: 0.45, blue: 0.20)]
        ),
        DemoRecipePhoto(
            recipeTitle: "Quick Garlic Fried Rice",
            symbol: "bowl.fill",
            gradient: [Color(red: 0.95, green: 0.85, blue: 0.55),
                       Color(red: 0.70, green: 0.45, blue: 0.20)]
        ),
        DemoRecipePhoto(
            recipeTitle: "Slow Cooker Chicken Stew",
            symbol: "flame.circle.fill",
            gradient: [Color(red: 0.75, green: 0.40, blue: 0.25),
                       Color(red: 0.35, green: 0.15, blue: 0.10)]
        ),
        DemoRecipePhoto(
            recipeTitle: "Cheesy Veggie Melt",
            symbol: "square.stack.fill",
            gradient: [Color(red: 0.95, green: 0.80, blue: 0.40),
                       Color(red: 0.80, green: 0.45, blue: 0.25)]
        ),
        DemoRecipePhoto(
            recipeTitle: "Simple Green Smoothie",
            symbol: "cup.and.saucer.fill",
            gradient: [Color(red: 0.55, green: 0.85, blue: 0.55),
                       Color(red: 0.20, green: 0.50, blue: 0.30)]
        ),
        DemoRecipePhoto(
            recipeTitle: "Air Fryer Chicken Tenders",
            symbol: "flame.fill",
            gradient: [Color(red: 0.95, green: 0.65, blue: 0.30),
                       Color(red: 0.65, green: 0.30, blue: 0.15)]
        )
    ]

    static func recipe(for photo: DemoRecipePhoto) -> Recipe? {
        sampleRecipes.first { $0.title == photo.recipeTitle }
    }

    static func render(_ photo: DemoRecipePhoto,
                       size: CGSize = CGSize(width: 1024, height: 1024)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgctx = ctx.cgContext
            let cgColors = photo.gradient.map { UIColor($0).cgColor }
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(
                colorsSpace: space,
                colors: cgColors as CFArray,
                locations: [0, 1]
            ) {
                cgctx.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            let symbolConfig = UIImage.SymbolConfiguration(
                pointSize: size.width * 0.42,
                weight: .light
            )
            if let symbol = UIImage(systemName: photo.symbol,
                                    withConfiguration: symbolConfig)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let s = symbol.size
                let origin = CGPoint(
                    x: (size.width - s.width) / 2,
                    y: (size.height - s.height) / 2 - size.height * 0.05
                )
                symbol.draw(at: origin, blendMode: .normal, alpha: 0.95)
            }

            let title = photo.recipeTitle as NSString
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width * 0.06, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
            let textRect = CGRect(
                x: 0,
                y: size.height * 0.80,
                width: size.width,
                height: size.height * 0.12
            )
            title.draw(in: textRect, withAttributes: attrs)
        }
    }

    enum SeedError: LocalizedError {
        case notAuthorized
        case unknown

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Photo library access was denied. Enable it in Settings to seed demo photos."
            case .unknown:
                return "Something went wrong while saving the demo photos."
            }
        }
    }

    static func seedToPhotoLibrary(completion: @escaping (Result<Int, Error>) -> Void) {
        let items = DemoLibrary.photos
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(.failure(SeedError.notAuthorized)) }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                for photo in items {
                    let image = DemoLibrary.render(photo)
                    PHAssetCreationRequest.creationRequestForAsset(from: image)
                }
            } completionHandler: { ok, err in
                DispatchQueue.main.async {
                    if let err = err {
                        completion(.failure(err))
                    } else if ok {
                        completion(.success(items.count))
                    } else {
                        completion(.failure(SeedError.unknown))
                    }
                }
            }
        }
    }
}
