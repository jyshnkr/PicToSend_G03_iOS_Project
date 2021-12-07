//  ViewController.swift
//  PicToSend App
//  Created by JayaShankar Mangina on 11/23/21.


import MultipeerConnectivity
import UIKit

    //MARK: 1 - Protocols for ImagePicker & MultiPeer Connectivity Framework

    /*
    1 - Added UIImagePickerControllerDelegate & UINavigationControllerDelegate protocols
    These are required to handle the callBacks of UIImagePickerController

    2 - Added MCSessionDelegate & MCBrowserViewControllerDelegate protocols
    These are required to handle the functions of Multipeer Connectivity
    */

class ViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate {
    
    //Initialized images variable and assigned to an array of UIImage
	var images = [UIImage]()
    
    //Declared the Variables required for the MPC framwework
	var peerID: MCPeerID!
	var mcSession: MCSession!
	var mcAdvertiserAssistant: MCAdvertiserAssistant!

	override func viewDidLoad() {
		super.viewDidLoad()

        //Navigation Title
		title = "PicToSend"
        
        //LeftBarButton Items
        let leftBarButtonOne = UIBarButtonItem(image: UIImage(named: "info SVG"), style: .plain, target: self, action: #selector(showConectedDevices))
        let LeftBarButtonTwo = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showConnectionPrompt))
        
