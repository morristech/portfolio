//
//  JamSeshModel.swift
//  JamSesh
//
//  Created by Adam Moffitt on 1/24/17.
//  Copyright © 2017 Adam's Apps. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseAuth
import FirebaseStorage

class JamSeshModel {
    
    var parties : [Party] = []
    var currentPartyIndex: Int = 0
    var ref: FIRDatabaseReference!
    var partiesChanged = true
    var storage : FIRStorage
    var storageRef : FIRStorageReference
    var myUser : User
    
    //singleton
    static var shared = JamSeshModel()
    
    init() {
        print("Initializing JamSesh model")
        ref = FIRDatabase.database().reference()
        
        // Get a reference to the storage service using the default Firebase App
        storage = FIRStorage.storage()
        // Create a storage reference from our storage service
        storageRef = storage.reference()
        
        myUser = User()
        
        //loadFromFirebase(completionHandler: {_ in print("yaaaaaaaas")})
        
    }
    
    func newParty(name: String , partyImage: UIImage, privateParty: Bool, password: String, numberJoined: Int, hostName: String, hostID: String) {
        
        //add new party to firebase
        let partyID = NSUUID().uuidString
        
        //upload image
        let tempImageName = NSUUID().uuidString
        let tempStorageRef = storageRef.child("\(tempImageName).png")
        var tempSavedImageURL = ""
        if let uploadData = UIImageJPEGRepresentation(partyImage, 1.0) {
            tempStorageRef.put(uploadData, metadata: nil, completion: { (metadata, error) in
                if error != nil {
                    print (error)
                    return
                }
                
                //save the firebase image url in order to download the image later
                tempSavedImageURL = (metadata?.downloadURL()?.absoluteString)!
                
                let newParty = Party(name: name , partyID: partyID, partyImage: partyImage, savedImageURL: tempSavedImageURL, privateParty: privateParty, password: password, numberJoined: numberJoined, partyPlaylist: [], hostName: hostName, hostID: hostID, users: [self.myUser.username])
                
                //upload to firebase
                self.ref.child("parties").child(partyID).setValue(newParty.toAnyObject())
                print("uploaded party")
                //pull from firebase to make new party and add to local parties
                self.ref.child("parties").queryEqual(toValue: partyID).observeSingleEvent(of: .value, with: { (snapshot) in
                    let p = Party(snapshot: snapshot)
                    self.parties.append(p)
                    print("appended \(p.partyName)")
                }){ (error) in
                    print(error.localizedDescription)
                }

                
            })
        } else {
            let newParty = Party(name: name , partyID: partyID, partyImage: partyImage, savedImageURL: tempSavedImageURL, privateParty: privateParty, password: password, numberJoined: numberJoined, partyPlaylist: [], hostName: hostName, hostID: hostID, users: [self.myUser.username])
            
            //upload to firebase
            self.ref.child("parties").child(partyID).setValue(newParty.toAnyObject())
            
            //pull from firebase to make new party and add to local parties
            self.ref.child("parties").queryEqual(toValue: partyID).observeSingleEvent(of: .value, with: { (snapshot) in
                let p = Party(snapshot: snapshot)
                self.parties.append(p)
                print("appended \(p.partyName)")
                    }){ (error) in
                        print(error.localizedDescription)
            }
        }
    }
    
    func setPartySong(song: Song) {
        
        //set current song on firebase
        ref.child("parties").child(parties[currentPartyIndex].partyID).child("currentSong").setValue(song.toAnyObject())
    
        //remove song from playlist on firebase
        ref.child("parties").child(parties[currentPartyIndex].partyID).child("playlist").child(encodeForFirebaseKey(string: song.songName)).removeValue()
        
        //set current song locally
        parties[currentPartyIndex].setCurrentSong(songId: String(describing: song.songID))
        
    }
    
    typealias CompletionHandler = (_ success:Bool) -> Void
    
    /******************* New load from firebase - observe *******************/
    func loadFromFirebase(completionHandler: @escaping CompletionHandler) {
        ref.child("parties").queryOrdered(byChild: "numberJoined").observe(FIRDataEventType.value, with: { (snapshot) in
            if !snapshot.exists() {
                print("snapshot of parties doesnt exist")
                return
            }
            var newParties : [Party] = []
            for child in (snapshot.children.allObjects as? [FIRDataSnapshot])! {
                print("LOADFROMFIREBASE \((child.value as? NSDictionary)?["partyName"])")
                let party = Party(snapshot: child as! FIRDataSnapshot)
                newParties.append(party)
            }
            self.parties = newParties
        })
        completionHandler(true)
    }
    /****************************************************************************/
    
    func setMyUser(newUser: User) {
        myUser = newUser
    }
    
    func addNewUser(newUser: User) {
        print("add new user")
        ref.child("users").child(newUser.userID).setValue(newUser.toAnyObject())
    }
    
    //update the numberJoined and playlist of the party
    func updateParty(party: Party, completionHandler: @escaping CompletionHandler) {
        print("update dis partay")
        
            ref.child("parties").child(party.partyID).child("numberJoined").setValue(party.numberJoined)
            ref.child("parties").child(party.partyID).updateChildValues(party.playlistToAnyObject() as! [AnyHashable : Any])
        
        print("partay updated")
        completionHandler(true)
    }
    
    func encodeForFirebaseKey(string: String) -> (String){
        var string1 = string.replacingOccurrences(of: "_", with: "__")
        string1 = string1.replacingOccurrences(of: ".", with: "_P")
        string1 = string1.replacingOccurrences(of: "$", with: "_D")
        string1 = string1.replacingOccurrences(of: "#", with: "_H")
        string1 = string1.replacingOccurrences(of: "[", with: "_O")
        string1 = string1.replacingOccurrences(of: "]", with: "_C")
        string1 = string1.replacingOccurrences(of: "/", with: "_S")
        return string1
    }

    func decodeFromFireBaseKey (string: String) -> (String) {
        var string1 = string.replacingOccurrences(of: "__" , with: "_")
        string1 = string1.replacingOccurrences(of: "_P", with: ".")
        string1 = string1.replacingOccurrences(of: "_D", with: "$")
        string1 = string1.replacingOccurrences(of: "_H", with: "#")
        string1 = string1.replacingOccurrences(of: "_O", with: "[")
        string1 = string1.replacingOccurrences(of: "_C", with: "]")
        string1 = string1.replacingOccurrences(of: "_S", with: "/")
        return string1
    }
}

    
