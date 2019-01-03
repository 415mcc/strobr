//
//  ViewController.swift
//  Strobr
//

import UIKit
import AVFoundation

// MARK: - ViewController

class ViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    UIGestureRecognizerDelegate {
    
    var captureFPS = 24.0
    var isHz = true, torchOn = false, hasTorch = false
    var exposure = CMTime(value: 2, timescale: 1)

    let captureDevice = AVCaptureDevice.default(for: .video)
    var formats = [AVCaptureDevice.Format]()
    var fpsRange = (24.0, 24.0)
    var previewLayer = AVCaptureVideoPreviewLayer()
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet var leftSwipeRecog: UISwipeGestureRecognizer!
    @IBOutlet var rightSwipeRecog: UISwipeGestureRecognizer!
    @IBOutlet var panRecog: UIPanGestureRecognizer!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCaptureSession()
        changeFPS(captureFPS)
        
        label.isUserInteractionEnabled = true
        let labelTapGesture = UITapGestureRecognizer(target: self, action: #selector(userDidTapLabel(tap:)))
        label.addGestureRecognizer(labelTapGesture)
        
        let cameraTapGesture = UITapGestureRecognizer(target: self, action: #selector(userDidTapCamera(tap:)))
        view.addGestureRecognizer(cameraTapGesture)
        
        if !hasTorch { flashButton.isHidden = true }
    }
    
    // MARK: - Gesture Handlers
    
    @objc func userDidTapLabel(tap: UITapGestureRecognizer) {
        isHz = !isHz
        updateLabel()
    }
    
    @objc func userDidTapCamera(tap: UITapGestureRecognizer) {
        guard let device = captureDevice else { return }
        // get tap point in appropriate coordinates
        let screenSize = previewLayer.bounds.size
        let tapPoint = tap.location(in: view)
        let x = tapPoint.y / screenSize.height
        let y = 1.0 - tapPoint.x / screenSize.width
        let focusPoint = CGPoint(x: x, y: y)
        // set autofocus and exposure according to point
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
            }
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            print("Could not handle camera tap: \(error)")
        }
    }
    
    @IBAction func leftSwipe(_: UISwipeGestureRecognizer) {
        changeFPS(captureFPS / 2)
    }
    
    @IBAction func rightSwipe(_: UISwipeGestureRecognizer) {
        changeFPS(captureFPS * 2)
    }

    @IBAction func panChangeRate(_ sender: UIPanGestureRecognizer) {
        let velocity = sender.velocity(in: view)
        changeFPS(captureFPS - Double(velocity.y) / 1000)
    }
    
    func gestureRecognizer(_ gesture: UIGestureRecognizer, shouldBeRequiredToFailBy otherGesture: UIGestureRecognizer) -> Bool {
        let swipe = (gesture == leftSwipeRecog || gesture == rightSwipeRecog)
        return swipe && otherGesture == panRecog
    }

    @IBAction func toggleFlash(_: UIButton) {
        guard let device = captureDevice else { return }
        let torchMode: AVCaptureDevice.TorchMode = torchOn ? .off : .on
        let buttonColor: UIColor = torchOn ? .white : .yellow
        do {
            try device.lockForConfiguration()
            if hasTorch {
                device.torchMode = torchMode
                flashButton.setTitleColor(buttonColor, for: .normal)
                torchOn = !torchOn
            }
            device.unlockForConfiguration()
        } catch {
            print("Could not toggle flash: \(error)")
        }
    }
    
    func updateLabel() {
        if isHz {
            label.text = String(format: "%.2f Hz", captureFPS)
        } else {
            label.text = String(format: "%.0f RPM", captureFPS * 60)
        }
    }
    
    // MARK: - Capture Session
    
    func setupCaptureSession() {
        // get highest resolution formats in each frame rate range
        guard let device = captureDevice else { return }
        hasTorch = device.isTorchModeSupported(.on)
        let getDims = CMVideoFormatDescriptionGetDimensions
        let aspect = 16.0 / 9.0
        let captureSession = AVCaptureSession()
        formats = device.formats
        for format in formats {
            let height = getDims(format.formatDescription).height
            let fps = getMaxFPS(format)
            formats.removeAll { format2 in
                let dims2 = getDims(format2.formatDescription)
                let aspect2 = Double(dims2.width) / Double(dims2.height)
                let sameFPS = fps == getMaxFPS(format2)
                return sameFPS && (height > dims2.height || aspect != aspect2)
            }
        }
        formats.sort { getMaxFPS($0) < getMaxFPS($1) }
        fpsRange = (getMinFPS(formats.first!), getMaxFPS(formats.last!))
        
        // link capture device to capture session
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        guard captureSession.canAddInput(input) else { return }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .inputPriority
        captureSession.addInput(input)
        captureSession.commitConfiguration()
        
        // setup view layer
        previewLayer.session = captureSession
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = view.layer.frame
        captureSession.startRunning()
    }
    
    func changeFPS(_ newFPS: Double) {
        guard let device = captureDevice else { return }
        let fps = min(max(newFPS, fpsRange.0), fpsRange.1)
        do {
            // choose format
            try device.lockForConfiguration()
            let format = formats.first { fps <= getMaxFPS($0) }!
            if format != device.activeFormat {
                device.activeFormat = format
                if hasTorch { device.torchMode = torchOn ? .on : .off }
            }
            
            // update frame rate
            let frameTime = CMTimeMake(10000, Int32(fps * 10000))
            device.activeVideoMaxFrameDuration = frameTime
            device.activeVideoMinFrameDuration = frameTime
            captureFPS = fps
            device.unlockForConfiguration()
        } catch {
            print("Could not change FPS: \(error)")
        }
        updateLabel()
    }
    
    func getMinFPS(_ format: AVCaptureDevice.Format) -> Double {
        let range = format.videoSupportedFrameRateRanges[0]
        return range.minFrameRate
    }
    
    func getMaxFPS(_ format: AVCaptureDevice.Format) -> Double {
        let range = format.videoSupportedFrameRateRanges[0]
        return range.maxFrameRate
    }
}

