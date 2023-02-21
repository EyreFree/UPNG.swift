//
//  ViewController.swift
//  UPNG.swift
//
//  Created by EyreFree on 11/22/2022.
//  Copyright (c) 2022 EyreFree. All rights reserved.
//

import UIKit
import EFFoundation
import UPNG_swift
import Messages
import SnapKit
import Photos

class ViewController: UIViewController {
    
    var currentIsPng: Bool = true
    
    private var oriPNGUrl: URL?
    private var oriAPNGUrl: URL?
    
    private var resultImageUrl: URL?
    
    lazy var beforePNGView: MSStickerView = {
        var stickerView = MSStickerView()
        stickerView.layer.borderColor = UIColor.gray.cgColor
        stickerView.layer.borderWidth = 0.5
        stickerView.isUserInteractionEnabled = false
        return stickerView
    }()
    
    lazy var changeButton: UIButton = {
        var button = UIButton()
        button.layer.borderColor = UIColor.gray.cgColor
        button.layer.borderWidth = 0.5
        button.setTitle("Change")
        button.setTitleColor(UIColor.black)
        button.addTouchUpInsideHandler { [weak self] controle in
            guard let self = self else { return }
            
            self.currentIsPng = !self.currentIsPng
            self.changeAction()
        }
        return button
    }()
    
    lazy var actionButton: UIButton = {
        var button = UIButton()
        button.layer.borderColor = UIColor.gray.cgColor
        button.layer.borderWidth = 0.5
        button.setTitle("Action")
        button.setTitleColor(UIColor.black)
        button.addTouchUpInsideHandler { [weak self] controle in
            guard let self = self else { return }
            
            button.isEnabled = false
            
            self.afterPNGView.stopAnimating()
            self.afterPNGView.sticker = nil
            if self.currentIsPng {
                self.pngTest()
            } else {
                self.apngTest()
            }
        }
        return button
    }()
    
    lazy var saveButton: UIButton = {
        var button = UIButton()
        button.layer.borderColor = UIColor.gray.cgColor
        button.layer.borderWidth = 0.5
        button.setTitle("Save Result")
        button.setTitleColor(UIColor.black)
        button.addTouchUpInsideHandler { [weak self] controle in
            guard let self = self else { return }
            
            self.saveToAlbum()
        }
        return button
    }()
    
    lazy var afterPNGView: MSStickerView = {
        var stickerView = MSStickerView()
        stickerView.layer.borderColor = UIColor.gray.cgColor
        stickerView.layer.borderWidth = 0.5
        stickerView.isUserInteractionEnabled = false
        return stickerView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(beforePNGView)
        beforePNGView.snp.makeConstraints { make in
            make.left.equalTo(10)
            make.right.equalTo(-10)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(10)
        }
        
        self.view.addSubview(changeButton)
        changeButton.snp.makeConstraints { make in
            make.left.equalTo(10)
            make.top.equalTo(beforePNGView.snp.bottom).offset(10)
            make.height.equalTo(60)
        }
        
        self.view.addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.left.equalTo(changeButton.snp.right).offset(10)
            make.top.equalTo(beforePNGView.snp.bottom).offset(10)
            make.height.equalTo(60)
        }
        
