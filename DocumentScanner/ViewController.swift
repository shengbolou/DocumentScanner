//
//  ViewController.swift
//  DocumentScanner
//
//  Created by Shengbo Lou on 6/29/18.
//  Copyright © 2018 Shengbo Lou. All rights reserved.
//

import UIKit
import CoreImage
import TesseractOCR

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    @IBOutlet var imageview: UIImageView!
    @IBOutlet var saveBtn: UIButton!
    
    var imagePicker:UIImagePickerController!
    var rawImg:UIImage!
    var crop:Bool! = false
    let ciContext =  CIContext()
    var docImage:CIImage!
    var resRect:CIRectangleFeature!
    var croppedImg:CIImage!
    var resultString:String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.saveBtn.isEnabled = false
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        imageview.isUserInteractionEnabled = true
        imageview.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @IBAction func takePressed(_ sender: UIButton) {
        imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        self.present(imagePicker, animated: true)
    }
    
    @IBAction func savePressed(_ sender:UIButton) {
        if let tesseract = G8Tesseract(language: "eng") {
            tesseract.engineMode = .tesseractCubeCombined
            tesseract.pageSegmentationMode = .auto
            tesseract.image = self.imageview.image
            tesseract.recognize()
            resultString = String(tesseract.recognizedText)
            print(resultString)
            self.performSegue(withIdentifier: "OCR", sender: nil)
        }
//        UIImageWriteToSavedPhotosAlbum(self.imageview.image!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print(error)
            presentAlert(title: "Error", message: "Save image failed!",handler: nil)
        } else {
            print("save image succeed")
            presentAlert(title: "Success", message: "Save image succeed!",handler: nil)
            self.imageview.image = nil
            self.rawImg = nil
            self.resRect = nil
            self.docImage = nil
            self.saveBtn.isEnabled = false
        }
    }
    
    @objc private func imageTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        if crop {
            cropImg()
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        imagePicker.dismiss(animated: true)
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else{
            print("no image")
            return
        }
        rawImg = image
        
        docImage = CIImage(image: rawImg!)!
        
        guard let detector = CIDetector(ofType: CIDetectorTypeRectangle,
                                        context: ciContext,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else {
            return
        }
        
        guard let rect:CIRectangleFeature = detector.features(in: docImage).first as? CIRectangleFeature else{
            self.presentAlert(title: "Please rescan document", message: "Not able to detect document correctly, please keep the document in the camera view"){ (_) in
                self.present(self.imagePicker, animated: true)
            }
            return
        }
        
        resRect = rect
        
        var overlay = CIImage(color: CIColor(red: 0.0, green: 0.47, blue: 0.73, alpha: 0.5))
        overlay = overlay.cropped(to: docImage.extent)

        overlay = overlay.applyingFilter("CIPerspectiveTransformWithExtent", parameters:
            [kCIInputExtentKey : CIVector(cgRect: docImage.extent),
             "inputTopLeft": CIVector(cgPoint:rect.topLeft),
             "inputTopRight": CIVector(cgPoint:rect.topRight),
             "inputBottomRight": CIVector(cgPoint:rect.bottomRight),
             "inputBottomLeft": CIVector(cgPoint:rect.bottomLeft)
            ] )

        var resimage = overlay.composited(over: docImage)
        resimage = resimage.oriented(self.CGImagePropertyOrientationForUIImageOrientation(uiOrientation: rawImg.imageOrientation))
        let updatedImage = UIImage(ciImage: resimage, scale: rawImg!.scale, orientation: rawImg.imageOrientation)
        self.imageview.image = updatedImage
        crop = true
        self.saveBtn.isEnabled = true
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destinationNavigationController = segue.destination as? UINavigationController{
            let contentViewController = destinationNavigationController.topViewController as! ContentViewController
            contentViewController.text = resultString
        }
    }
    
    
    private func presentAlert(title:String, message:String, handler:((UIAlertAction)->Void)?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: handler))
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    private func cropImg() {
        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")!

        perspectiveCorrection.setValue(CIVector(cgPoint:resRect.topLeft),
                                       forKey: "inputTopLeft")
        perspectiveCorrection.setValue(CIVector(cgPoint:resRect.topRight),
                                       forKey: "inputTopRight")
        perspectiveCorrection.setValue(CIVector(cgPoint:resRect.bottomRight),
                                       forKey: "inputBottomRight")
        perspectiveCorrection.setValue(CIVector(cgPoint:resRect.bottomLeft),
                                       forKey: "inputBottomLeft")
        perspectiveCorrection.setValue(docImage,
                                       forKey: kCIInputImageKey)

        var outputImage = perspectiveCorrection.outputImage
        outputImage = outputImage?.oriented(self.CGImagePropertyOrientationForUIImageOrientation(uiOrientation: rawImg.imageOrientation))
        croppedImg = outputImage
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(outputImage, forKey: kCIInputImageKey)
        filter?.setValue(5.3, forKey: kCIInputContrastKey)
        filter?.setValue(0.2, forKey: kCIInputSaturationKey)
        filter?.setValue(1.08, forKey: kCIInputBrightnessKey)
        outputImage = filter?.outputImage
        outputImage = outputImage?.applyingFilter("CIPhotoEffectNoir")
        let cgimg = ciContext.createCGImage(outputImage!, from: outputImage!.extent)
        self.imageview.image = UIImage(cgImage: cgimg!)
    }
    
    private func CGImagePropertyOrientationForUIImageOrientation(uiOrientation:UIImageOrientation) -> CGImagePropertyOrientation{
        switch (uiOrientation) {
        case UIImageOrientation.up:
            return CGImagePropertyOrientation.up
        case UIImageOrientation.down:
            return CGImagePropertyOrientation.down
        case UIImageOrientation.left:
            return CGImagePropertyOrientation.left
        case UIImageOrientation.right:
            return CGImagePropertyOrientation.right
        case UIImageOrientation.upMirrored:
            return CGImagePropertyOrientation.upMirrored
        case UIImageOrientation.downMirrored:
            return CGImagePropertyOrientation.downMirrored
        case UIImageOrientation.leftMirrored:
            return CGImagePropertyOrientation.leftMirrored
        case UIImageOrientation.rightMirrored:
            return CGImagePropertyOrientation.rightMirrored
        }
    }
    
    private func OCR() {
        let context = CIContext()

        guard let detector = CIDetector(ofType: CIDetectorTypeText,
                                        context: context,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else {
                                            return
        }

        guard let rects:[CITextFeature] = detector.features(in: croppedImg, options:[CIDetectorImageOrientation: 8]) as? [CITextFeature] else {
            return
        }

        print(rects.count)

        for rect in rects{
            var textArea:CIImage = croppedImg.cropped(to: rect.bounds)
            textArea = textArea.oriented(self.CGImagePropertyOrientationForUIImageOrientation(uiOrientation: rawImg.imageOrientation))
            let cgimg = context.createCGImage(textArea, from: textArea.extent)
            let uiImg = UIImage(cgImage: cgimg!)
            if let tesseract = G8Tesseract(language: "eng") {
                tesseract.engineMode = .tesseractCubeCombined
                tesseract.pageSegmentationMode = .auto
                tesseract.image = uiImg.g8_blackAndWhite()
                tesseract.recognize()
                print(tesseract.recognizedText)
            }
            break
        }
    }
    
    
//    func DrawOnImage(startingImage: UIImage, observations:[CIRectangleFeature]) -> UIImage {
//
//        // Create a context of the starting image size and set it as the current one
//        UIGraphicsBeginImageContext(startingImage.size)
//
//        // Draw the starting image in the current context as background
//        startingImage.draw(at: CGPoint.zero)
//
//        // Get the current context
//        let context = UIGraphicsGetCurrentContext()!
//
//
//        for observation in observations{
//            // Draw a red line
//            context.setLineWidth(3)
//            context.setStrokeColor(UIColor.red.cgColor)
//            context.move(to: observation.topLeft.scaled(to: startingImage.size))
//            context.addLine(to: observation.topRight.scaled(to: startingImage.size))
//            context.addLine(to: observation.bottomRight.scaled(to: startingImage.size))
//            context.addLine(to: observation.bottomLeft.scaled(to: startingImage.size))
//            context.addLine(to: observation.topLeft.scaled(to: startingImage.size))
//            context.strokePath()
//        }
//
//
//        // Save the context as a new UIImage
//        let myImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//
//        // Return modified image
//        return myImage!
//
//    }
//
}


//extension UIImage {
//    func fixed() -> UIImage {
//        let ciContext = CIContext(options: nil)
//
//        let cgImg = ciContext.createCGImage(ciImage!, from: ciImage!.extent)
//        let image = UIImage(cgImage: cgImg!, scale: scale, orientation: .right)
//
//        return image
//    }
//}
