//
//  ImagePickerCompressor.swift
//  
//
//  Created by Phanith on 21/10/21.
//

import MobileCoreServices
import PhotosUI

public typealias PHSingleImagePickerCompressionResult = (data: Data, name: String)

public struct ImagePickerCompressor {
  
  public typealias CompressionResult = (data: Data, name: String)
  
  public static func downsamplingImage(at url: URL, to maxSize: Int = 2_000) -> CompressionResult? {
    
    // Create the CGImage from url,
    // @see https://developer.apple.com/videos/play/wwdc2018/219
    let sourceOptions: CFDictionary = [kCGImageSourceShouldCache: false] as CFDictionary
    
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
      return nil
    }
    
    let downsampleOptions: CFDictionary = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxSize
    ] as CFDictionary
    
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
      return nil
    }
    
    // Convert CGImage we've just created into data
    let data = NSMutableData()
    guard let imageDestination = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else {
      return nil
    }
    
    // Don't compress PNGs, they're too pretty
    let isPNG: Bool = {
      guard let utType = cgImage.utType else { return false }
      return (utType as String).lowercased().contains("png")
    }()
    
    let destinationProperties: CFDictionary = [kCGImageDestinationLossyCompressionQuality: isPNG ? 1.0 : 0.75] as CFDictionary
    CGImageDestinationAddImage(imageDestination, cgImage, destinationProperties)
    CGImageDestinationFinalize(imageDestination)
    
    // This will return the filename from tmp directory, which is not the original filename
    return (data: data as Data, name: url.lastPathComponent.filename)
  }
}

extension String {
  public var filename: String {
    if let range: Range<String.Index> = self.range(of: ".") {
      let index: Int = self.distance(from: self.startIndex, to: range.lowerBound)
      return String(self.prefix(index))
    } else {
      return UUID().uuidString
    }
  }
}
