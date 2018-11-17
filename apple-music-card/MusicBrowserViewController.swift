//
//  ViewController.swift
//  apple-music-card
//
//  Created by J Tan on 11/4/18.
//  Copyright © 2018 J Tan. All rights reserved.
//

import UIKit
import MediaPlayer
import Foundation

protocol MusicBrowserViewDelegate: class {
    func musicBrowserNowPlayingCardDidDrag(yTrans: CGFloat, isCollapsing: Bool)
    func musicBrowserNowPlayingCardDragFailed()
    func musicBrowserNowPlayingCardDragEnded()
}

class MusicBrowserViewController: UIViewController, UIGestureRecognizerDelegate {
    
    let viewBackGroundLayer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0)
        return view
    }()
    
    let viewContainer: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()
    
    let nowPlayingCardViewContainer: UIView = {
        let view = UIView()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.backgroundColor = UIColor.white.withAlphaComponent(0)
        return view
    }()
    
    weak var delegate: MusicBrowserViewDelegate!
    
    var didSetupConstraints = false
    
    var nowPlayingController: AudioPlayerViewController!
    
    var currentStatusBarStyle: UIStatusBarStyle = .lightContent
    
    let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
    
    var viewContainerTransformScale: CGFloat = 0.94
    var viewContainerTransformExpandSpeed: CGFloat = 12
    var viewContainerSizeOffset: CGFloat!
    var nowPlayingCardContainerHeight: CGFloat!
    var nowPlayingCardContainerBottomOffset: CGFloat!
    var nowPlayingCardContainerOffsetPct: CGFloat!
    var nowPlayingCardHeight: CGFloat!
    
    let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
    var blurEffectView = UIVisualEffectView()
    
    var panGestureRecognizer: UIPanGestureRecognizer?
    
    var nowPlayingCardAnimator: UIViewPropertyAnimator!
    var nowPlayingImageAnimator: UIViewPropertyAnimator!
    var isNowPlayingCollapsed = true
    var isNowPlayingCardAnimated = false
    
    var tableView: UITableView!
    var songTableView: ReusableTableView!
    
    var songs = [MPMediaItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpNavBar()
        setUpBlurEffectView()
        setUpProps()
        setUpTable()
        setUpGestures()
        setUpAudioViewController()
        
        addViews()
        
        tryToFetchSongs()
        updateViewConstraints()
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    var progressWhenInterrupted: CGFloat = 0
    
    @objc func panGestureAction(_ panGesture: UIPanGestureRecognizer) {
        let translation = panGesture.translation(in: view)
        let direction = panGesture.direction(in: view)
        let translationPercent = translation.y / nowPlayingCardContainerBottomOffset
        
        if panGesture.state == .began {
            animateTransitionIfNeeded(direction)
        }
        else if panGesture.state == .changed {
            //make sure to only handle pan up or down
            if (direction.contains(.Down) || direction.contains(.Up)){
                //prevent moving view beyond original bottom constraint
                if (!isNowPlayingCollapsed && translation.y > 0) ||
                    (isNowPlayingCollapsed && translation.y < 0) {
                    
                    if !isNowPlayingCollapsed {
                        // slow down pan when trying to collapse card from expanded state
                        nowPlayingCardAnimator.fractionComplete = abs(translationPercent) * 0.5 + progressWhenInterrupted
                    } else {
                        nowPlayingCardAnimator.fractionComplete = abs(translationPercent) + progressWhenInterrupted
                    }
                }
            }
        } else if panGesture.state == .ended {
            let velocity = panGesture.velocity(in: view)
            if isNowPlayingCardAnimated {
                if isNowPlayingCollapsed {
                    if (velocity.y <= -150 || -translation.y >= view.frame.height * 0.5) {
                        isNowPlayingCollapsed = false
                    } else { //for when the user reverse pan direction halfway
                        //animator reversed won't reverse these
                        nowPlayingCardAnimator.isReversed = true
                        navigationController?.setNavigationBarHidden(false, animated: false)
                        navigationController?.navigationBar.barStyle = .default
                        viewBackGroundLayer.isHidden = true
                        blurEffectView.alpha = 1
                        nowPlayingCardViewContainer.backgroundColor = UIColor.white.withAlphaComponent(0)
                    }
                } else { // pan from expanded to collpases
                    isNowPlayingCollapsed = true
                    
                    // nowPlayingController props
                    // get nowPlayingImage animations back in sync with the nowPlayCard animation
                    nowPlayingImageAnimator.fractionComplete = nowPlayingCardAnimator.fractionComplete
                    nowPlayingImageAnimator.startAnimation()
                    nowPlayingImageAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
                }
                isNowPlayingCardAnimated = false
            }
            nowPlayingCardAnimator.startAnimation()
            nowPlayingCardAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            
        }
    }
    
    // MARK: - View Update
    fileprivate func animateTransitionIfNeeded(_ direction: UIPanGestureRecognizer.PanGestureDirection) {
        let expandingDuration: Double = 0.35
        let collapsingDuration: Double = 0.60
        
        if (isNowPlayingCollapsed && direction.contains(.Up)) {
            isNowPlayingCardAnimated = true
            nowPlayingCardAnimator = UIViewPropertyAnimator(duration: expandingDuration, curve: .easeOut, animations: { [weak self] in
                self?.updateToExpandedProps()
            })
            blurEffectView.alpha = 0
            nowPlayingCardViewContainer.backgroundColor = UIColor.white.withAlphaComponent(1)
        } else if (!isNowPlayingCollapsed && direction.contains(.Down)){
            isNowPlayingCardAnimated = true
            nowPlayingCardAnimator = UIViewPropertyAnimator(duration: collapsingDuration, dampingRatio: 0.85, animations: { [weak self] in
                self?.updateToCollapsedProps()
            })
            nowPlayingImageAnimator = UIViewPropertyAnimator(duration: collapsingDuration, dampingRatio: 0.85, animations: { [weak self] in
                self?.nowPlayingController.nowPlayingImage.transform = CGAffineTransform.identity
                self?.nowPlayingController.collapsedControlsContainer.alpha = 1
                self?.nowPlayingController.expandedControlsContainer.alpha = 0
                self?.nowPlayingController.nowPlayingImage.layer.cornerRadius = 5
            })
            nowPlayingImageAnimator.stopAnimation(true)
        }
        nowPlayingCardAnimator.pauseAnimation()
        progressWhenInterrupted = nowPlayingCardAnimator.fractionComplete
    }
    
    fileprivate func updateToExpandedProps() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.navigationBar.barStyle = .black
        
        nowPlayingCardViewContainer.transform = CGAffineTransform(translationX: 0,
                                                                  y: -(nowPlayingCardContainerBottomOffset))
        viewContainer.transform = CGAffineTransform(scaleX: viewContainerTransformScale,
                                                    y: viewContainerTransformScale)
        
        viewBackGroundLayer.isHidden = false
        viewBackGroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        viewContainer.layer.cornerRadius = 13
        blurEffectView.layer.cornerRadius =  13
        nowPlayingCardViewContainer.layer.cornerRadius =  13
        
        updateNowPlayingImagePropsToExpanded()
    }
    
    fileprivate func updateToCollapsedProps() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.barStyle = .default
        
        nowPlayingCardViewContainer.transform = CGAffineTransform(translationX: 0,
                                                                  y: 0)
        viewContainer.transform = CGAffineTransform(scaleX: 1,
                                                    y: 1)
        
        viewBackGroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0)
        viewContainer.layer.cornerRadius = 0
        blurEffectView.layer.cornerRadius =  0
        nowPlayingCardViewContainer.layer.cornerRadius =  0
        
        nowPlayingCardAnimator.addCompletion({ _ in
            self.viewBackGroundLayer.isHidden = true
            self.blurEffectView.alpha = 1
            self.nowPlayingCardViewContainer.backgroundColor = UIColor.white.withAlphaComponent(0)
        })
    }
    
    fileprivate func updateNowPlayingImagePropsToExpanded() {
        //nowPlayingController props
        let collapsedNowPlayingImageLeftOffset = view.frame.width * 0.05
        let collapsedNowPlayingImageWidth = nowPlayingController.collapsedNowPlayingImageWidth
        let nowPlayingImageTransformScale = view.frame.width * 0.65 / nowPlayingController.collapsedNowPlayingImageWidth
        let expandedNowplayingImageLeftOffset = collapsedNowPlayingImageLeftOffset * nowPlayingImageTransformScale - collapsedNowPlayingImageLeftOffset
        let nowPlayingImageOffset = expandedNowplayingImageLeftOffset + (view.frame.width - (collapsedNowPlayingImageWidth * nowPlayingImageTransformScale)) / 2
        
        var t = CGAffineTransform.identity
        t = t.translatedBy(x: nowPlayingImageOffset,
                           y: nowPlayingImageOffset)
        t = t.scaledBy(x: nowPlayingImageTransformScale,
                       y: nowPlayingImageTransformScale)
        nowPlayingController.nowPlayingImage.transform = t
        nowPlayingController.nowPlayingImage.layer.cornerRadius = nowPlayingController.nowPlayingImage.layer.cornerRadius / nowPlayingImageTransformScale
        nowPlayingController.expandedControlsContainer.transform = CGAffineTransform(translationX: 0,
                                                                                     y: nowPlayingImageOffset + collapsedNowPlayingImageWidth )
        nowPlayingController.collapsedControlsContainer.alpha = 0
        nowPlayingController.expandedControlsContainer.alpha = 1
    }
    
    // MARK: - View Setup
    fileprivate func setUpAudioViewController() {
        nowPlayingController = AudioPlayerViewController()
        nowPlayingController.parentVC = self
        nowPlayingController.delegate = self
        nowPlayingController.collapsedNowPlayingHeight = nowPlayingCardHeight - nowPlayingCardContainerBottomOffset
        nowPlayingController.nowPlayingCardViewHeight = nowPlayingCardHeight
        addChild(nowPlayingController)
        nowPlayingController.view.autoresizingMask = [] // important, right constraint won't work without this
        nowPlayingCardViewContainer.addSubview(nowPlayingController.view)
        nowPlayingController.didMove(toParent: self)
    }
    
    fileprivate func setUpNavBar() {
        let bounds = navigationController?.navigationBar.bounds.insetBy(dx: 0, dy: -(statusBarHeight)).offsetBy(dx: 0, dy: -(statusBarHeight))
        // Create blur effect.
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        visualEffectView.frame = bounds!
        // Set navigation bar up.
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.addSubview(visualEffectView)
        navigationController?.navigationBar.sendSubviewToBack(visualEffectView)
        navigationItem.title = "Songs"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    fileprivate func setUpTable() {
        tableView = UITableView(frame: view.frame, style: UITableView.Style.grouped)
        tableView.clipsToBounds = false
        tableView.contentInset = UIEdgeInsets(top: (navigationController?.navigationBar.frame.height)! + statusBarHeight,
                                              left: 0,
                                              bottom: nowPlayingCardHeight - nowPlayingCardContainerBottomOffset,
                                              right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
    }
    
    fileprivate func setUpGestures() {
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        panGestureRecognizer?.delegate = self
        nowPlayingCardViewContainer.addGestureRecognizer(panGestureRecognizer!)
    }
    
    fileprivate func setUpBlurEffectView() {
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = nowPlayingCardViewContainer.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        //        blurEffectView.layer.cornerRadius = 15
        blurEffectView.layer.masksToBounds = true
        blurEffectView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        nowPlayingCardViewContainer.addSubview(blurEffectView)
    }
    
    
    fileprivate func setUpProps() {
        viewContainerSizeOffset = -35
        nowPlayingCardHeight = view.frame.height * 0.95
        nowPlayingCardContainerOffsetPct = 0.85
        nowPlayingCardContainerBottomOffset = view.frame.height * 0.85
    }
    
    fileprivate func addViews() {
        viewContainer.addSubview(tableView)
        view.addSubview(viewContainer) //REMINDER: Add subview BEFORE snp make
        viewBackGroundLayer.isHidden = true
        view.addSubview(viewBackGroundLayer)
        view.addSubview(nowPlayingCardViewContainer)
        addLineToView(view: nowPlayingCardViewContainer, position: .LINE_POSITION_TOP, color: themeDict["topBorder"]!, width: 0.5)
    }
    
    fileprivate func tryToFetchSongs() {
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .authorized:
            addSongsToTable(nowPlayingController)
        // Get Media
        case .notDetermined:
            addSongsToTable(nowPlayingController)
        case .denied: break
            
        case .restricted: break
            
        }
    }
    
    fileprivate func addSongsToTable(_ nowPlayingController: AudioPlayerViewController) {
        MPMediaLibrary.requestAuthorization() { status in
            if status == .authorized {
                DispatchQueue.main.async {
                    // // Get Media
                    let query = MPMediaQuery()
                    let result = query.items
                    
                    for song in result!{
                        self.songs.append(song)
                    }
                    self.songTableView = ReusableTableView(self.tableView, self.songs, self)
                    self.songTableView.delegate = nowPlayingController
                    self.songTableView.tableView.reloadData()
                }
            }
        }
    }
}

