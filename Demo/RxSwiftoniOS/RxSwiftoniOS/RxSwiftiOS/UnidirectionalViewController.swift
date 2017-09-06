//
//  UnidirectionalViewController.swift
//  RxSwiftiOS
//
//  Created by Marin Todorov on 1/22/17.
//  Copyright © 2017 Underplot ltd. All rights reserved.
//

import UIKit
import RealmSwift

import RxSwift
import RxCocoa
import RxRealm
import RxRealmDataSources

class UnidirectionalViewController: UIViewController {

    @IBOutlet var tableView: UITableView!

    private let bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        bindUI()
    }

    func bindUI() {

        // store data
        SourceControlAPI.updates()
            .observeOn(SerialDispatchQueueScheduler(qos: .background))
            .map(Update.fromOrEmpty)
            .subscribe(Realm.rx.add())
            .disposed(by: bag)

        // display data
        let dataSource = RxTableViewRealmDataSource<Update>(cellIdentifier: "Cell", cellType: UITableViewCell.self) {cell, ip, update in
            cell.detailTextLabel!.text = "[" + update.ago + "] " + update.name + " " + update.action
            cell.textLabel?.text = "Repo: " + update.repo
        }
        dataSource.headerTitle = "Source Control Activity"

        let realm = try! Realm()
        let updates = realm.objects(Update.self).sorted(byKeyPath: "date", ascending: false)

        Observable.changeset(from: updates)
            .bind(to: tableView.rx.realmChanges(dataSource))
            .disposed(by: bag)
    }
}
