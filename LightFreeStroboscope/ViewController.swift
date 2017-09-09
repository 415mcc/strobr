//
//  ViewController.swift
//  LightFreeStroboscope
//
//  Created by Lachlan McCarty on 9/8/17.
//  Copyright © 2017 Lachlan McCarty. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    var refreshRate: Float = 10
    var doneSlide = true
    @IBOutlet var MainView: UIView!
    let panRec = UIPanGestureRecognizer()

    
    @IBOutlet weak var rpmLabel: UILabel!
    @IBOutlet weak var hertzLabel: UILabel!
    var lastDate = Date().timeIntervalSince1970
    var oldtransy:Float = 0
    
    lazy var captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        view.layer.insertSublayer(previewLayer, at: 0)
        
        cameraSession.startRunning()
    }
    


    @IBAction func rightSwipe(_ sender: UISwipeGestureRecognizer) {
    }
    @IBAction func leftSwipe(_ sender: UISwipeGestureRecognizer) {
    }

    @IBAction func panChangeRate(_ sender: UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: MainView)
        sender.setTranslation(CGPoint(), in: MainView)

        let velocity = sender.velocity(in: MainView)
//        print("velocity")
//        print(velocity.x)
        
        
        
//        print("translation y")
//        print(translation.y)
        

        refreshRate += -1*(Float(translation.y))
        let output = (String(refreshRate) + "Hz")
        hertzLabel.text = output
    }



    lazy var cameraSession: AVCaptureSession = {
        let s = AVCaptureSession()
        s.sessionPreset = AVCaptureSessionPresetHigh
        
        return s
    }()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview =  AVCaptureVideoPreviewLayer(session: self.cameraSession)
        preview?.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        preview?.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        preview?.videoGravity = AVLayerVideoGravityResizeAspect
        return preview!
    }()
    
    func setupCameraSession() {
        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            cameraSession.beginConfiguration()
            
            if cameraSession.canAddInput(deviceInput) {
                cameraSession.addInput(deviceInput)
            }
            
            let dataOutput = AVCaptureVideoDataOutput()
            dataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)]
            dataOutput.alwaysDiscardsLateVideoFrames = true
            
            if cameraSession.canAddOutput(dataOutput) {
                cameraSession.addOutput(dataOutput)
                let conn = dataOutput.connection(withMediaType: AVFoundation.AVMediaTypeVideo)
                conn?.videoOrientation = .portrait
                try captureDevice.lockForConfiguration()
                captureDevice.exposureMode = .custom
                print(captureDevice.iso)
                captureDevice.setExposureModeCustomWithDuration(CMTimeMake(1, 2000), iso: captureDevice.activeFormat.maxISO, completionHandler: nil)
                captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, 6)
                captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, 6)
                captureDevice.unlockForConfiguration()
                
            }
            
            cameraSession.commitConfiguration()
            
            let queue = DispatchQueue(label: "com.invasivecode.videoQueue")
            dataOutput.setSampleBufferDelegate(self, queue: queue)
            
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        // non-dropped frames
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        // dropped frames
    }
    
}

