//
//  FirstViewController.swift
//  ArchaismDictionaryiOS
//
//  Created by Ognian Trajanov on 25.03.20.
//  Copyright © 2020 AR Learn. All rights reserved.
//

import UIKit
import AVFoundation
import Firebase
import FirebaseMLVision

class FirstViewController: UIViewController {
    
    @IBOutlet weak var ImageView: UIImageView!
    @IBOutlet weak var Значение: UILabel!
    @IBOutlet weak var Label: UILabel!
    @IBOutlet weak var Activity: UIActivityIndicatorView!
    
    @IBOutlet weak var Background: UIImageView!
    @IBOutlet weak var Instructions: UILabel!
    @IBOutlet weak var Instructions2: UILabel!
    @IBOutlet weak var Instructions3: UILabel!
    @IBOutlet weak var InstructionsImage: UIImageView!
    @IBOutlet weak var InstructionsImage2: UIImageView!
    
    let session = AVCaptureSession()
    var camera : AVCaptureDevice?
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    var cameraCaptureOutput: AVCapturePhotoOutput?
    var ocrResult: String = ""
    var finalResult: String = ""

    var dataBase = [[String]]()
    
    struct Welcome: Codable {
        let property1: [Property1]

        enum CodingKeys: String, CodingKey {
            case property1 = "Property1"
        }
    }

    struct Property1: Codable {
        let type: String
        let version, comment, name, database: String?
        let data: [Datum]?
    }

    struct Datum: Codable {
        let the0, the1: String
        let the2: JSONNull?
        let the3, id, word: String
        let synonym: JSONNull?
        let definition: String

        enum CodingKeys: String, CodingKey {
            case the0 = "0"
            case the1 = "1"
            case the2 = "2"
            case the3 = "3"
            case id, word, synonym, definition
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        InitializeCaptureSession()
        DictionaryManager()
        FirebaseApp.configure()
        Activity.hidesWhenStopped = true
        Activity.stopAnimating()
        
        let defaults: UserDefaults = UserDefaults.standard
        let understood = defaults.value(forKey: "understood") as? Bool
        
        if(understood != nil){
        Background.isHidden = true
        Instructions.isHidden = true
        Instructions2.isHidden = true
        Instructions3.isHidden = true
        InstructionsImage.isHidden = true
        InstructionsImage2.isHidden = true
        defaults.set(true, forKey: "understood")
        defaults.synchronize()
        }
    }
    
    func InitializeCaptureSession(){
        
        session.sessionPreset = AVCaptureSession.Preset.high
        camera = AVCaptureDevice.default(for: AVMediaType.video)
        
        do{
        let cameraCaptureInput = try AVCaptureDeviceInput(device: camera!)
            cameraCaptureOutput = AVCapturePhotoOutput()
            
            session.addInput(cameraCaptureInput)
            session.addOutput(cameraCaptureOutput!)
        } catch{
            print(error.localizedDescription)
        }
        
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraPreviewLayer?.frame = self.view.bounds
        cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        
        view.layer.insertSublayer(cameraPreviewLayer!, at: 0)
        session.startRunning()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if UIDevice.current.orientation.isLandscape {
            cameraPreviewLayer?.frame = self.view.bounds
                   cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
                           }
    }
        