        self.view.addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            make.left.equalTo(actionButton.snp.right).offset(10)
            make.top.equalTo(beforePNGView.snp.bottom).offset(10)
            make.height.equalTo(60)
            make.right.equalTo(-10)
            make.width.equalTo(changeButton)
            make.width.equalTo(actionButton)
        }
        
        self.view.addSubview(afterPNGView)
        afterPNGView.snp.makeConstraints { make in
            make.top.equalTo(actionButton.snp.bottom).offset(10)
            make.left.equalTo(10)
            make.right.equalTo(-10)
            make.height.equalTo(beforePNGView)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-10)
        }
        
        if let pngUrl = Bundle.main.url(forResource: "png", withExtension: "data"), let pngData = try? Data(contentsOf: pngUrl), let pngFileUrl = self.saveImageFile(imageData: pngData) {
            oriPNGUrl = pngFileUrl
        }
        if let apngUrl = Bundle.main.url(forResource: "apng", withExtension: "data"), let apngData = try? Data(contentsOf: apngUrl), let apngFileUrl = self.saveImageFile(imageData: apngData) {
            oriAPNGUrl = apngFileUrl
        }
        
        changeAction()
    }
    
    func changeAction() {
        self.beforePNGView.stopAnimating()
        self.afterPNGView.stopAnimating()
        self.afterPNGView.sticker = nil
        
        let pngUrl = {
            if currentIsPng {
                return oriPNGUrl
            } else {
                return oriAPNGUrl
            }
        }()
        
        if let pngUrl = pngUrl {
            self.beforePNGView.sticker = try? MSSticker(contentsOfFileURL: pngUrl, localizedDescription: "png")
            self.beforePNGView.startAnimating()
        }
    }
    
    func showNewResult(fileUrl: URL) {
        self.afterPNGView.sticker = try? MSSticker(contentsOfFileURL: fileUrl, localizedDescription: "png")
        self.afterPNGView.startAnimating()
        
        resultImageUrl = fileUrl
    }
    
    func pngTest() {
        printLog("png:")
        // put static png in .xcassets
        if let pngImageData = {
            if let pngUrl = oriPNGUrl {
                return try? Data(contentsOf: pngUrl)
            }
            return nil
        }() {
            sizeOfData(data: pngImageData)
            UPNG.shared.optimize(imageData: pngImageData) { [weak self] data, error in
                guard let self = self else { return }
                
                if let data = data {
                    self.sizeOfData(data: data)
                    
                    if let fileUrl = self.saveImageFile(imageData: data) {
                        self.showNewResult(fileUrl: fileUrl)
                    }
                } else {
                    printLog(error?.localizedDescription ?? "Unknown")
                }
                
                DispatchQueue.main.async {
                    self.actionButton.isEnabled = true
                }
            }
        }
    }
    
    func apngTest() {
        printLog("apng:")
        // put apng in bundle
        if let apngImageData = {
            if let apngUrl = oriAPNGUrl {
                return try? Data(contentsOf: apngUrl)
            }
            return nil
        }() {
            sizeOfData(data: apngImageData)
            UPNG.shared.optimize(imageData: apngImageData, compressionLevel: 200) { [weak self] data, error in
                guard let self = self else { return }
                
                if let data = data {
                    self.sizeOfData(data: data)
                    
                    if let fileUrl = self.saveImageFile(imageData: data) {
                        self.showNewResult(fileUrl: fileUrl)
                    }
                } else {
                    printLog(error?.localizedDescription ?? "Unknown")
                }
                
                self.actionButton.isEnabled = true
            }
        }
    }
    
    func sizeOfData(data: Data) {
        func textToPrint() -> String {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useKB]
            bcf.countStyle = .file
            let string = bcf.string(fromByteCount: Int64(data.count))
            return "dataSizeKB: \(string)"
        }
        printLog(textToPrint())
    }
    
    func saveImageFile(imageData: Data, with name: String = "\(Date().timeIntervalSince1970).png") -> URL? {
        let fileManager = FileManager.default
        do {
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = documentDirectory.appendingPathComponent(name)
            try imageData.write(to: fileURL)
            return fileURL
        } catch {
            printLog(error.localizedDescription)
            return nil
        }
    }
    
    func saveToAlbum() {
        guard let stickerUrl = self.resultImageUrl else { return }
        
        PHPhotoLibrary.shared().performChanges ({
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: stickerUrl)
        }) { saved, error in
            DispatchQueue.main.async { [weak self] in
                guard let _ = self else { return }
                if saved {
                    printLog("Your image was successfully saved")
                } else {
                    printLog("Your image save failed")
                }
            }
        }
    }
}
