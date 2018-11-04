//
//  ReusableTableView.swift
//  apple-music-card
//
//  Created by J Tan on 11/4/18.
//  Copyright © 2018 J Tan. All rights reserved.
//

import UIKit
import Foundation
import SnapKit
import MediaPlayer
import AVFoundation
import AVKit

@objc protocol ReusableTableViewDelegate: class {
    @objc optional func reusableTableDidSelect(song: MPMediaItem)
}

class ReusableTableView: NSObject, UITableViewDataSource, UITableViewDelegate{
    weak var delegate: ReusableTableViewDelegate!
    weak var parentVC: UIViewController!
    
    let saturation = CGFloat(0.70)
    let lightness = CGFloat(1)
    
    var songArray: [MPMediaItem]!
    var tableView: UITableView
    
    var player: AVAudioPlayer?
    
    init(_ tv: UITableView, _ data: [MPMediaItem], _ parentVC: UIViewController) {
        
        songArray = data
        tableView = tv
        self.parentVC = parentVC
        
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        //        tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) //top,left,bottom,right
        //        tableView.separatorColor = themeDict["cell"]
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        tableView.backgroundColor = themeDict["table"]
        tableView.sectionIndexBackgroundColor = themeDict["table"]
        tableView.tableFooterView = UIView() //hide empty rows
        tableView.alwaysBounceVertical = false
        tableView.alwaysBounceHorizontal = false
        tableView.contentInsetAdjustmentBehavior = .never
        
        super.init()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SongTableCell.self, forCellReuseIdentifier: "songCell")
    }
    
    // MARK: - Tableview Setup
    // End of scrolling optimization
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let imageCell = tableView.dequeueReusableCell(withIdentifier: "songCell") as! SongTableCell
        imageCell.titleLabel.text = songArray[indexPath.row].title
        imageCell.postImage.image = songArray[indexPath.row].artwork?.image(at: CGSize(width: 50, height: 50))
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = themeDict["table"]
        imageCell.selectedBackgroundView = backgroundView
        
        return imageCell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //        playSound(songTitle: songArray[indexPath.row].title!)
        delegate?.reusableTableDidSelect!(song: songArray[indexPath.row])
    }
}

extension UITableView {
    func scrollToBottom(){
        DispatchQueue.main.async {
            let indexPath = IndexPath(
                row: self.numberOfRows(inSection:  self.numberOfSections - 1) - 1,
                section: self.numberOfSections - 1)
            self.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    func scrollToTop() {
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: 0, section: 0)
            self.scrollToRow(at: indexPath, at: .top, animated: false)
        }
    }
}

