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
    weak var delegate: MusicBrowserViewDelegate!
    
    var didSetupConstraints = false
    var isNowPlayingCollapsed = true
    
    var currentStatusBarStyle: UIStatusBarStyle = .lightContent
    
    var tableView: UITableView!
    var songTableView: ReusableTableView!
    
    let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
    
    var viewContainerTransformScale: CGFloat = 0.94
    var viewContainerTransformExpandSpeed: CGFloat = 12
    var viewContainerSizeOffset: CGFloat!
    var nowPlayingCardContainerHeight: CGFloat!
    var nowPlayingCardContainerBottomOffset: CGFloat!
    var nowPlayingCardContainerOffsetPct: CGFloat!
    var nowPlayingCardHeight: CGFloat!
    
    var songs = [MPMediaItem]()
    
    var panGestureRecognizer: UIPanGestureRecognizer?
    
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
    
    let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
    var blurEffectView = UIVisualEffectView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("music", view.frame.height)
        
        setUpNavBar()
        setUpBlurEffectView()
        setUpProps()
        setUpTable()
        
        viewContainer.addSubview(tableView)
        view.addSubview(viewContainer) //REMINDER: Add subview BEFORE snp make
        viewBackGroundLayer.isHidden = true
        view.addSubview(viewBackGroundLayer)
        view.addSubview(nowPlayingCardViewContainer)
        addLineToView(view: nowPlayingCardViewContainer, position: .LINE_POSITION_TOP, color: themeDict["topBorder"]!, width: 0.5)
        
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        panGestureRecognizer?.delegate = self
        nowPlayingCardViewContainer.addGestureRecognizer(panGestureRecognizer!)
        
        let nowPlayingController = AudioPlayerViewController()
        nowPlayingController.parentVC = self
        nowPlayingController.delegate = self
        nowPlayingController.collapsedNowPlayingHeight = nowPlayingCardHeight - nowPlayingCardContainerBottomOffset
        nowPlayingController.nowPlayingCardViewHeight = nowPlayingCardHeight
        addChild(nowPlayingController)
        nowPlayingController.view.autoresizingMask = [] // important, right constraint won't work without this
        nowPlayingCardViewContainer.addSubview(nowPlayingController.view)
        
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .authorized:
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
        // Get Media
        case .notDetermined:
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
        case .denied: break
            
        case .restricted: break
            
        }
        
        nowPlayingController.didMove(toParent: self)
        self.updateViewConstraints()
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    @objc func panGestureAction(_ panGesture: UIPanGestureRecognizer) {
        var translation = panGesture.translation(in: view)
        let direction = panGesture.direction(in: view)
        let translationPercent = translation.y / view.frame.height
        
        if panGesture.state == .began {
            
        }
        else if panGesture.state == .changed {
            //make sure to only pan up or down and prevent moving view beyond original bottom constraint
            if (direction.contains(.Down) || direction.contains(.Up)) {
                if translation.y <= 0 {
                    translation.y = translation.y + translation.y * 0.4
                } else {
                    translation.y = translation.y - translation.y * 0.4
                }
                if isNowPlayingCollapsed {
                    if -translation.y >= view.frame.height  {
                        nowPlayingCardViewContainer.snp.updateConstraints { make in
                            make.bottom.equalTo(view).offset(0)
                        }
                        
                        self.viewContainer.transform = CGAffineTransform(scaleX: viewContainerTransformScale,
                                                                         y: viewContainerTransformScale)
                        updateExpandedProps()
                    } else {
                        nowPlayingCardViewContainer.snp.updateConstraints { make in
                            make.bottom.equalTo(view).offset(translation.y * nowPlayingCardContainerOffsetPct +
                                nowPlayingCardContainerBottomOffset)
                        }
                        
                        UIView.animate(withDuration: animationDuration, animations: {
                            if 1 - -translationPercent / self.viewContainerTransformExpandSpeed > self.viewContainerTransformScale {
                                self.viewContainer.transform = CGAffineTransform(scaleX: 1 - -translationPercent / self.viewContainerTransformExpandSpeed,
                                                                                 y: 1 - -translationPercent / self.viewContainerTransformExpandSpeed)
                            }
                            self.navigationController?.navigationBar.barStyle = .black
                        })
                        
                        viewBackGroundLayer.isHidden = false
                        viewBackGroundLayer.backgroundColor = UIColor.black.withAlphaComponent(-translationPercent * 0.7)
                        viewContainer.layer.cornerRadius = -translationPercent * 13
                        blurEffectView.layer.cornerRadius = -translationPercent * 13
                        blurEffectView.alpha = 1 + translationPercent * 3
                        nowPlayingCardViewContainer.backgroundColor = UIColor.white.withAlphaComponent(-translationPercent * 1 + 0.8)
                        nowPlayingCardViewContainer.layer.cornerRadius = -translationPercent * 13
                    }
                    delegate?.musicBrowserNowPlayingCardDidDrag(yTrans: translation.y, isCollapsing: false)
                } else if translation.y >= 0 {
                    if translation.y >= view.frame.height / 2 {
                        panGesture.state = .ended
                    }
                    delegate?.musicBrowserNowPlayingCardDidDrag(yTrans: translation.y, isCollapsing: true)
                    
                    nowPlayingCardViewContainer.snp.updateConstraints { make in
                        make.bottom.equalTo(view).offset(translation.y)
                    }
                    
                    UIView.animate(withDuration: animationDuration, animations: {
                        if 0.94 + translationPercent / 16 <= 1 {
                            self.viewContainer.transform = CGAffineTransform(scaleX: self.viewContainerTransformScale + translationPercent / 16,
                                                                             y: self.viewContainerTransformScale + translationPercent / 16)
                        }
                        //                        self.navigationController?.navigationBar.barStyle = .default
                        //                        self.navigationController?.navigationBar.layoutIfNeeded()
                    })
                }
                self.navigationController?.setNavigationBarHidden(true, animated: true)
                UIView.animate(withDuration: animationDuration, animations: {
                    self.view.layoutIfNeeded()
                })
            }
        } else if panGesture.state == .ended {
            let velocity = panGesture.velocity(in: view)
            
            if (velocity.y <= -150 || -translation.y >= view.frame.height * 0.5) {
                print("expanded")
                delegate?.musicBrowserNowPlayingCardDragEnded()
                nowPlayingCardViewContainer.snp.updateConstraints { make in
                    make.bottom.equalTo(self.view).offset(0)
                }
                isNowPlayingCollapsed = false
                viewBackGroundLayer.isHidden = false
                
                UIView.animate(withDuration: endintAnimationDuration, animations: {
                    self.view.layoutIfNeeded()
                    self.viewContainer.transform = CGAffineTransform(scaleX: self.viewContainerTransformScale,
                                                                     y: self.viewContainerTransformScale)
                    self.updateExpandedProps()
                    self.navigationController?.navigationBar.layoutIfNeeded()
                })
                
                isNowPlayingCollapsed = false
            } else {
                print("collapsed")
                self.nowPlayingCardViewContainer.snp.updateConstraints { make in
                    make.bottom.equalTo(self.view).offset(self.nowPlayingCardContainerBottomOffset)
                }
                self.delegate?.musicBrowserNowPlayingCardDragFailed()
                self.isNowPlayingCollapsed = true
                
                UIView.animate(withDuration: endintAnimationDuration, animations: {
                    self.view.layoutIfNeeded()
                    self.viewContainer.transform = CGAffineTransform(scaleX: 1,
                                                                     y: 1)
                    UIView.animate(withDuration: endintAnimationDuration, animations: {
                        self.updateCollapsedProps()
                    })
                    self.navigationController?.navigationBar.layoutIfNeeded()
                    
                }, completion: { comp in
                    self.viewBackGroundLayer.isHidden = true
                })
            }
        }
    }
    
    func updateExpandedProps() {
        self.navigationController?.navigationBar.barStyle = .black
        self.viewBackGroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.viewContainer.layer.cornerRadius = 10
        self.blurEffectView.layer.cornerRadius = 10
        self.blurEffectView.alpha = 0
        self.nowPlayingCardViewContainer.layer.cornerRadius = 10
        self.nowPlayingCardViewContainer.backgroundColor = UIColor.white.withAlphaComponent(1)
    }
    
    func updateCollapsedProps() {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.navigationBar.barStyle = .default
        self.viewBackGroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0)
        self.viewContainer.layer.cornerRadius = 0
        self.blurEffectView.layer.cornerRadius = 0
        self.blurEffectView.alpha = 1
        self.nowPlayingCardViewContainer.layer.cornerRadius = 0
        self.nowPlayingCardViewContainer.backgroundColor = UIColor.white.withAlphaComponent(0)
    }
    
    func setUpNavBar() {
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
    
    func setUpTable() {
        tableView = UITableView(frame: view.frame, style: UITableView.Style.grouped)
        tableView.clipsToBounds = false
        tableView.contentInset = UIEdgeInsets(top: (navigationController?.navigationBar.frame.height)! + statusBarHeight,
                                              left: 0,
                                              bottom: nowPlayingCardHeight - nowPlayingCardContainerBottomOffset,
                                              right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
    }
    
    func setUpBlurEffectView() {
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = nowPlayingCardViewContainer.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        //        blurEffectView.layer.cornerRadius = 15
        blurEffectView.layer.masksToBounds = true
        blurEffectView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        nowPlayingCardViewContainer.addSubview(blurEffectView)
    }
    
    
    func setUpProps() {
        viewContainerSizeOffset = -35
        nowPlayingCardHeight = view.frame.height * 0.95
        nowPlayingCardContainerOffsetPct = 0.85
        nowPlayingCardContainerBottomOffset = view.frame.height * 0.85
    }
    
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

func addTopBorderWithColor(_ objView : UIView, color: UIColor, width: CGFloat) {
    let border = CALayer()
    border.backgroundColor = color.cgColor
    border.frame = CGRect(x: 0, y: 0, width: objView.frame.size.width, height: width)
    objView.layer.addSublayer(border)
}

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

extension MusicBrowserViewController: AudioPlayerViewDelegate {
    
}