extension MusicBrowserViewController: AudioPlayerViewDelegate {
    
}

extension MusicBrowserViewController {
    enum LINE_POSITION {
        case LINE_POSITION_TOP
        case LINE_POSITION_BOTTOM
    }
    
    func addLineToView(view : UIView, position : LINE_POSITION, color: UIColor, width: Double) {
        let lineView = UIView()
        lineView.backgroundColor = color
        lineView.translatesAutoresizingMaskIntoConstraints = false // This is important!
        view.addSubview(lineView)
        
        let metrics = ["width" : NSNumber(value: width)]
        let views = ["lineView" : lineView]
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[lineView]|", options:NSLayoutConstraint.FormatOptions(rawValue: 0), metrics:metrics, views:views))
        
        switch position {
        case .LINE_POSITION_TOP:
            view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[lineView(width)]", options:NSLayoutConstraint.FormatOptions(rawValue: 0), metrics:metrics, views:views))
            break
        case .LINE_POSITION_BOTTOM:
            view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[lineView(width)]|", options:NSLayoutConstraint.FormatOptions(rawValue: 0), metrics:metrics, views:views))
            break
        }
    }
}

// MARK: - Constraints
extension MusicBrowserViewController {
    override func updateViewConstraints() {
        //bottom -, right -,
        if (!didSetupConstraints) {
            viewBackGroundLayer.snp.makeConstraints { make in
                make.width.equalTo(view.snp.width)
                make.height.equalTo(view.snp.height)
            }
            
            viewContainer.snp.makeConstraints { make in
                make.width.equalTo(view.snp.width)
                make.height.equalTo(view.snp.height)
                make.centerY.equalTo(view)
                make.centerX.equalTo(view)
            }
            
            nowPlayingCardViewContainer.snp.makeConstraints { make in
                make.width.equalTo(view)
                make.height.equalTo(nowPlayingCardHeight)
                make.bottom.equalTo(view).offset(nowPlayingCardContainerBottomOffset)
            }
            
            didSetupConstraints = true
        }
        
        super.updateViewConstraints()
    }
}

