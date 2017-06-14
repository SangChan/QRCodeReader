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
}

struct FreeClassInfo {
    let startTime  : Date
    let endTime    : Date
    let domain     : String
    let freePL     : Bool
    let contentId  : String
    let uniqueId   : String
    let role       : String
    let name       : String
    let layoutCode : String
}

class QRCodeReaderViewController: UIViewController {
    @IBOutlet weak var showImagePickeButton: UIButton!
    @IBOutlet weak var cameraContainer: UIView!
    let session = AVCaptureSession()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.startSession()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        self.stopSession()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    
}

extension QRCodeReaderViewController: AVCaptureMetadataOutputObjectsDelegate {
    func startSession() {
        if session.isRunning { return }
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
        for current in metadataObjects {
            if let readableCodeObject = current as? AVMetadataMachineReadableCodeObject, readableCodeObject.type == AVMetadataObjectTypeQRCode  {
                if let stringValue = readableCodeObject.stringValue {
                    let result = QRCode(type: readableCodeObject.type, value: stringValue)
                    print("result : \(result)")
                }
            }
        }
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
        let image:UIImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        let detector:CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context:nil, options:[CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        let ciImage: CIImage = CIImage(image: image)!
        
        let features = detector.features(in: ciImage)
        
        for feature in features as! [CIQRCodeFeature] {
            print(feature.messageString!)
        }
        
        
        picker.dismiss(animated: true, completion: nil)
    }
}
