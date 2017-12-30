//
//  ViewController.swift
//  Strobr
//

import UIKit
import AVFoundation

class ViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    UIGestureRecognizerDelegate {
    
    // Instance variables
    
    var refreshRate = 24.0
    var isHz = true
    var flashOn = false
    var exposure = CMTime(value: 2, timescale: 1)

    let captureSession = AVCaptureSession()
    var formats: [AVCaptureDevice.Format]!
    var range: (Double, Double)!
    var previewLayer: AVCaptureVideoPreviewLayer!
    let captureDevice = AVCaptureDevice.default(for: .video)!
    
    @IBOutlet weak var hertzLabel: UILabel!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet var leftSwipeRecog: UISwipeGestureRecognizer!
    @IBOutlet var rightSwipeRecog: UISwipeGestureRecognizer!
    @IBOutlet var panRecog: UIPanGestureRecognizer!
    var lastDate = Date().timeIntervalSince1970
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // Initialize camera and gesture recognizers
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCaptureSession()
        captureSession.startRunning()
        changeRefresh(hertz: refreshRate)
        
        hertzLabel.isUserInteractionEnabled = true
        let labelTapGesture = UITapGestureRecognizer(target: self, action: #selector(userDidTapLabel(tap:)))
        hertzLabel.addGestureRecognizer(labelTapGesture)
        
        let cameraTapGesture = UITapGestureRecognizer(target: self, action: #selector(userDidTapCamera(tap:)))
        view.addGestureRecognizer(cameraTapGesture)
    }
    
    // Handle user interactions, including updating UI and camera configuration
    
    @objc func userDidTapLabel(tap: UITapGestureRecognizer) {
        isHz = !isHz
        updateHertzLabel()
    }
    
    @objc func userDidTapCamera(tap: UITapGestureRecognizer) {
        // get tap point in appropriate coordinates
        let screenSize = previewLayer.bounds.size
        let tapPoint = tap.location(in: view)
        let x = tapPoint.y / screenSize.height
        let y = 1.0 - tapPoint.x / screenSize.width
        let focusPoint = CGPoint(x: x, y: y)
        // set autofocus and exposure according to point
        do {
            try captureDevice.lockForConfiguration()
            if captureDevice.isFocusPointOfInterestSupported == true {
                captureDevice.focusPointOfInterest = focusPoint
                captureDevice.focusMode = .continuousAutoFocus
            }
            captureDevice.exposurePointOfInterest = focusPoint
            captureDevice.exposureMode = .autoExpose
            usleep(400000) // hack to wait for exposure adjustment
            exposure = CMTimeMultiplyByFloat64(captureDevice.exposureDuration, Float64(captureDevice.iso))
            let duration = CMTimeMultiplyByFloat64(exposure, 1.0 / Float64(captureDevice.activeFormat.maxISO))
            captureDevice.setExposureModeCustom(duration: duration, iso: captureDevice.activeFormat.maxISO)
            captureDevice.unlockForConfiguration()
        } catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    @IBAction func leftSwipe(_ sender: UISwipeGestureRecognizer) {
        changeRefresh(hertz: refreshRate / 2)
    }
    
    @IBAction func rightSwipe(_ sender: UISwipeGestureRecognizer) {
        changeRefresh(hertz: refreshRate * 2)
    }

    @IBAction func panChangeRate(_ sender: UIPanGestureRecognizer) {
        let velocity = sender.velocity(in: view)
        changeRefresh(hertz: refreshRate - Double(velocity.y)/1000)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return (gestureRecognizer == leftSwipeRecog || gestureRecognizer == rightSwipeRecog) && otherGestureRecognizer == panRecog
    }

    @IBAction func toggleFlash(_ sender: UIButton) {
        flashOn = !flashOn
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.torchMode = flashOn ? .on : .off
            captureDevice.unlockForConfiguration()
        } catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
        flashButton.setTitleColor(flashOn ? .yellow : .white, for: .normal)
    }
    
    func updateHertzLabel() {
        if isHz {
            hertzLabel.text = String(format: "%.2f Hz", refreshRate)
        } else {
            hertzLabel.text = String(format: "%.0f RPM", refreshRate*60)
        }
    }
    
    // Camera setup and refresh rate changing code
    
    func setupCaptureSession() {
        do {
            captureSession.sessionPreset = .high
            // get highest resolution formats in each frame rate range
            formats = captureDevice.formats
            for format in captureDevice.formats {
                formats = formats.filter {
                    getMinMaxFrameRate(format: format).1 != getMinMaxFrameRate(format: $0).1 ||
                    CMVideoFormatDescriptionGetDimensions(format.formatDescription).height <=
                        CMVideoFormatDescriptionGetDimensions($0.formatDescription).height &&
                    Double(CMVideoFormatDescriptionGetDimensions($0.formatDescription).width) /
                        Double(CMVideoFormatDescriptionGetDimensions($0.formatDescription).height) ==
                        1920.0/1080.0
                }
            }
            formats.sort { getMinMaxFrameRate(format: $0).1 < getMinMaxFrameRate(format: $1).1 }
            range = (getMinMaxFrameRate(format: formats[0]).0,
                getMinMaxFrameRate(format: formats[formats.count-1]).1)
            // link capture device to capture session
            captureSession.beginConfiguration()
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(deviceInput)
            captureSession.commitConfiguration()
        } catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
        // setup view layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = view.layer.frame
    }
    
    func changeRefresh(hertz: Double) {
        let newRefreshRate = min(max(hertz, range.0), range.1)
        do {
            try captureDevice.lockForConfiguration()
            // choose format
            captureDevice.activeFormat = formats.first(
                where: { newRefreshRate <= getMinMaxFrameRate(format: $0).1 } )!
            // update torch
            captureDevice.torchMode = flashOn ? .on : .off
            // update exposure
            let duration = CMTimeMultiplyByFloat64(exposure, 1.0 / Float64(captureDevice.activeFormat.maxISO))
            captureDevice.setExposureModeCustom(duration: duration, iso: captureDevice.activeFormat.maxISO)
            // update frame rate
            captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1000, Int32(newRefreshRate * 1000))
            captureDevice.activeVideoMinFrameDuration = CMTimeMake(1000, Int32(newRefreshRate * 1000))
            captureDevice.unlockForConfiguration()
        } catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
        refreshRate = newRefreshRate
        updateHertzLabel()
    }
    
    func getMinMaxFrameRate(format: AVCaptureDevice.Format) -> (Double, Double) {
        let minandmax = format.videoSupportedFrameRateRanges[0] as AVFrameRateRange
        return (minandmax.minFrameRate, minandmax.maxFrameRate)
    }
}

