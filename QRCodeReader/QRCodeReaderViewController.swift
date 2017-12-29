//
//  QRCodeReaderViewController.swift
//  QRCodeReader
//
//  Created by LeeSangchan on 2017. 6. 11..
//  Copyright © 2017년 LeeSangchan. All rights reserved.
//

import UIKit
import AVFoundation

struct QRCode {
    let type  : String
    let value : String
    
    func parse() -> FreeClassInfo? {
        let divideBySharp = value.components(separatedBy: "#")
        guard divideBySharp.count == 2 else {
            return nil
        }
        
        var dic = [String:String]()
        dic["domain"] = divideBySharp[0]
        guard divideBySharp[1].contains(";") else {
            return nil
        }
        
        let divideBySemiColon = divideBySharp[1].components(separatedBy: ";")
        for data in divideBySemiColon {
            if data.contains("=") {
                let detail = data.components(separatedBy: "=")
                dic[detail[0]] =  detail[1]
            }
        }
        return FreeClassInfo(dictionary: dic)
    }
}

struct FreeClassInfo {
    let domain     : String
    let freePL     : Bool
    let startTime  : String
    let endTime    : String
    let cc         : String
    let contentId  : String
    let uniqueId   : String
    let role       : String
    let name       : String
    let layoutCode : String
    let hashCode   : String
    
    init?(dictionary: [String:String]) {
        guard let domain    = dictionary["domain"],
            let freePLStr   = dictionary["freepl"],
            let startTime   = dictionary["starttime"],
            let endTime     = dictionary["endtime"],
            let cc          = dictionary["cc"],
            let contentId   = dictionary["contentid"],
            let uniqueId    = dictionary["uniqueid"],
            let role        = dictionary["role"],
            let name        = dictionary["name"],
            let layoutCode  = dictionary["layoutcode"],
            let hashCode    = dictionary["hashcode"]
        else {
            return nil
        }
        
        self.domain = domain
        self.freePL = (freePLStr == "true") ? true : false
        self.startTime = startTime
        self.endTime = endTime
        self.cc = cc
        self.contentId = contentId
        self.uniqueId = uniqueId
        self.role = role
        self.name = name
        self.layoutCode = layoutCode
        self.hashCode = hashCode
    }
}

class QRCodeReaderViewController: UIViewController {
    @IBOutlet weak var showImagePickeButton: UIButton!
    @IBOutlet weak var cameraContainer: UIView!
    @IBOutlet weak var progressContainer: ScanProcessingView!
    
    let session = AVCaptureSession()
    var ableToScan : Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.hideProgressView()
        self.startSession()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        self.stopSession()
    }
    
}


extension QRCodeReaderViewController: AVCaptureMetadataOutputObjectsDelegate {
    func startSession() {
        if session.isRunning { return }
        ableToScan = true
        session.sessionPreset = AVCaptureSessionPresetHigh
        
        let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        let videoInput = try! AVCaptureDeviceInput(device: videoDevice)
        
        session.addInput(videoInput)
        
        let frameOut = AVCaptureVideoDataOutput()
        session.addOutput(frameOut)
        frameOut.connection(withMediaType: AVMediaTypeVideo)
        if let previewLayer = AVCaptureVideoPreviewLayer(session: session) {
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            let rootLayer = cameraContainer.layer
            rootLayer.masksToBounds = true
            previewLayer.frame = rootLayer.bounds
            rootLayer.addSublayer(previewLayer)
        }
        
        let output = AVCaptureMetadataOutput()
        output.setMetadataObjectsDelegate(self, queue:DispatchQueue.main)
        session.addOutput(output)
        output.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        
        session.startRunning()
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        guard ableToScan == true else { return }
        for current in metadataObjects {
            if let readableCodeObject = current as? AVMetadataMachineReadableCodeObject, readableCodeObject.type == AVMetadataObjectTypeQRCode  {
                if let stringValue = readableCodeObject.stringValue {
                    let result = QRCode(type: readableCodeObject.type, value: stringValue)
                    if let parsedResult = result.parse() {
                        self.showProgressView()
                        print("parsed = \(parsedResult.uniqueId)")
                    }
                }
            }
        }
    }
    
    func showProgressView() {
        self.ableToScan = false
        self.progressContainer.show()
    }
    
    func hideProgressView() {
        self.ableToScan = true
        self.progressContainer.hide()
    }
}

extension QRCodeReaderViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBAction func getImageLibrary(_ sender : UIButton) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) == true {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let originalImage:UIImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        let image:UIImage = self.reduceImageSize(image: originalImage)
        
