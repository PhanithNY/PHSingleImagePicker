//
//  ImagePickerCompressor.swift
//  
//
//  Created by Phanith on 21/10/21.
//

import MobileCoreServices
import PhotosUI

typealias PHSingleImagePickerCompressionResult = (data: Data, name: String)

public struct ImagePickerCompressor {
    
  typealias CompressionResult = (PHSingleImagePickerCompressionResult?) -> Void
  
  static func downsamplingImage(at url: URL, to maxSize: Int = 2_000, then: CompressionResult?) {
    
    // Create the CGImage from url,
    // @see https://developer.apple.com/videos/play/wwdc2018/219
    let sourceOptions: CFDictionary = [kCGImageSourceShouldCache: false] as CFDictionary
    
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
      then?(nil)
      return
    }
    
    let downsampleOptions: CFDictionary = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxSize
      ] as CFDictionary
    
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
      then?(nil)
      return
    }
    
    // Convert CGImage we've just created into data
    let data = NSMutableData()
    guard let imageDestination = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else {
      then?(nil)
      return
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
    // Check solution in WingImagePickerManager.swift
    then?((data: data as Data, name: url.lastPathComponent.filename))
  }
}

extension String {
  var filename: String {
    if let range: Range<String.Index> = self.range(of: ".") {
      let index: Int = self.distance(from: self.startIndex, to: range.lowerBound)
      return String(self.prefix(index))
    } else {
      return UUID().uuidString
    }
  }
}
