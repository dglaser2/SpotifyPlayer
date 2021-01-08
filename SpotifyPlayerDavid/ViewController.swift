//
//  ViewController.swift
//  SpotifyPlayerDavid
//
//  Created by David Glaser on 12/31/20.
//

import UIKit
import Alamofire

class ViewController: UIViewController, SPTSessionManagerDelegate, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    
    
    @IBOutlet var albumArtwork: UIImageView!
    @IBOutlet var songTitleLabel: UILabel!
    @IBOutlet var albumNameLabel: UILabel!
    @IBOutlet var artistNameLabel: UILabel!
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var playPauseButton: UIButton!
    @IBOutlet var rwButton: UIButton!
    @IBOutlet var ffButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViewBasedOnConnected()
    }
    
    // MARK: - Actions
    
    @IBAction func didTapConnect(_ sender: Any) {
        if (appRemote.isConnected) == false {
            print("connect was tapped")
            /*
             Scopes let you specify exactly what types of data your application wants to
             access, and the set of scopes you pass in your call determines what access
             permissions the user is asked to grant.
             For more information, see https://developer.spotify.com/web-api/using-scopes/.
             */
            if #available(iOS 11, *) {
                sessionManager.initiateSession(with: scopes, options: .default)
            } else {
                sessionManager.initiateSession(with: scopes, options: .default, presenting: self)
            }
        } else {
            appRemote.disconnect()
        }
    }
    
    @IBAction func didTapPausePlay(_ sender: Any) {
        print("play was tapped")
        if let lastPlayerState = lastPlayerState, lastPlayerState.isPaused {
            appRemote.playerAPI?.resume(nil)
        } else {
            appRemote.playerAPI?.pause(nil)
        }
    }
    @IBAction func didTapRewind(_ sender: Any) {
        print("rw was tapped")
    }
    @IBAction func didTapFastForward(_ sender: Any) {
        print("ff was tapped")
    }
    
    
    // MARK: - Spotify
    
    let spotifyClientID = "a7ce2bb1ba3d4e62a8c60eb091a4e9c5"
    let spotifyRedirectURL = URL(string: "davidplayer://callback")!
    var accessToken = ""
    let scopes: SPTScope = [.appRemoteControl]

    
    lazy var configuration: SPTConfiguration = {
        let configuration = SPTConfiguration(clientID: spotifyClientID,
                                             redirectURL: spotifyRedirectURL)
        configuration.playURI = "spotify:track:20I6sIOMTCkB6w7ryavxtO"
//        configuration.tokenSwapURL = URL(string: "http://localhost:1234/swap")
        // https://spotify-token-swap.glitch.me/api/token
//        configuration.tokenRefreshURL = URL(string: "http://localhost:1234/refresh")
        // https://spotify-token-swap.glitch.me/api/refresh_token
        return configuration
    }()
    
    lazy var sessionManager: SPTSessionManager = {
        let manager = SPTSessionManager(configuration: self.configuration, delegate: self)
        return manager
    }()
    
    lazy var appRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(configuration: self.configuration, logLevel: .debug)
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()
    
    
    func updateViewBasedOnConnected() {
        if (appRemote.isConnected) {
            connectButton.setTitle("Disconnect from Spotify", for: .normal)
            albumArtwork.isHidden = false
            songTitleLabel.isHidden = false
            artistNameLabel.isHidden = false
            albumNameLabel.isHidden = false
            playPauseButton.isHidden = false
            rwButton.isHidden = false
            ffButton.isHidden = false
        } else {
            connectButton.setTitle("Connect to Spotify", for: .normal)
            albumArtwork.isHidden = true
            songTitleLabel.isHidden = true
            artistNameLabel.isHidden = true
            albumNameLabel.isHidden = true
            playPauseButton.isHidden = true
            rwButton.isHidden = true
            ffButton.isHidden = true
        }
    }
    
    private var lastPlayerState: SPTAppRemotePlayerState?
    
    
    func update(playerState: SPTAppRemotePlayerState) {
        if lastPlayerState?.track.uri != playerState.track.uri {
            fetchAlbumArtwork(for: playerState.track)
        }
        lastPlayerState = playerState
        songTitleLabel.text = playerState.track.name
        if playerState.isPaused {
            playPauseButton.setImage(UIImage(named: "play"), for: .normal)
        } else {
            playPauseButton.setImage(UIImage(named: "pause"), for: .normal)
        }
    }
    
    func fetchPlayerState() {
        appRemote.playerAPI?.getPlayerState({ [weak self] (playerState, error) in
            if let error = error {
                print("Error in fetching player state" + error.localizedDescription)
            } else if let playerState = playerState as? SPTAppRemotePlayerState {
                self?.update(playerState: playerState)
            }
        })
    }
    
    func fetchAlbumArtwork(for track: SPTAppRemoteTrack) {
        appRemote.imageAPI?.fetchImage(forItem: track, with: CGSize.zero, callback: { [weak self] (image, error) in
            if let error = error {
                print("error fetching album artwork" + error.localizedDescription)
            } else if let image = image as? UIImage {
                self?.albumArtwork.image = image
            }
        })
    }
    
    
    
    // MARK: - SPTSessionManagerDelegate
    
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        appRemote.connectionParameters.accessToken = session.accessToken
        DispatchQueue.main.async {
            self.appRemote.connect()
        }
    }
    
    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        presentAlertController(title: "Session Renewed", message: session.description, buttonTitle: "Sweet")
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        presentAlertController(title: "Authorization Failed", message: error.localizedDescription, buttonTitle: "Bummer")
    }
    
    
    
    
    // MARK: - SPTAppRemoteDelegate
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        updateViewBasedOnConnected()
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { (success, error) in
            if let error = error {
                print("Error subscribing to player state:" + error.localizedDescription)
            }
        })
        fetchPlayerState()
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        updateViewBasedOnConnected()
        lastPlayerState = nil
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        updateViewBasedOnConnected()
        lastPlayerState = nil
    }
    
    
    // MARK: - SPTAppRemotePlayerAPIDelegate
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        update(playerState: playerState)
    }
    
    
    // MARK: - Private Helpers
    
    private func presentAlertController(title: String, message: String, buttonTitle: String) {
        DispatchQueue.main.async {
            let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let action = UIAlertAction(title: buttonTitle, style: .default, handler: nil)
            controller.addAction(action)
            self.present(controller, animated: true)
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        sessionManager.application(app, open: url, options: options)
        return true
    }
    
    // MARK: - Glitch Token Swap/Refresh
    
//     Swapping code for access_token
    
    
//        func swapToken() {
//            AF.request("https://spotify-token-swap.glitch.me/api/token", method: .post, parameters: ["code": "[code]"])
//                .validate()
//                .responseJSON { (response) in
//                    debugPrint(response)
//                }
//        }
//    
//        // Swapping refresh_token for access_token
//        func refreshToken() {
//            AF.request("https://spotify-token-swap.glitch.me/api/refresh_token", method: .post, parameters: ["refresh_token": "[refresh token]"])
//                .validate()
//                .responseJSON { (response) in
//                    debugPrint(response)
//                }
//    
//        }
    
}
