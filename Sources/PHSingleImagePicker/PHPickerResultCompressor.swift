//
//  File.swift
//  
//
//  Created by Phanith on 21/10/21.
//

import MobileCoreServices
import PhotosUI

@available(iOS 14.0, *)
struct PHPickerResultCompressor {
  
  typealias CompressionResult = ([PHSingleImagePickerCompressionResult?]) -> Void
  
  static func downsampling(_ results: [PHPickerResult], to maxSize: Int = 2_000, then: CompressionResult?) {
    
    // loadFileRepresentation fires on an async queue,
    // So, create a queue to ensure we’re not writing to this array of Data across multiple threads
    let dispatchQueue = DispatchQueue(label: "com.phanith.expense.PHPickerQueue")
    
    // Array itself is set up in a way that we can maintain the order of the images, otherwise the photos in and the order they're processed may not be aligned 1:1
    var selectedImageDatas = [PHSingleImagePickerCompressionResult?](repeating: nil, count: results.count)
    
    // Track if conversion is completed
    var totalConversionsCompleted = 0

    for (index, result) in results.enumerated() {
      result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { (url, error) in
        guard let url = url else {
          dispatchQueue.sync { totalConversionsCompleted += 1 }
          return
        }
        
        // Create the CGImage from url,
        // @see https://developer.apple.com/videos/play/wwdc2018/219
        let sourceOptions: CFDictionary = [kCGImageSourceShouldCache: false] as CFDictionary
        
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
          dispatchQueue.sync { totalConversionsCompleted += 1 }
          return
        }
        
        let downsampleOptions: CFDictionary = [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: maxSize
          ] as CFDictionary
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
          dispatchQueue.sync { totalConversionsCompleted += 1 }
          return
        }
        
        // Convert CGImage we've just created into data
        let data = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else {
          dispatchQueue.sync { totalConversionsCompleted += 1 }
          return
        }
        
        // Don't compress PNGs, they're too pretty
        let isPNG: Bool = {
          guard let utType = cgImage.utType else { return false }
          return (utType as String) == UTType.png.identifier
        }()
        
        let destinationProperties: CFDictionary = [kCGImageDestinationLossyCompressionQuality: isPNG ? 1.0 : 0.75] as CFDictionary
        CGImageDestinationAddImage(imageDestination, cgImage, destinationProperties)
        CGImageDestinationFinalize(imageDestination)
        
        dispatchQueue.sync {
          selectedImageDatas[index] = (data: data as Data, name: url.lastPathComponent.filename)
          totalConversionsCompleted += 1
        }
        
        // Trigger callback if finished all conversion
        if totalConversionsCompleted == results.count {
          then?(selectedImageDatas)
        }
      }
    }
  }
}
