//
//  CameraViewController.swift
//  MeasureCam
//
//  Created by admin29 on 17/11/24.
//


import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {
    private var cameraModel: CameraModel!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var skeletonLayer: CAShapeLayer!
    private var captureButton: UIButton!
    private var loadingIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCameraModel()
    }
    
    private func setupUI() {
        setupPreviewLayer()
        setupSkeletonLayer()
        setupCaptureButton()
        setupLoadingIndicator()
        setupConstraints()
    }
    
    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    private func setupSkeletonLayer() {
        skeletonLayer = CAShapeLayer()
        skeletonLayer.fillColor = nil
        skeletonLayer.strokeColor = UIColor.red.cgColor
        skeletonLayer.lineWidth = 3
        view.layer.addSublayer(skeletonLayer)
    }
    
    private func setupCaptureButton() {
        captureButton = UIButton(type: .system)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.setImage(UIImage(systemName: "camera.circle.fill"), for: .normal)
        captureButton.tintColor = .white
        captureButton.transform = CGAffineTransform(scaleX: 3.0, y: 3.0)
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        captureButton.isHidden = true
        view.addSubview(captureButton)
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupCameraModel() {
        cameraModel = CameraModel()
        cameraModel.delegate = self
        previewLayer.session = cameraModel.session
        
        setupCameraCallbacks()
        cameraModel.checkPermission()
    }
    
    private func setupCameraCallbacks() {
        cameraModel.onTPoseUpdate = { [weak self] isTpose in
            DispatchQueue.main.async {
                self?.captureButton.isHidden = !isTpose
                self?.skeletonLayer.strokeColor = isTpose ? UIColor.green.cgColor : UIColor.red.cgColor
            }
        }
        
        cameraModel.onBodyPointsUpdate = { [weak self] points in
            self?.updateSkeletonLayer(with: points)
        }
        
        cameraModel.onLoadingStateChange = { [weak self] isLoading in
            DispatchQueue.main.async {
                if isLoading {
                    self?.loadingIndicator.startAnimating()
                } else {
                    self?.loadingIndicator.stopAnimating()
                }
            }
        }
    }
    
    @objc private func captureButtonTapped() {
        cameraModel.captureImage()
    }
    
    private func updateSkeletonLayer(with points: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        let path = UIBezierPath()
        for (start, end) in SkeletonConnections.connections {
            guard let startPoint = points[start],
                  let endPoint = points[end] else { continue }
            
            let scaledStart = CGPoint(
                x: startPoint.x * view.bounds.width,
                y: startPoint.y * view.bounds.height
            )
            let scaledEnd = CGPoint(
                x: endPoint.x * view.bounds.width,
                y: endPoint.y * view.bounds.height
            )
            
            path.move(to: scaledStart)
            path.addLine(to: scaledEnd)
        }
        
        skeletonLayer.path = path.cgPath
    }
}

extension CameraViewController: CameraModelDelegate {
    func navigateToMeasurePreview(measurement: BodyMeasurement) {
        let measurePreviewVC = MeasurePreviewViewController()
        measurePreviewVC.fetchedMeasurements = measurement
        navigationController?.pushViewController(measurePreviewVC, animated: true)
    }
}
