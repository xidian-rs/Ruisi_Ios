//
//  MyPostsViewController.swift
//  Ruisi
//
//  Created by yang on 2017/6/28.
//  Copyright © 2017年 yang. All rights reserved.
//

import UIKit
import Kanna

// 我的帖子
class MyPostsViewController: BaseTableViewController<ArticleListData> {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"", style:.plain, target:nil, action:nil)
    }
    
    override func getUrl(page: Int) -> String {
        return Urls.getMyPostsUrl(uid: App.uid) + "&page=\(page)"
    }
    
    override func parseData(pos:Int, doc: HTMLDocument) -> [ArticleListData]{
        var subDatas:[ArticleListData] = []
        loop1:
        for li in doc.xpath("/html/body/div[1]/ul/li") {
            let a = li.css("a").first
            var tid: Int?
            if let u = a?["href"] {
                tid = Utils.getNum(from: u)
            } else {
                //没有tid和咸鱼有什么区别
                continue
            }
            
            for d in self.datas {
                if d.tid == tid {break loop1}
            }
            
            let img = (li.css("img").first)?["src"]
            var haveImg = false
            if let i =  img {
                haveImg = i.contains("icon_tu.png")
            }
            
            var replyStr: String
            let replys = li.css("span.num").first
            if let r =  replys {
                replyStr = r.text!
            }else {
                replyStr = "-"
            }
            
            let title = a?.text?.trimmingCharacters(in: CharacterSet(charactersIn: "\r\n "))
            let color =  Utils.getHtmlColor(from: a?["style"])
            
            let d = ArticleListData(title: title ?? "未获取到标题", tid: tid!,replys: replyStr, haveImage:haveImg, titleColor: color)
            subDatas.append(d)
        }
        
        if subDatas.count < 20 { self.totalPage = self.currentPage }
        return subDatas
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let titleLabel = cell.viewWithTag(1) as! UILabel
        let commentsLabel = cell.viewWithTag(3) as! UILabel
        let d = datas[indexPath.row]
        
        titleLabel.text = d.title
        if let color = d.titleColor {
            titleLabel.textColor = color
        }
        
        commentsLabel.text = d.replyCount
        return cell
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dest = segue.destination as? PostViewController,
            let cell = sender as? UITableViewCell {
            let index = tableView.indexPath(for: cell)!
            dest.title = datas[index.row].title
            dest.tid = datas[index.row].tid
        }
    }
}
