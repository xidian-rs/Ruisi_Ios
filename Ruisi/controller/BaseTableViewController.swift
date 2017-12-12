//
//  AbstractTableViewController.swift
//  Ruisi
//
//  Created by yang on 2017/11/28.
//  Copyright © 2017年 yang. All rights reserved.
//

import Foundation
import UIKit
import Kanna

class BaseTableViewController<T>: UITableViewController {
    
    func getUrl(page: Int) -> String {
        fatalError("要实现")
    }
    
    func parseData(pos: Int, doc: HTMLDocument) -> [T] {
        fatalError("要实现")
    }
    
    private var showFooterPrivate = true
    var showFooter:Bool {
        get {
            return showFooterPrivate
        }
        set {
            if showFooterPrivate != newValue {
                showFooterPrivate = newValue
                if showFooterPrivate { //显示footer
                    if (tableView.tableFooterView as? LoadMoreView) != nil {
                        tableView.tableFooterView?.isHidden = false
                    }else {
                        tableView.tableFooterView = LoadMoreView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 45))
                    }
                }else { //隐藏footer
                    tableView.tableFooterView?.isHidden = true
                }
            }
        }
    }
    var datas  = [T]()
    var currentPage = 1
    var pageSume = Int.max
    var position = 0 //为了hotnew而准备的
    var emptyPlaceholderText = "加载中..."
    var refreshView: UIRefreshControl?
    
    private var loading = false
    open var isLoading: Bool{
        get{
            return loading
        }
        set {
            loading = newValue
            if !loading {
                self.refreshControl?.endRefreshing()
                if let f = (tableView.tableFooterView as? LoadMoreView) {
                    f.endLoading(haveMore: currentPage < pageSume)
                }
            }else {
                self.refreshControl?.attributedTitle = NSAttributedString(string: "正在加载")
                if currentPage > 1 { //上拉刷新
                    if let f = (tableView.tableFooterView as? LoadMoreView) {
                        f.startLoading()
                    }
                }
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"", style:.plain, target:nil, action:nil)
        
        self.tableView.estimatedRowHeight = 80
        self.tableView.rowHeight = UITableViewAutomaticDimension
        if showFooter {
            showFooterPrivate = false
            showFooter = true
        }
        
        // Initialize the refresh control.
        refreshView = UIRefreshControl()
        Widgets.setRefreshControl(refreshView!)
        refreshView?.addTarget(self, action: #selector(pullRefresh), for: .valueChanged)
        self.refreshControl = refreshView
        refreshView?.beginRefreshing()
        loadData()
    }
    
    @objc func pullRefresh(){
        print("下拉刷新'")
        currentPage = 1
        pageSume = Int.max
        loadData(position)
    }
    
    func loadData(_ pos: Int = 0) {
        // 所持请求的数据正在加载中/未加载
        if isLoading { return }
        isLoading = true
        print("load data page:\(currentPage) sumPage:\(pageSume)")
        HttpUtil.GET(url: getUrl(page: currentPage), params: nil) { ok, res in
            var subDatas:[T] = []
            if !ok {
                self.emptyPlaceholderText = "加载失败,\(res)"
            } else if pos == self.position { //返回的数据是我们要的
                if let doc = try? HTML(html: res, encoding: .utf8) {
                    // load fromHash
                    let exitNode = doc.xpath("/html/body/div[@class=\"footer\"]/div/a[2]").first
                    if let hash =  Utils.getFormHash(from: exitNode?["href"]) {
                        print("formhash: \(hash)")
                        App.formHash = hash
                    }
                    
                    //load subdata
                    subDatas = self.parseData(pos: pos, doc: doc)
                }
            }
            
            
            //load data ok
            if pos == self.position {
                // 第一次换页清空
                if self.currentPage == 1 {
                    self.datas = subDatas
                    DispatchQueue.main.async{
                        self.tableView.reloadData()
                    }
                } else {
                    let count = self.datas.count
                    self.datas.append(contentsOf: subDatas)
                    DispatchQueue.main.async{
                        self.tableView.beginUpdates()
                        var indexs = [IndexPath]()
                        for i in 0 ..< subDatas.count {
                            indexs.append(IndexPath(row: count + i, section: 0))
                        }
                        self.tableView.insertRows(at: indexs, with: .automatic)
                        self.tableView.endUpdates()
                    }
                }
                
                var str: String
                if subDatas.count > 0 {
                    let df =  DateFormatter()
                    df.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
                    str = "Last update: "+df.string(from: Date())
                }else{
                    str = "加载失败"
                }
                
                let attrStr = NSAttributedString(string: str, attributes: [
                    NSAttributedStringKey.foregroundColor:UIColor.gray])
                
                DispatchQueue.main.async {
                    self.refreshControl?.attributedTitle = attrStr
                    self.isLoading = false

                    if self.currentPage < self.pageSume {
                        self.currentPage += 1
                    }
                }
            }
            
            print("finish http")
        }
    }
    
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        if datas.count == 0 {//no data avaliable
            let label = UILabel(frame:CGRect(x: 0, y: 0, width: tableView.bounds.width, height: tableView.bounds.height))
            label.text = emptyPlaceholderText
            label.textColor = UIColor.black
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 20)
            label.textColor = UIColor.lightGray
            label.sizeToFit()
            
            tableView.backgroundView = label;
            tableView.separatorStyle = .none;
            tableView.tableFooterView?.isHidden = true
            return 0
        } else {
            tableView.backgroundView = nil
            if showFooter {
                tableView.tableFooterView?.isHidden = false
            }
            tableView.separatorStyle = .singleLine
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datas.count
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let lastElement = datas.count - 1
        if !isLoading && indexPath.row == lastElement {
            print("load more")
            loadData()
        }
    }

}