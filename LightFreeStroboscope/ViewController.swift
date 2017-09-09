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
    
    var minandmax: AVFrameRateRange!
    @IBOutlet weak var rpmLabel: UILabel!
    @IBOutlet weak var hertzLabel: UILabel!
    var lastDate = Date().timeIntervalSince1970
    var oldtransy:Float = 0
    var format240: AVCaptureDeviceFormat?
    var captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice
    var formatDef: AVCaptureDeviceFormat!
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        hertzLabel.layer.cornerRadius = 5
        rpmLabel.layer.cornerRadius = 5
        setupCameraSession()
        self.view.layer.insertSublayer(previewLayer, at: 0)
        cameraSession.startRunning()
        changeRefresh(hertz: 10)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    


    @IBAction func rightSwipe(_ sender: UISwipeGestureRecognizer) {
        changeRefresh(hertz: refreshRate * 2)
    }
    
    @IBAction func leftSwipe(_ sender: UISwipeGestureRecognizer) {
        changeRefresh(hertz: refreshRate / 2)
    }

    @IBAction func panChangeRate(_ sender: UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: self.view)
        sender.setTranslation(CGPoint(), in: self.view)

        let velocity = sender.velocity(in: self.view)
        
        changeRefresh(hertz: refreshRate + copysign(Double(Int(Double(translation.y) * Double(velocity.y) / 64)) / 100, -Double(translation.y)))
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
            formatDef = captureDevice.activeFormat
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
                for format in captureDevice.formats {
                    let frmt = format as! AVCaptureDeviceFormat
                    if (frmt.videoSupportedFrameRateRanges as! [AVFrameRateRange])[0].maxFrameRate == 120 && CMFormatDescriptionGetMediaSubType(frmt.formatDescription) == 875704422 {
                        captureDevice.activeFormat = frmt
                        formatDef = frmt
                    } else if (frmt.videoSupportedFrameRateRanges as! [AVFrameRateRange])[0].maxFrameRate == 240 && CMFormatDescriptionGetMediaSubType(frmt.formatDescription) == 875704422 {
                        format240 = frmt
                    }
                    
                }
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
        let (min, max) = getMinMaxFrameRate()
        var newHertz = hertz
        if hertz <= min {
            newHertz = min
        } else if hertz >= max {
            if format240 == nil {
                newHertz = max
            } else if hertz >= 240 {
                newHertz = 240
            }
        }
        
        refreshRate = newHertz
        updateLabels(hertz: newHertz)
        do {
            try captureDevice.lockForConfiguration()
            if captureDevice.activeFormat == formatDef && newHertz > 120 {
                captureDevice.activeFormat = format240
            } else if captureDevice.activeFormat == format240 && newHertz <= 120 {
                captureDevice.activeFormat = formatDef
            }
            captureDevice.setExposureModeCustomWithDuration(CMTimeMake(1, 2000), iso: captureDevice.activeFormat.maxISO, completionHandler: nil)
            captureDevice.activeVideoMaxFrameDuration = CMTimeMake(100, Int32(newHertz * 100))
            captureDevice.activeVideoMinFrameDuration = CMTimeMake(100, Int32(newHertz * 100))
            captureDevice.unlockForConfiguration()
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    func getMinMaxFrameRate() -> (Double, Double) {
        minandmax = formatDef.videoSupportedFrameRateRanges[0] as? AVFrameRateRange
        return ((minandmax?.minFrameRate)!, (minandmax?.maxFrameRate)!)
    }
    
    func updateLabels(hertz: Double) {
        hertzLabel.text = String(format: "%.2f Hz", hertz)
        rpmLabel.text = String(format: "%.1f RPM", hertz * 60)
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        // non-dropped frames
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        // dropped frames
    }
    
}

