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
  public typealias Handler = (Result<[WingImagePickerResult], PHSingleImagePickerManagerError>) -> Void
  
  // MARK: - Public properties
  
  public static let shared = PHSingleImagePickerManager()
  public var onDownsampling: (() -> Void)?
  public var onFinishDownsampling: (() -> Void)?
  public var onCancel: (() -> Void)?
  
  public var preferredMaxSize: Int = 2_000 {
    didSet {
      initPHPickerController()
    }
  }
  
  public var selectionLimit: Int = 1 {
    didSet {
      initPHPickerController()
    }
  }
  
  // MARK: - Properties
  
  private var pickImageCallback: Handler?
  private var imagePickerController: UIImagePickerController!
  private var phPickerViewController: UIViewController!
  
  // MARK: - Init
  
  private override init() {
    super.init()
    
    imagePickerController = UIImagePickerController()
    imagePickerController.delegate = self
    initPHPickerController()
  }
  
  private func initPHPickerController() {
    if #available(iOS 14, *) {
      var config = PHPickerConfiguration()
      config.selectionLimit = selectionLimit
      config.filter = .images
      config.preferredAssetRepresentationMode = .current
      if #available(iOS 15.0, *) {
        config.selection = .ordered
      }
      
      phPickerViewController = PHPickerViewController(configuration: config)
      phPickerViewController.isModalInPresentation = true
      
      if UIDevice.current.userInterfaceIdiom == .phone {
        phPickerViewController.modalPresentationStyle = .fullScreen
      }
      
      (phPickerViewController as? PHPickerViewController)?.delegate = self
    }
  }
  
  // MARK: - Actions
  
  public final func show(_ type: SourceType,
                         on viewController: UIViewController,
                         _ then: Handler?) {
    switch type {
    case .photoLibrary:
      openGallery(viewController) { result in
        then?(result)
      }
      
    case .camera:
      openCamera(viewController) { result in
        then?(result)
      }
      
    case .fronCamera:
      openCamera(viewController, camera: .front) { result in
        then?(result)
      }
      
    case .video:
      break
    }
  }
  
  private func openCamera(_ viewController: UIViewController,
                          camera: UIImagePickerController.CameraDevice? = nil,
                          _ callback: @escaping (Handler)) {
    pickImageCallback = callback
    
    CameraPermissionManager.shared.requestAuthorization { [unowned self] status in
      DispatchQueue.main.async {
        switch status {
        case .authorized:
          guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            callback(.failure(.noCamera))
            return
          }
          
          self.imagePickerController.sourceType = .camera
          if let camera = camera, UIImagePickerController.isCameraDeviceAvailable(camera) {
            self.imagePickerController.cameraDevice = camera
          }
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
      CameraPermissionManager.shared.requestPhotoAuthorization { [unowned self] status in
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
    onCancel?()
  }
  
  public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    picker.dismiss(animated: true, completion: nil)
    
    if #available(iOS 11.0, *), let url = info[.imageURL] as? URL {
      if let result = ImagePickerCompressor.downsamplingImage(at: url, to: preferredMaxSize) {
        DispatchQueue.main.async {
          let filename: String
          if let asset = info[.phAsset] as? PHAsset,
             let _filename = PHAssetResource.assetResources(for: asset).first?.originalFilename.filename {
            filename = _filename
          } else {
            filename = result.name
          }
          
          if let image = UIImage(data: result.data),
             let data = image.fixOrientation().jpegData(compressionQuality: 1.0) {
            self.pickImageCallback?(.success([(data: data, name: filename)]))
          } else {
            self.pickImageCallback?(.success([(data: result.data, name: filename)]))
          }
        }
      } else {
        DispatchQueue.main.async {
          self.pickImageCallback?(.failure(.downsamplingFailure))
        }
      }
      return
    }
    
    if let image = info[.originalImage] as? UIImage {
      let scaleFactor: CGFloat = image.size.width > 1024 ? 1024/image.size.width : image.size.width
      let size = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
      if let data = image.resize(to: size).fixOrientation().jpegData(compressionQuality: 0.75) {
        pickImageCallback?(.success([(data: data, name: UUID().uuidString)]))
      } else {
        pickImageCallback?(.failure(.unknown))
      }
    } else {
      pickImageCallback?(.failure(.unknown))
    }
  }
}

