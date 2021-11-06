//
//  File.swift
//  
//
//  Created by Phanith on 21/10/21.
//

import Foundation

public enum PHSingleImagePickerManagerError: LocalizedError {
  case downsamplingFailure
  case noCamera
  case noCameraPermission
  case noPhotoLibraryPermission
  case unknown
  
  public var errorDescription: String? {
    switch self {
    case .downsamplingFailure:
      return "ImagePickerManagerError: Could not downsampling. This should be never happen!"
    case .noCamera:
      return "ImagePickerManagerError: No camera or camera malfunction."
    case .noCameraPermission:
      return "ImagePickerManagerError: No camera permission."
    case .noPhotoLibraryPermission:
      return "ImagePickerManagerError: No photo library permission."
    case .unknown:
      return "ImagePickerManagerError: Unknown."
    }
  }
}
