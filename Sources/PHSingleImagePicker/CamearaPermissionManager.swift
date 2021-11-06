//
//  CamearaPermissionManager.swift
//  
//
//  Created by Phanith on 21/10/21.
//

import UIKit
import AVFoundation
import Photos

public final class CamearaPermissionManager {
  static let shared = CamearaPermissionManager()
  
  private init() {}
  
  var permission: AVAuthorizationStatus = .restricted
  
  func requestAuthorization(completionHandler: @escaping (AVAuthorizationStatus) -> Void) {
    
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
          if !granted {
            self.permission = .denied
            completionHandler(self.permission)
          } else {
            self.permission = .authorized
            completionHandler(self.permission)
          }
        }
      }
    default: break
    }
  }
  
  func requestPhotoAuthorization(completionHandler: @escaping (PHAuthorizationStatus) -> Void) {
    let status = PHPhotoLibrary.authorizationStatus()
    switch status {
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization { _status in
        DispatchQueue.main.async {
          if _status == .authorized {
            completionHandler(.authorized)
          }else {
            completionHandler(.denied)
          }
        }
      }
      
    default:
      completionHandler(status)
    }
  }
  
  func isAuthorized() -> Bool {
    permission == .authorized
  }
}

