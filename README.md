# PHSingleImagePicker
A low memory, single image picker wrapper that provide a significant smaller file size while also preserve high image quality.

# Introduction
Image file size ≠ memory size after rendering. Eg: We have a png image with file size 3.4MB and resolution 3000x4000 File size: 3.4MB Memory size to render that image: 3000x4000x4 ~= 46MB For more info, please see [WWDC2018's Video](https://developer.apple.com/videos/play/wwdc2018/219) We attempt to solve both file size and memory size without sacrifice much quality.

Inspired by:
• [Using PHPickerViewController Images in a Memory-Efficient Way](https://christianselig.com/2020/09/phpickerviewcontroller-efficiently/)
• [try! Swift NYC 2019 - The Life of an Image on iOS](https://www.youtube.com/watch?v=vl3aXaNPKE0)


# Requirement
If you need camera usage, please include **NSCameraUsageDescription** key in plist.
Below iOS 14, please include **NSPhotoLibraryUsageDescription** key in plist.

# Usage
```

let imagePicker = PHSingleImagePickerManager.shared
// Optional: Default is 2_000 which mean image width and height cannot reach more than 2_000
imagePicker.preferredMaxSize = 2_000
imagePicker.show(.photoLibrary, on: self) { result in
  switch result {
  case .failure(let error):
    // Show message bar here

  case .success(let value):
    let data = value.data
    let filename = value.name
    let image = UIImage(data: data)
  }
}
    
```
Note: Please use **data** in success block to upload to server instead of `image?.pngData()` or `image?.jpegData(compressionQuality: ??)` . If need to display image, we can convert that image data to image using UIImage(data: data).

# Localize error message
```
extension PHSingleImagePickerManagerError {
  var message: String {
     switch self {
     case .downsamplingFailure:
       return "imagepicker_downsamplingFailure"
     case .noCamera:
       return "imagepicker_noCamera"
     case .noCameraPermission:
       return "imagepicker_noCameraPermission"
     case .noPhotoLibraryPermission:
       return "imagepicker_noPhotoLibraryPermission"
     case .unknown:
       return "imagepicker_unknown"
     }
   }
}
```
# Swift Package Manager

From Xcode menu bar: 
1. File 
2. Swift Packages 
3. Add Package Dependency...
4. Paste the repo url `https://github.com/PhanithNY/PHSingleImagePicker.git`

Or just drop files in Sources folder into your project.
