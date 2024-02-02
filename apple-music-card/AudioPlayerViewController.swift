//
//  AudioPlayerViewController.swift
//  apple-music-card
//
//  Created by J Tan on 11/4/18.
//  Copyright © 2018 J Tan. All rights reserved.
//

import Foundation
import SnapKit
import MediaPlayer
import AVFoundation
import AVKit

@objc protocol AudioPlayerViewDelegate: class {
    @objc optional func audioPlayerViewDidDrag(yTrans: CGFloat)
    @objc optional func audioPlayerViewDragFailed()
    @objc optional func audioPlayerWillAppear()
    @objc optional func audioPlayerWillDisappear()
    @objc optional func audioPlayerPlayPauseTapped()
}

let animationDuration: TimeInterval = 0
let endintAnimationDuration: TimeInterval = 0.20

class AudioPlayerViewController: UIViewController {
    
    weak var delegate: AudioPlayerViewDelegate!
    weak var parentVC: MusicBrowserViewController!
    
    var player: MPMusicPlayerController?
    var playerState: String!
    
    var didSetupConstraints = false
    
    var panGestureRecognizer: UIPanGestureRecognizer?
    var originalPosition: CGPoint?
    var currentPositionTouched: CGPoint?
    
    var nowPlayingCardViewHeight: CGFloat = 0.0
    
    var collapsedNowPlayingHeight: CGFloat = 0.0
    var collapsedNowPlayingImageTopOffset: CGFloat = 10.0
    var collapsedNowPlayingImageWidth: CGFloat = 50
    var collapsedNowPlayingImageLeftOffset: CGFloat = 0.0
    
    var expandedNowPlayingImageTopOffset : CGFloat = 0.0
    var expandedNowPlayingImageCenterOffset: CGFloat = 0.0
    var expandedNowPlayingImageWidth: CGFloat = 150
    var expandedNowPlayingImageLeftOffset: CGFloat = 0.0
    
    var nowPlayingSongTitleLabelLeftOffset: CGFloat = 0.0
    
    var nowPlayingSong: MPMediaItem!
    
