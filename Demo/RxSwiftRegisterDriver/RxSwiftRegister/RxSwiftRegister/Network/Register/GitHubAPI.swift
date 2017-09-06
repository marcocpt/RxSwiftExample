//
//  GitHubAPI.swift
//  RxSwiftRegister
//
//  Created by wgd on 2017/8/14.
//  Copyright © 2017年 wgd. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

class GitHubAPI{
  let URLSession: URLSession
  
  static let sharedAPI = GitHubAPI(
    URLSession: Foundation.URLSession.shared
  )
  
  init(URLSession: URLSession) {
    self.URLSession = URLSession
  }
  
  //如果url存在就认为已注册，否则就是没有。
  func usernameAvailable(_ username: String) -> Observable<Bool> {
    let url = URL(string: "https://github.com/\(username.URLEscaped)")!
    let request = URLRequest(url: url)
    return self.URLSession.rx.response(request: request)
      .map{ (response, _) in
        return response.statusCode == 404
      }
      .catchErrorJustReturn(false)
  }
  
  //这里和官方例子一样，模拟下注册过程
  func register(_ username: String, password: String) -> Observable<Bool> {
    let registerResult = arc4random() % 5 == 0 ? false : true
    return Observable.just(registerResult)
      .delay(1.0, scheduler: MainScheduler.instance)  //延迟一秒
  }
}