    func TakePicture(){
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        cameraCaptureOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    func ScanPhoto(capturedPhoto: UIImage){
        
        Значение.text = "Моля изчакайте..."
        Activity.startAnimating()
        var filteredImage: UIImage
        filteredImage = capturedPhoto.imageRotatedByDegrees(degrees: 90, flip: false)
        filteredImage = filteredImage.toGrayScale()

        let vision = Vision.vision()
        let options = VisionCloudTextRecognizerOptions()
        options.languageHints = ["bg"]
        let textRecognizer = vision.cloudTextRecognizer(options: options)

        let visionImage = VisionImage(image: capturedPhoto)
        
        textRecognizer.process(visionImage) { result, error in
            guard error == nil, let result = result else {
            return
          }
            self.ocrResult = result.text
        }
        
        print(ocrResult)
        
            if(ocrResult != ""){
            
                let result = SearchInDictionary(input: ocrResult)
            
                if !result.isEmpty{
                
                let resultArr = result.split{$0 == " "}.map(String.init)
                Значение.text = resultArr[0].capitalizingFirstLetter()
                var array = ""
                let definitionLength = 1...resultArr.count - 1
                for i in definitionLength{
                    if(i == 1){
                    array += resultArr[i].capitalizingFirstLetter() + " "
                    }
                    else{
                    array += resultArr[i] + " "
                    }
                }
                Label.text = array
                }
        }
        Activity.stopAnimating()
}
    
    func DictionaryManager()
    {
        let urlString = "http://www.archaismdictionary.bg/json_manager.php"
        guard let url = URL(string: urlString) else{
            print("Error")
            return
        }
        do {
            let jsonString = try String(contentsOf: url)
            let data = Data(jsonString.utf8)
            let decoder = JSONDecoder()
            let dataParsed = try decoder.decode(Welcome.self, from: data)
            
            let size = dataParsed.property1[2].data?.count
            let count = 0...size! - 1
            
            dataBase = Array(repeating: Array(repeating: "default", count: 2), count: size!)
            
            for number in count{
                      dataBase[number][0] = dataParsed.property1[2].data?[number].word ?? "<no word>"
                      dataBase[number][1] = dataParsed.property1[2].data?[number].definition ?? "<no word>"
            }
        }
        catch let error as NSError{
            print("Error: \(error)")
        }
    }
    
        func SearchInDictionary(input: String) -> String{
            
            let size = dataBase.count
            var result: String = ""

            print(input)

            if(size > 0){
                let resultArr = input.split{[" ", "\n"].contains($0.description)}.map(String.init)
            let sizeArr = resultArr.count
            let countArr = 0...sizeArr-1
            let count = 0...size - 1
            
                for word in countArr{
                    if(result == ""){
                for number in count{
                    if(resultArr[word].lowercased() == dataBase[number][0].lowercased()){
                    result = dataBase[number][0] + " " + dataBase[number][1]
                }
                    }
                    }
                }
                if(result == ""){
                    result = "Грешка: Не засякахме дума, която е в речника."
                }
            }
    return result
    }
    
    @IBAction func Button(_ sender: UIButton) {
        let defaults: UserDefaults = UserDefaults.standard
        let understood = defaults.value(forKey: "understood") as? Bool
        
        if(understood == nil){
        Background.isHidden = true
        Instructions.isHidden = true
        Instructions2.isHidden = true
        Instructions3.isHidden = true
        InstructionsImage.isHidden = true
        InstructionsImage2.isHidden = true
        defaults.set(true, forKey: "understood")
        defaults.synchronize()
        }
            
        else{
        TakePicture()
        }
    }
}

extension FirstViewController : AVCapturePhotoCaptureDelegate
{
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let unwrappedError = error{
               print(unwrappedError.localizedDescription)
           }
           else{
            if let sampleBuffer = photoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer){
                
                if let finalImage = UIImage(data: dataImage){
                    ScanPhoto(capturedPhoto: finalImage)
                }
            }
           }
    }
}

class ImagePreview: FirstViewController{
    var capturedImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ImageView.image = capturedImage
    }
}

extension UIImage {

    public func imageRotatedByDegrees(degrees: CGFloat, flip: Bool) -> UIImage {
        let radiansToDegrees: (CGFloat) -> CGFloat = {
            return $0 * (180.0 / CGFloat.pi)
        }
        let degreesToRadians: (CGFloat) -> CGFloat = {
            return $0 / 180.0 * CGFloat.pi
        }

        // calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox = UIView(frame: CGRect(origin: .zero, size: size))
        let t = CGAffineTransform(rotationAngle: degreesToRadians(degrees));
        rotatedViewBox.transform = t
        let rotatedSize = rotatedViewBox.frame.size

        // Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap = UIGraphicsGetCurrentContext()

        // Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap?.translateBy(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0)

        //   // Rotate the image context
        bitmap?.rotate(by: degreesToRadians(degrees))

        // Now, draw the rotated/scaled image into the context
        var yFlip: CGFloat

        if(flip){
            yFlip = CGFloat(-1.0)
        } else {
            yFlip = CGFloat(1.0)
        }

        bitmap?.scaleBy(x: yFlip, y: -1.0)
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)

        bitmap?.draw(cgImage!, in: rect)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
    func toGrayScale() -> UIImage {

          let greyImage = UIImageView()
          greyImage.image = self
          let context = CIContext(options: nil)
          let currentFilter = CIFilter(name: "CIPhotoEffectNoir")
          currentFilter!.setValue(CIImage(image: greyImage.image!), forKey: kCIInputImageKey)
          let output = currentFilter!.outputImage
          let cgimg = context.createCGImage(output!,from: output!.extent)
          let processedImage = UIImage(cgImage: cgimg!)
          greyImage.image = processedImage

          return greyImage.image!
      }
}
