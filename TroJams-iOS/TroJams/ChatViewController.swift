//
//  ChatViewController.swift
//  JamSesh
//
//  Created by Adam Moffitt on 5/26/17.
//  Copyright © 2017 Adam's Apps. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {

   
    let SharedJamSeshModel = JamSeshModel.shared
    var chatRef : DatabaseReference?
    
    var messages = [JSQMessage]()
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    private lazy var messageRef: DatabaseReference = self.chatRef!.child("messages")
    private var newMessageRefHandle: DatabaseHandle?
    
    
    private lazy var userIsTypingRef: DatabaseReference =
        self.chatRef!.child("typingIndicator").child(self.senderId) // 1
    private var localTyping = false // 2
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            // 3
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    
    private lazy var usersTypingQuery: DatabaseQuery =
        self.chatRef!.child("typingIndicator").queryOrderedByValue().queryEqual(toValue: true)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("chat view did load")
        
        self.senderId = Auth.auth().currentUser?.uid
        // No avatars
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        observeMessages()
        print("end chat view did load")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("chat view did appear")
        super.viewDidAppear(animated)
        observeTyping()
        print("end chat view did appear")
    }
    
    /*****************************************************************************/
    deinit {
        
        if let refHandle = newMessageRefHandle {
            SharedJamSeshModel.ref.removeObserver(withHandle: refHandle)
        }
        
        
    }
    /*****************************************************************************/
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
    
        print("chat did press send")
        let itemRef = messageRef.childByAutoId() // 1
        let messageItem = [ // 2
            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": text!,
            ]
        
        itemRef.setValue(messageItem) // 3
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound() // 4
        
        finishSendingMessage() // 5
        isTyping = false
        print("end chat did press send")
    }
    
    private func observeMessages() {
        print("chat observe messages")
        messageRef = (chatRef?.child("messages"))!
        // 1.
        let messageQuery = messageRef.queryLimited(toLast:25)
        
        // 2. We can use the observe method to listen for new
        // messages being written to the Firebase DB
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            // 3
            let messageData = snapshot.value as! Dictionary<String, String>
            
            if let id = messageData["senderId"] as String!, let name = messageData["senderName"] as String!, let text = messageData["text"] as String!, text.characters.count > 0 {
                // 4
                self.addMessage(withId: id, name: name, text: text)
                
                // 5
                self.finishReceivingMessage()
            } else {
                print("Error! Could not decode message data")
            }
        })
        print("end chat observe messages")
    }
    
    private func addMessage(withId id: String, name: String, text: String) {
        print("chat add message")
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            messages.append(message)
        }
        print("end chat add message")
    }
 
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item] // 1
        if message.senderId == senderId { // 2
            return outgoingBubbleImageView
        } else { // 3
            return incomingBubbleImageView
        }
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
 
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        // If the text is not empty, the user is typing
        isTyping = textView.text != ""
    }
    
    private func observeTyping() {
        let typingIndicatorRef = self.chatRef?.child("typingIndicator")
        userIsTypingRef = (typingIndicatorRef?.child(senderId))!
        userIsTypingRef.onDisconnectRemoveValue()

    // 1
    usersTypingQuery.observe(.value) { (data: DataSnapshot) in
    // 2 You're the only one typing, don't show the indicator
    if data.childrenCount == 1 && self.isTyping {
    return
    }
    
    // 3 Are there others typing?
    self.showTypingIndicator = data.childrenCount > 0
    self.scrollToBottom(animated: true)
    }
    }
}
