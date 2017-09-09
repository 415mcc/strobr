//
//  ViewController.swift
//  LightFreeStroboscope
//
//  Created by Lachlan McCarty on 9/8/17.
//  Copyright © 2017 Lachlan McCarty. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UIGestureRecognizerDelegate {
    
    var refreshRate: Double = 10
    var doneSlide = true
    @IBOutlet var leftSwipeRecog: UISwipeGestureRecognizer!
    @IBOutlet var rightSwipeRecog: UISwipeGestureRecognizer!
    @IBOutlet var panRecog: UIPanGestureRecognizer!
    var isHz = true

    var minandmax: AVFrameRateRange!
    var min: Double = 0.0
    var max: Double = 0.0
    @IBOutlet var hertzLabel: UILabel!
   
    
    var lastDate = Date().timeIntervalSince1970
    var oldtransy:Float = 0
    
    lazy var captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice

    override func viewDidLoad() {
        super.viewDidLoad()
        hertzLabel.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(userDidTapLabel(tapGestureRecognizer:)))
        hertzLabel.addGestureRecognizer(tapGesture)
        minandmax = captureDevice.activeFormat.videoSupportedFrameRateRanges[0] as? AVFrameRateRange
        min = (minandmax?.minFrameRate)!
        max = (minandmax?.maxFrameRate)!
        setupCameraSession()
        self.view.layer.insertSublayer(previewLayer, at: 0)
        cameraSession.startRunning()
        changeRefresh(hertz: 14.11)
    }

    func userDidTapLabel(tapGestureRecognizer: UITapGestureRecognizer) {
        isHz =  !isHz
        updateLabels(hertz: refreshRate)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    


    @IBAction func rightSwipe(_ sender: UISwipeGestureRecognizer) {
        print("called r")
        if refreshRate * 2 < max{
            refreshRate *= 2
            updateLabels(hertz: refreshRate)
        } else {
            refreshRate = max
            updateLabels(hertz: refreshRate)
        }
    }
    
    @IBAction func leftSwipe(_ sender: UISwipeGestureRecognizer) {
        print("called l")
        if refreshRate/2 > min{
            refreshRate /= 2
            updateLabels(hertz: refreshRate)
        } else {
            refreshRate = min
            updateLabels(hertz: refreshRate)
        }
    }

    @IBAction func panChangeRate(_ sender: UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: self.view)
        sender.setTranslation(CGPoint(), in: self.view)

        let velocity = sender.velocity(in: self.view)
        print("velocity \(velocity.y)")
        
        
        
        print("translation y \(translation.y)")
        
        let nextrate = refreshRate + copysign(Double(Int(Double(translation.y) * Double(velocity.y) / 64)) / 100, -Double(translation.y))
        
        if nextrate < min {
            changeRefresh(hertz: min)
        } else if nextrate > max {
            changeRefresh(hertz: max)
        } else {
            changeRefresh(hertz: nextrate)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return (gestureRecognizer == self.leftSwipeRecog || gestureRecognizer == self.rightSwipeRecog) && otherGestureRecognizer == self.panRecog
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
    
    func changeRefresh(hertz: Double) {
        refreshRate = hertz
        updateLabels(hertz: hertz)
        do {
            try captureDevice.lockForConfiguration()
            print(captureDevice.iso)
            captureDevice.setExposureModeCustomWithDuration(CMTimeMake(1, 2000), iso: captureDevice.activeFormat.maxISO, completionHandler: nil)
            captureDevice.activeVideoMaxFrameDuration = CMTimeMake(100, Int32(hertz * 100))
            captureDevice.activeVideoMinFrameDuration = CMTimeMake(100, Int32(hertz * 100))
            captureDevice.unlockForConfiguration()
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    func updateLabels(hertz: Double) {
        if isHz{
            hertzLabel.text = String(format: "%.2f Hz", hertz)

        } else {
            hertzLabel.text = String(format: "%.2f RPM", hertz*60)
        }
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        // non-dropped frames
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        // dropped frames
    }
    
}