        //RightBarButtonItems
        let RightBarButtonOne = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(sendMessage))
		let RightBarButtonTwo = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importPicture))
        
        //Arrays for Both Left and Right BarButtonItems
        navigationItem.leftBarButtonItems = [LeftBarButtonTwo, leftBarButtonOne]
        navigationItem.rightBarButtonItems = [RightBarButtonTwo, RightBarButtonOne]
        
        //We have declared peerID here with MCPeerID method,
        //this is how the device will be visible/shown to others on the session
		peerID = MCPeerID(displayName: UIDevice.current.name)
        
        //Injected PeerID into the MCSession Method
		mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        
        //Delegate
        mcSession.delegate = self
	}
    
    //MARK: 2 - Functions (@objc) for all the navigation Buttons
    
    @objc func importPicture() {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc func showConectedDevices(){
        let alert = UIAlertController(title: "Connected Devices", message: "\(mcSession.connectedPeers)", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: { (ACTION) in
            alert.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
        print(mcSession.connectedPeers)
        
    }
    
    @objc func sendMessage(){
        msgAlertController()
    }
    
    @objc func showConnectionPrompt() {
        let ac = UIAlertController(title: "Connect to others", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Host a session", style: .default, handler: startHosting))
        ac.addAction(UIAlertAction(title: "Join a session", style: .default, handler: joinSession))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }

    //MARK: 3 - CollectionView Methods
    
    /*
     1. Returns the Numbers of images in our image array
     */
    
	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return images.count
	}

    /*
     2.We gave a tag of 1000 to the resuable collectionView cell in the IB Storyboard
     The Reason is the subclasses have a method called viewWithTag, which searches from any views,
     inside itself/ within itself with the tag number. So we can find our imageView just by using,
     this method.
     */

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageView", for: indexPath)

		if let imageView = cell.viewWithTag(1000) as? UIImageView {
			imageView.image = images[indexPath.item]
		}

		return cell
	}
    
    //MARK: 4 - Functions
    
    /*
     3.ImagePicker Delegate method that handles the aftermath of picking an image. That is, after picking the image from image picker,
     it checks whether the image is edited image (else it will break the guard let loop), then we dismiss the current controller,
     through dismiss animation. The selected image will then be imported into the 'imageView' - resuable identifier cell of collectionView
     at the index 0 and the collectionView, pops up the image with the reloadData() method (kind of refreshing the collectionView)
     */
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		guard let image = info[.editedImage] as? UIImage else { return }

		dismiss(animated: true)

		images.insert(image, at: 0)
		collectionView?.reloadData()

		if mcSession.connectedPeers.count > 0 {

			if let imageData = image.pngData() {

				do {
					try mcSession.send(imageData, toPeers: mcSession.connectedPeers, with: .reliable)
				} catch {
					let ac = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
					ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
					present(ac, animated: true)
				}
			}
		}
	}
    
    /*
     4. Function for the msgAlertController() , that creates an UIALertController to send a message
     */
    
    func msgAlertController(){
        let msgAlertPrompt = UIAlertController(title: "Chat with Friends", message: "Type the message below", preferredStyle: .alert)
        
        msgAlertPrompt.addTextField { (textField) in
            textField.placeholder = "Type your message"
        }
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        let sendButton = UIAlertAction(title: "Send", style: .default) { [weak msgAlertPrompt] _ in
            guard let textFields = msgAlertPrompt?.textFields else {return}
            if let messageTextField = textFields[0].text {
                self.sendTextMessage(data: "\(messageTextField)")
            }
        }
        msgAlertPrompt.addAction(sendButton)
        msgAlertPrompt.addAction(cancelButton)
        DispatchQueue.main.async {
            self.present(msgAlertPrompt, animated: true, completion: nil)
        }
    }

    // Function to send the text message to all the connected peers in a session
    func sendTextMessage(data: String){
        if mcSession.connectedPeers.count > 0 {
            if let messageData = data.data(using: .utf8){
                do {
                    try mcSession.send(messageData, toPeers: mcSession.connectedPeers, with: .reliable)
                } catch let error as NSError {
                    print(error.localizedDescription)
                }
            }
        }
    }

    //Function to start the Session hosting
	func startHosting(action: UIAlertAction) {
		mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "PicToSend", discoveryInfo: nil, session: mcSession)
		mcAdvertiserAssistant.start()
	}

    //Function to join the session
	func joinSession(action: UIAlertAction) {
		let mcBrowser = MCBrowserViewController(serviceType: "PicToSend", session: mcSession)
		mcBrowser.delegate = self
		present(mcBrowser, animated: true)
	}
    
    
    //Function to show the message as an Alert on Receiver's side
    func messageAlert(title:String, message:String) {
        let errorAlert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        
        errorAlert.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: { (ACTION) in
            errorAlert.dismiss(animated: true, completion: nil)
        }))
        self.present(errorAlert, animated: true, completion: nil)
    }
    
    //MARK: 5 - These are the 7 methods facilitated by both the MCBrowserViewControllerDelegate & MCSessionDelegate protocols
    
    /*
     1. Three of these methods are not essential as of now for our app .
     */

	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {

	}

	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {

	}

	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {

	}
    
    /*
     2. These two methods are the MCBrowserViewController protocols stubs, which provides implementations for cancellation and finishing
     */
    
	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		dismiss(animated: true)
	}

	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		dismiss(animated: true)
	}
    
    /*
     3. These two methods are essential that manages the core functionality of our app.
        a) When the user joins/leaves/connecting to the session, the didChange Method gets called
     */

	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		switch state {
		case MCSessionState.connected:
			print("Connected: \(peerID.displayName)")

		case MCSessionState.connecting:
			print("Connecting: \(peerID.displayName)")

		case MCSessionState.notConnected:
			print("Not Connected: \(peerID.displayName)")
        @unknown default:
            fatalError()
        }
        
	}

    /*
     3. b) This method helps to catch the data the app receives, processes it and add to the collectionView,
           on receiver's side.
     */
    
	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        //For image
		if let image = UIImage(data: data) {
			DispatchQueue.main.async { [unowned self] in
				self.images.insert(image, at: 0)
				self.collectionView?.reloadData()
			}
		}
        
        // For Text Message
        if let text = String(data: data, encoding: .utf8){
            DispatchQueue.main.sync {
                messageAlert(title: "You got a New Message!", message: "\(text)")
            }
        }
	}


    
}

