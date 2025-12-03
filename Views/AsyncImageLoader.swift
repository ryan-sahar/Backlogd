//
//  AsyncImageLoader.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/25/25.
//
//  Helper view for loading images asynchronously from URLs.
//

import SwiftUI
import UIKit

/// Loads an image from a URL asynchronously with a placeholder.
struct AsyncImageLoader: View {
    let urlString: String?
    let placeholder: Image
    
    @State private var loadedImage: UIImage?
    
    init(urlString: String?, placeholder: Image = Image(systemName: "person.fill")) {
        self.urlString = urlString
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder
                    .resizable()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: urlString) { oldValue, newValue in
            if oldValue != newValue {
                loadedImage = nil
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            print("⚠️ AsyncImageLoader: Invalid URL string: \(urlString ?? "nil")")
            return
        }
        
        print("🖼️ AsyncImageLoader: Loading image from: \(urlString)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ AsyncImageLoader: Failed to load image - \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("❌ AsyncImageLoader: No data received")
                return
            }
            
            guard let image = UIImage(data: data) else {
                print("❌ AsyncImageLoader: Invalid image data")
                return
            }
            
            print("✅ AsyncImageLoader: Image loaded successfully")
            DispatchQueue.main.async {
                loadedImage = image
            }
        }.resume()
    }
}

