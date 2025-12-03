//
//  ImageCropView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/25/25.
//
//  Simple image cropping view for profile pictures (square crop).
//

import SwiftUI

struct ImageCropView: View {
    let image: UIImage
    @Binding var croppedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    private let cropSize: CGFloat = 300
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                GeometryReader { geometry in
                    ZStack {
                        // Dark overlay with transparent crop circle
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.7))
                            Circle()
                                .fill(Color.clear)
                                .frame(width: cropSize, height: cropSize)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                        
                        // Image that can be zoomed and panned
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = min(max(scale * delta, 1.0), 4.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )
                        
                        // Crop circle border
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: cropSize, height: cropSize)
                        
                        // Instruction text
                        VStack {
                            Spacer()
                            Text("Pinch to zoom, drag to move")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                                .padding(.bottom, 50)
                        }
                    }
                }
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        performCrop()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func performCrop() {
        // Simple center crop of the image
        let size = min(image.size.width, image.size.height)
        let x = (image.size.width - size) / 2
        let y = (image.size.height - size) / 2
        
        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            croppedImage = image
            dismiss()
            return
        }
        
        let cropped = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        croppedImage = cropped
        dismiss()
    }
}