@available(iOS 14, *)
extension PHSingleImagePickerManager: PHPickerViewControllerDelegate {
  public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    let preferredMaxSize = self.preferredMaxSize
    picker.dismiss(animated: true) { [unowned self] in
      if !results.isEmpty {
        self.onDownsampling?()
      } else {
        self.onCancel?()
      }
      
      PHPickerResultCompressor.downsampling(results, to: preferredMaxSize) { [unowned self] results in
        DispatchQueue.main.async {
          if let results = results as? [WingImagePickerResult] {
            let values = results.map { (data: $0.data, name: $0.name) }
            self.pickImageCallback?(.success(values))
          } else {
            self.pickImageCallback?(.failure(.downsamplingFailure))
          }
          self.onFinishDownsampling?()
        }
      }
    }
  }
}

@objc public enum SourceType: Int {
  case photoLibrary
  case camera
  case fronCamera // Keep objc support
  case video
}

public extension Data {
  var sizeInMB: Double { Double(self.count) / (1024 * 1024) }
}

import Foundation

fileprivate extension UIImage {
  func resize(to size: CGSize) -> UIImage {
    if size.width <= 0 || size.height <= 0 {
      return self
    }
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image ?? self
  }
  
  func fixOrientation() -> UIImage  {
    guard let cgImage = self.cgImage else {
      return self
    }
    
    let width = cgImage.width
    let height = cgImage.height
    
    var transform: CGAffineTransform = .identity
    var bounds = CGRect(x: 0, y: 0, width: width, height: height)
    let scaleRatio = bounds.size.width / CGFloat(width)
    let imageSize = CGSize(width: width, height: height)
    var boundHeight: CGFloat
    let orient = self.imageOrientation
    
    switch(orient) {
    case .up: //EXIF = 1
      transform = .identity
      
    case .upMirrored: //EXIF = 2
      transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0)
      transform = CGAffineTransformScale(transform, -1.0, 1.0)
      
    case .down: //EXIF = 3
      transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height)
      transform = CGAffineTransformRotate(transform, .pi)
      
    case .downMirrored: //EXIF = 4
      transform = CGAffineTransformMakeTranslation(0.0, imageSize.height)
      transform = CGAffineTransformScale(transform, 1.0, -1.0)
      
    case .leftMirrored: //EXIF = 5
      boundHeight = bounds.size.height
      bounds.size.height = bounds.size.width
      bounds.size.width = boundHeight
      transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width)
      transform = CGAffineTransformScale(transform, -1.0, 1.0)
      transform = CGAffineTransformRotate(transform, 3.0 * .pi / 2.0)
      
    case .left: //EXIF = 6
      boundHeight = bounds.size.height
      bounds.size.height = bounds.size.width
      bounds.size.width = boundHeight
      transform = CGAffineTransformMakeTranslation(0.0, imageSize.width)
      transform = CGAffineTransformRotate(transform, 3.0 * .pi / 2.0)
      
    case .rightMirrored: //EXIF = 7
      boundHeight = bounds.size.height
      bounds.size.height = bounds.size.width
      bounds.size.width = boundHeight
      transform = CGAffineTransformMakeScale(-1.0, 1.0)
      transform = CGAffineTransformRotate(transform, .pi / 2.0)
      
    case .right: //EXIF = 8
      boundHeight = bounds.size.height
      bounds.size.height = bounds.size.width
      bounds.size.width = boundHeight
      transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0)
      transform = CGAffineTransformRotate(transform, .pi / 2.0)
      
    default:
      fatalError("Invalid image orientation")
    }
    
    UIGraphicsBeginImageContext(bounds.size);
    
    let context = UIGraphicsGetCurrentContext();
    
    if (orient == .right || orient == .left) {
      context?.scaleBy(x: -scaleRatio, y: scaleRatio)
      context?.translateBy(x: CGFloat(-height), y: 0.0)
    } else {
      context?.scaleBy(x: scaleRatio, y: -scaleRatio)
      context?.translateBy(x: 0.0, y: CGFloat(-height))
    }
    
    context?.concatenate(transform)
    context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    let imageCopy = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return imageCopy ?? self
  }
}
