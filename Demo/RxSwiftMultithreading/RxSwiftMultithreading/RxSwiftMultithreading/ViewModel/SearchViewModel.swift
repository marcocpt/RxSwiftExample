//
//  SearchViewModel.swift
//  RxSwiftMultithreading
//
//  Created by monkey on 2017/4/6.
//  Copyright © 2017年 Coder. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import RxAlamofire
import ObjectMapper

class SearchViewModel {
    
    lazy var rx_repositories: Driver<[Repository]> = self.fetchRepositories()
    fileprivate var repositoryName: Observable<String>
    
    init(searchText nameObservable: Observable<String>) {
        self.repositoryName = nameObservable
    }
    
    fileprivate func fetchRepositories() -> Driver<[Repository]> {
        return repositoryName
            .subscribeOn(MainScheduler.instance) // Make sure we are on MainScheduler
            .do(onNext: { response in
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            })
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .flatMapLatest { text in // .background thread, network request
                return RxAlamofire
                    .requestJSON(.get, "https://api.github.com/users/\(text)/repos")
                    .debug()
                    .catchError { error in
                        return Observable.never()
                }
            }
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .map { (response, json) -> [Repository] in // again back to .background, map objects
                if let repos = Mapper<Repository>().mapArray(JSONObject: json) {
                    return repos
                } else {
                    return []
                }
            }
            .observeOn(MainScheduler.instance) // switch to MainScheduler, UI updates
            .do(onNext: { response in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            })
            .asDriver(onErrorJustReturn: []) // This also makes sure that we are on MainScheduler
    }
}
