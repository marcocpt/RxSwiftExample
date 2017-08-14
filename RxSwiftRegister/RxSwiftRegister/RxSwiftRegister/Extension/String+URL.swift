//
//  String+URL.swift
//  RxSwiftRegister
//
//  Created by wgd on 2017/8/14.
//  Copyright © 2017年 wgd. All rights reserved.
//

extension String {
  var URLEscaped: String {
    return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
  }
}
