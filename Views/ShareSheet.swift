//
//  ShareSheet.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  UIKit wrapper for sharing content via the system share sheet.
//  Uses UIActivityViewController wrapped in UIViewControllerRepresentable.
//

import SwiftUI
import UIKit

/// A SwiftUI wrapper for UIActivityViewController (UIKit share sheet).
///
/// This allows sharing content from SwiftUI views using the native iOS share sheet.
/// The completion handler provides feedback back to SwiftUI when sharing completes.
struct ShareSheet: UIViewControllerRepresentable {
    
    /// Items to share (can be strings, URLs, images, etc.)
    let items: [Any]
    
    /// Called when the share sheet is dismissed.
    /// Parameter indicates if the user actually shared something.
    var completion: ((Bool) -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Set completion handler to communicate back to SwiftUI
        controller.completionWithItemsHandler = { _, completed, _, _ in
            completion?(completed)
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

