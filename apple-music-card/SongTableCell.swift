//
//  SongTableCell.swift
//  apple-music-card
//
//  Created by J Tan on 11/4/18.
//  Copyright © 2018 J Tan. All rights reserved.
//

import Foundation
import SnapKit

var portW:CGFloat = 0.0
var portH:CGFloat = 0.0

class SongTableCell: UITableViewCell {
    
    let cellContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.2
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontSizeToFitWidth = false
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = themeDict["sub"]
        return label
    }()
    
    let postImage: UIImageView = {
        let imgView = UIImageView()
        imgView.image = UIImage(named: "placeholder-tn")
        imgView.contentMode = .scaleAspectFill
        imgView.clipsToBounds = true
        return imgView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(cellContainer)
        cellContainer.addSubview(titleLabel)
        cellContainer.addSubview(postImage)
        cellContainer.backgroundColor = themeDict["cell"]
        contentView.backgroundColor = themeDict["table"]
        self.setupConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("has not been implemented")
    }
    
    func setupConstraints() {
        cellContainer.snp.makeConstraints { make in
            make.leading.equalTo(contentView)
            make.trailing.equalTo(contentView)
            make.top.equalTo(contentView.snp.top).offset(5)
            make.bottom.equalTo(contentView).offset(-5)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(cellContainer).offset(15)
            make.trailing.equalTo(cellContainer).offset(-15)
            make.top.equalTo(cellContainer.snp.top).offset(15)
        }
        
        postImage.snp.makeConstraints { make in
            let w = contentView.frame.size.width
            let newH = w / 16 * 9
            portW = w
            portH = newH
            make.width.equalTo(50)
            make.height.equalTo(50)
            make.left.equalTo(contentView).offset(20)
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
            make.bottom.equalTo(cellContainer.snp.bottom).offset(-25)
        }
    }
}

