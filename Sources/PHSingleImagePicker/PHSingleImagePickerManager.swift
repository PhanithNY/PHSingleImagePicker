//
//  PHSingleImagePickerManager.swift
//  
//
//  Created by Phanith on 21/10/21.
//

import UIKit
import PhotosUI
import Photos

public final class PHSingleImagePickerManager: NSObject {
  
  public typealias WingImagePickerResult = (data: Data, name: String)
  public typealias Handler = (Result<WingImagePickerResult, PHSingleImagePickerManagerError>) -> Void
  
  // MARK: - Public properties
  
  public static let shared = PHSingleImagePickerManager()
  public var preferredMaxSize: Int = 2_000
  
  // MARK: - Properties
  
  private var pickImageCallback: Handler?
  private var imagePickerController: UIImagePickerController!
  private var phPickerViewController: UIViewController!
  
  // MARK: - Init
  
  private override init() {
    super.init()
    
    imagePickerController = UIImagePickerController()
    imagePickerController.delegate = self
    
    if #available(iOS 14, *) {
      var config = PHPickerConfiguration()
      config.selectionLimit = 1
      config.filter = .images
      config.preferredAssetRepresentationMode = .current
      
      phPickerViewController = PHPickerViewController(configuration: config)
      (phPickerViewController as? PHPickerViewController)?.delegate = self
    }
  }
  
  // MARK: - Actions
  
  public final func show(_ type: SourceType, on viewController: UIViewController, _ then: Handler?) {
    switch type {
    case .photoLibrary:
      openGallery(viewController) { result in
        then?(result)
      }
      
    case .camera:
      openCamera(viewController) { result in
        then?(result)
      }
    }
  }
  
  private func openCamera(_ viewController: UIViewController, _ callback: @escaping (Handler)) {
    pickImageCallback = callback
    
    CamearaPermissionManager.shared.requestAuthorization { [unowned self] status in
      DispatchQueue.main.async {
        switch status {
        case .authorized:
          guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            callback(.failure(.noCamera))
            return
          }
          
          self.imagePickerController.sourceType = .camera
          viewController.present(self.imagePickerController, animated: true)
          
        default:
          callback(.failure(.noCameraPermission))
        }
      }
    }
  }
  
  private func openGallery(_ viewController: UIViewController, _ callback: @escaping (Handler)) {
    pickImageCallback = callback
    
    // MARK: - From iOS 14 picker image need to use new apple framework
    if #available(iOS 14.0, *) {
      viewController.present(phPickerViewController, animated: true, completion: nil)
    } else {
      CamearaPermissionManager.shared.requestPhotoAuthorization { [unowned self] status in
        DispatchQueue.main.async {
          switch status {
          case .authorized:
            self.imagePickerController.sourceType = .photoLibrary
            viewController.present(self.imagePickerController, animated: true, completion: nil)
            
          default:
            callback(.failure(.noPhotoLibraryPermission))
          }
        }
      }
    }
  }
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate

extension PHSingleImagePickerManager: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }
  
  public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    picker.dismiss(animated: true, completion: nil)
    
    if #available(iOS 11.0, *), let url = info[.imageURL] as? URL {
        ImagePickerCompressor.downsamplingImage(at: url, to: preferredMaxSize) { [unowned self] _result in
          if let result = _result {
            let filename: String
            if let asset = info[.phAsset] as? PHAsset,
               let _filename = PHAssetResource.assetResources(for: asset).first?.originalFilename.filename {
              filename = _filename
            } else {
              filename = result.name
            }
            self.pickImageCallback?(.success((data: result.data, name: filename)))
          } else {
            self.pickImageCallback?(.failure(.downsamplingFailure))
          }
        }
      return
    }
    
    if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.75) {
      pickImageCallback?(.success((data: data, name: UUID().uuidString)))
    } else {
      pickImageCallback?(.failure(.unknown))
    }
  }
}

@available(iOS 14, *)
extension PHSingleImagePickerManager: PHPickerViewControllerDelegate {
  public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    let preferredMaxSize = self.preferredMaxSize
    picker.dismiss(animated: true) {
      PHPickerResultCompressor.downsampling(results, to: preferredMaxSize) { [unowned self] results in
        if let result = results.first as? WingImagePickerResult {
          self.pickImageCallback?(.success((data: result.data, name: result.name)))
        } else {
          self.pickImageCallback?(.failure(.downsamplingFailure))
        }
      }
    }
  }
}

@objc public enum SourceType: Int {
  case photoLibrary
  case camera
}

public extension Data {
  var sizeInMB: Double { Double(self.count) / (1024 * 1024) }
}