    let viewContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.backgroundColor = .purple
        return view
    }()
    
    let nowPlayingCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    let collapsedControlsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    let expandedControlsContainer: UIView = {
        let view = UIView()
        view.alpha = 0
        return view
    }()
    
    let nowPlayingImage: UIImageView = {
        let imageView = UIImageView()
        imageView.alpha = 1
        imageView.layer.shadowColor = UIColor.darkGray.cgColor
        imageView.layer.shadowOpacity = 1
        imageView.layer.masksToBounds = false
        imageView.layer.shadowRadius = 5
        imageView.layer.cornerRadius = 5
        imageView.contentMode = .scaleAspectFit // OR .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    let collapsedSongTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Not Playing"
        return label
    }()
    
    let collapsedPlayPauseButton: UIButton = {
        let button = UIButton()
        let origImage = UIImage(named: "play")
        let tintedImage = origImage?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        button.setImage(tintedImage, for: .normal)
        button.tintColor = themeDict["com"]
        button.isUserInteractionEnabled = true
        return button
    }()
    
    let expandedSongTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Not Playing"
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 16.0)
        return label
    }()
    
    let expandedPlayPauseButton: UIButton = {
        let button = UIButton()
        let origImage = UIImage(named: "play")
        let tintedImage = origImage?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        button.setImage(tintedImage, for: .normal)
        button.tintColor = themeDict["com"]
        button.isUserInteractionEnabled = true
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        parentVC.delegate = self
        
        setUpExpandedNowPlayingCardProps()
        setUpCollapsedNowPlayingCardProps()
        
        nowPlayingSongTitleLabelLeftOffset = collapsedNowPlayingImageLeftOffset * 2 + collapsedNowPlayingImageWidth
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0)
        
        addViewsAndGestures()
        
        player = MPMusicPlayerController.applicationMusicPlayer
        
        self.updateViewConstraints()
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    @objc func playPauseButtonOnTap() {
        print("playbutton press")
        if player != nil {
            var origImage: UIImage!
            if (player?.playbackState == .playing) {
                player?.pause()
                origImage = UIImage(named: "play")
            } else {
                player?.play()
                origImage = UIImage(named: "pause")
            }
            let tintedImage = origImage?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
            collapsedPlayPauseButton.setImage(tintedImage, for: .normal)
            expandedPlayPauseButton.setImage(tintedImage, for: .normal)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        print("ob calle")
        if keyPath == "rate" {
            print("playing")
        }
        else {
            print("paused")
        }
    }
    
    fileprivate func setUpExpandedNowPlayingCardProps() {
        expandedNowPlayingImageTopOffset = collapsedNowPlayingHeight - collapsedNowPlayingImageTopOffset
        expandedNowPlayingImageCenterOffset = -view.frame.width / 2.5
        expandedNowPlayingImageWidth = view.frame.width * 0.65
        expandedNowPlayingImageLeftOffset = (view.frame.width - expandedNowPlayingImageWidth) / 2
    }
    
    fileprivate func setUpCollapsedNowPlayingCardProps() {
        collapsedNowPlayingImageWidth = collapsedNowPlayingHeight * 0.70
        collapsedNowPlayingImageTopOffset = collapsedNowPlayingHeight * 0.15
        collapsedNowPlayingImageLeftOffset = view.frame.width * 0.05
    }
    
    fileprivate func addViewsAndGestures() {
        view.addSubview(nowPlayingCardView)
        nowPlayingCardView.addSubview(collapsedControlsContainer)
        nowPlayingCardView.addSubview(expandedControlsContainer)
        expandedControlsContainer.addSubview(expandedSongTitleLabel)
        expandedControlsContainer.addSubview(expandedPlayPauseButton)
        expandedPlayPauseButton.addTarget(self, action: #selector(playPauseButtonOnTap), for: .touchUpInside)
        collapsedControlsContainer.addSubview(collapsedSongTitleLabel)
        collapsedControlsContainer.addSubview(collapsedPlayPauseButton)
        collapsedPlayPauseButton.addTarget(self, action: #selector(playPauseButtonOnTap), for: .touchUpInside)
        view.addSubview(nowPlayingImage)
    }
}

extension AudioPlayerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension AudioPlayerViewController: MusicBrowserViewDelegate {
    func musicBrowserNowPlayingCardDidDrag(yTrans: CGFloat, isCollapsing: Bool) {
        
    }
    
    func musicBrowserNowPlayingCardDragFailed() {
    }
    
    func musicBrowserNowPlayingCardDragEnded() {
        
    }
}

extension AudioPlayerViewController: ReusableTableViewDelegate {
    func reusableTableDidSelect(song: MPMediaItem) {
        collapsedSongTitleLabel.text = song.title
        expandedSongTitleLabel.text = song.title
        nowPlayingSong = song
        nowPlayingImage.image = nowPlayingSong.artwork?.image(at: CGSize(width: expandedNowPlayingImageWidth, height: expandedNowPlayingImageWidth))
        
        let mediaItemCollection = MPMediaItemCollection(items: [song])
        
        if let player = player {
            player.setQueue(with: mediaItemCollection)
            
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                print("Playback OK")
                try AVAudioSession.sharedInstance().setActive(true)
                print("Session is Active")
                
                player.prepareToPlay()
                player.play()
                
                let origImage = UIImage(named: "pause")
                let tintedImage = origImage?.withRenderingMode(.alwaysTemplate)
                collapsedPlayPauseButton.setImage(tintedImage, for: .normal)
                expandedPlayPauseButton.setImage(tintedImage, for: .normal)
            } catch let error {
                print("error: \(error.localizedDescription)")
            }
        }
    }
}

extension UIPanGestureRecognizer {
    public struct PanGestureDirection: OptionSet {
        public let rawValue: UInt8
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        static let Up = PanGestureDirection(rawValue: 1 << 0)
        static let Down = PanGestureDirection(rawValue: 1 << 1)
        static let Left = PanGestureDirection(rawValue: 1 << 2)
        static let Right = PanGestureDirection(rawValue: 1 << 3)
    }
    
    private func getDirectionBy(velocity: CGFloat, greater: PanGestureDirection, lower: PanGestureDirection) -> PanGestureDirection {
        if velocity == 0 {
            return []
        }
        return velocity > 0 ? greater : lower
    }
    
    public func direction(in view: UIView) -> PanGestureDirection {
        let velocity = self.velocity(in: view)
        let yDirection = getDirectionBy(velocity: velocity.y, greater: PanGestureDirection.Down, lower: PanGestureDirection.Up)
        let xDirection = getDirectionBy(velocity: velocity.x, greater: PanGestureDirection.Right, lower: PanGestureDirection.Left)
        return xDirection.union(yDirection)
    }
}

// MARK: - Constraints
extension AudioPlayerViewController {
    override func updateViewConstraints() {
        if (!didSetupConstraints) {
            nowPlayingCardView.snp.makeConstraints { make in
                make.left.equalTo(view)
                make.right.equalTo(view)
                make.height.equalTo(nowPlayingCardViewHeight)
                make.top.equalTo(view.snp.top)
                make.centerX.equalTo(view)
            }
            
            collapsedControlsContainer.snp.makeConstraints { make in
                make.width.equalTo(nowPlayingCardView)
                make.height.equalTo(collapsedNowPlayingHeight)
                make.top.equalTo(nowPlayingCardView)
                make.centerX.equalTo(nowPlayingCardView)
            }
            
            nowPlayingImage.snp.makeConstraints { make in
                make.width.equalTo(collapsedNowPlayingImageWidth)
                make.height.equalTo(nowPlayingImage.snp.width)
                make.top.equalTo(nowPlayingCardView).offset(collapsedNowPlayingImageTopOffset)
                make.left.equalTo(nowPlayingCardView).offset(collapsedNowPlayingImageLeftOffset)
            }
            
            collapsedSongTitleLabel.snp.makeConstraints { make in
                make.width.equalTo(100)
                make.centerY.equalTo(collapsedControlsContainer)
                make.left.equalTo(nowPlayingCardView).offset(nowPlayingSongTitleLabelLeftOffset)
            }
            
            collapsedPlayPauseButton.snp.makeConstraints { make in
                make.width.equalTo(35)
                make.height.equalTo(35)
                make.centerY.equalTo(collapsedControlsContainer)
                make.right.equalTo(collapsedControlsContainer).offset(-collapsedNowPlayingImageLeftOffset)
            }
            
            expandedControlsContainer.snp.makeConstraints { make in
                print("shit", -(nowPlayingCardView.frame.height * 0.5), view.snp.bottom)
                make.width.equalTo(nowPlayingCardView).offset(-(view.frame.width * 0.2))
                make.height.equalTo(nowPlayingCardView).offset(-(nowPlayingCardViewHeight * 0.55))
                //                make.bottom.equalTo(nowPlayingCardView.snp.bottom).offset(0)
                make.top.equalTo(nowPlayingImage.snp.bottom).offset(30)
                make.centerX.equalTo(nowPlayingCardView)
            }
            
            expandedSongTitleLabel.snp.makeConstraints { make in
                make.leading.equalTo(expandedControlsContainer).offset(10)
                make.trailing.equalTo(expandedControlsContainer).offset(-10)
                make.top.equalTo(expandedControlsContainer).offset(40)
            }
            
            expandedPlayPauseButton.snp.makeConstraints { make in
                make.width.equalTo(50)
                make.height.equalTo(50)
                make.centerX.equalTo(expandedControlsContainer)
                make.top.equalTo(expandedSongTitleLabel.snp.bottom).offset(10)
            }
            
            didSetupConstraints = true
        }
        super.updateViewConstraints()
    }
}

