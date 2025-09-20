//
//  CamearaPermissionManager.swift
//  
//
//  Created by Phanith on 21/10/21.
//

import UIKit
import AVFoundation
import Photos

public final class CameraPermissionManager {
  public static let shared = CameraPermissionManager()
  
  private init() {}
  
  public var permission: AVAuthorizationStatus = .restricted
  
  public func requestAuthorization(completionHandler: @escaping (AVAuthorizationStatus) -> Void) {
    
    let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    switch status{
    case .authorized:
      permission = .authorized
      completionHandler(permission)
      
    case .denied, .restricted:
      permission = .denied
      completionHandler(permission)
      
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          switch granted {
          case true:
            self.permission = .authorized
            completionHandler(self.permission)
            
          case false:
            self.permission = .denied
            completionHandler(self.permission)
          }
        }
      }
      
    @unknown default:
      permission = .denied
      completionHandler(permission)
    }
  }
  
  public func requestPhotoAuthorization(completionHandler: @escaping (PHAuthorizationStatus) -> Void) {
    let status = PHPhotoLibrary.authorizationStatus()
    switch status {
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization { _status in
        DispatchQueue.main.async {
          completionHandler(_status == .authorized ? .authorized : .denied)
        }
      }
      
    default:
      completionHandler(status)
    }
  }
  
  public func isAuthorized() -> Bool {
    permission == .authorized
  }
}

