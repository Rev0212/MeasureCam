//
//  CameraModel.swift
//  MeasureCam
//
//  Created by admin29 on 17/11/24.
//


import AVFoundation
import Vision
import UIKit

class CameraModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var session = AVCaptureSession()
    private var bodyPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    private var permissionGranted = false
    private var isTpose: Bool = false
    private var capturedImage: UIImage?
    private var currentMeasurement: BodyMeasurement?
    private var isLoading = false
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    weak var delegate: CameraModelDelegate?
    
    var onTPoseUpdate: ((Bool) -> Void)?
    var onBodyPointsUpdate: (([VNHumanBodyPoseObservation.JointName: CGPoint]) -> Void)?
    var onLoadingStateChange: ((Bool) -> Void)?
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    func captureImage() {
        guard let connection = videoOutput.connection(with: .video) else { return }
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        connection.videoOrientation = .portrait
        updateLoadingState(true)
    }
    
    func stopCamera() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    private func setupCamera() {
        do {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                videoOutput.setSampleBufferDelegate(self, queue: queue)
                
                if let connection = videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                }
            }
            
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.session.startRunning()
            }
            
            permissionGranted = true
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    private func uploadMeasurement() {
        guard let image = capturedImage else { return }
        Task {
            do {
                let measurement = try await APIClient.shared.uploadMeasurement(image: image)
                DispatchQueue.main.async { [weak self] in
                    self?.currentMeasurement = measurement
                    self?.stopCamera()
                    self?.delegate?.navigateToMeasurePreview(measurement: measurement)
                }
            } catch {
                print("Error uploading measurement: \(error.localizedDescription)")
            }
            updateLoadingState(false)
        }
    }
    
    private func updateLoadingState(_ isLoading: Bool) {
        self.isLoading = isLoading
        onLoadingStateChange?(isLoading)
    }
}