        if let ciImage: CIImage = CIImage(image: image), let detector:CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context:nil, options:[CIDetectorAccuracy: CIDetectorAccuracyHigh]) {
            let features = detector.features(in: ciImage)
            for feature in features as! [CIQRCodeFeature] {
                if let stringValue = feature.messageString {
                    let result = QRCode(type: AVMetadataObjectTypeQRCode, value: stringValue)
                    if let parsedResult = result.parse() {
                        self.showProgressView()
                        print("parsed = \(parsedResult.uniqueId)")
                    }
                }
            }
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    func reduceImageSize(image:UIImage) -> UIImage{
        let scaleFactor = self.getScaleFactor(length: max(image.size.width, image.size.height))
        let newImageSize = CGSize(width: image.size.width * scaleFactor, height:image.size.height * scaleFactor)
        let newCanvasSize = CGSize(width: newImageSize.width * 1.1, height: newImageSize.height * 1.1)
        UIGraphicsBeginImageContextWithOptions(newCanvasSize, false, 0.0);
        UIColor.white.set()
        UIRectFill(CGRect(x: 0, y: 0, width: newCanvasSize.width, height: newCanvasSize.height))
        let newImageCenter = CGPoint(x: (newCanvasSize.width - newImageSize.width)/2.0, y: (newCanvasSize.height - newImageSize.height)/2.0)
        image.draw(in: CGRect(origin: newImageCenter, size: newImageSize))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func getScaleFactor(length:CGFloat) -> CGFloat {
        let maximumLength : CGFloat = 1200.0
        if length > maximumLength {
            return maximumLength / length
        }
        
        return 1.0
    }
}

class BackgroundView : UIView {
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context!.clear(self.bounds)
        
        let clipPath = UIBezierPath(rect: self.bounds)
        
        let size : CGFloat = 200.0
        let originX = (self.bounds.width - size) / 2.0
        let originY = (self.bounds.height - size) / 2.0
        
        let transparentFrame = CGRect(x: originX, y: originY, width: size, height: size)
        
        let path = UIBezierPath(rect: transparentFrame)
        clipPath.append(path)
        
        clipPath.usesEvenOddFillRule = true
        clipPath.addClip()
        
        let tintColor = UIColor(red: 0, green: 28/255.0, blue: 60/255.0, alpha: 0.5)
        tintColor.setFill()
        clipPath.fill()
        
        let whiteColor = UIColor.white
        whiteColor.setStroke()
        path.stroke()
        
        let labelHeight : CGFloat = 20.0
        
        let label = UILabel(frame: CGRect(x: self.bounds.origin.x, y: transparentFrame.origin.y - (labelHeight * 2), width: self.bounds.size.width, height:labelHeight))
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17)
        label.text = "Scan QR Code to take a taster class"

        self.addSubview(label)
        
        let scanLine = UIView(frame: CGRect(x: transparentFrame.origin.x, y: transparentFrame.origin.y, width: transparentFrame.size.width, height: 3.0))
        scanLine.backgroundColor = UIColor.blue
        self.addSubview(scanLine)
        
        
        UIView.animate(withDuration: 3.0, animations: { 
            scanLine.frame = CGRect(x: transparentFrame.origin.x, y: transparentFrame.origin.y+transparentFrame.size.height, width: transparentFrame.size.width, height: 3.0)
        }) { (done) in
            scanLine.frame = CGRect(x: transparentFrame.origin.x, y: transparentFrame.origin.y, width: transparentFrame.size.width, height: 3.0)
        }
        
    }

}

class ScanProcessingView : UIView {
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context!.clear(self.bounds)
        
        let size : CGFloat = 200.0
        let originX = (self.bounds.width - size) / 2.0
        let originY = (self.bounds.height - size) / 2.0
        
        let transparentFrame = CGRect(x: originX, y: originY, width: size, height: size)
        
        let path = UIBezierPath(rect: transparentFrame)
        
        let tintColor = UIColor(red: 0, green: 28/255.0, blue: 60/255.0, alpha: 0.3)
        tintColor.setFill()
        path.fill()
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        activityIndicator.frame = transparentFrame
        activityIndicator.startAnimating()
        self.addSubview(activityIndicator)
        
        let labelHeight : CGFloat = 20.0
        
        let label = UILabel(frame: CGRect(x: transparentFrame.origin.x, y: transparentFrame.origin.y + (size / 2) + labelHeight , width: transparentFrame.width, height:labelHeight))
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17)
        label.text = "Loading"
        
        self.addSubview(label)
    }
    
    func hide() {
        self.isHidden = true
    }
    
    func show() {
        self.isHidden = false
    }
}
