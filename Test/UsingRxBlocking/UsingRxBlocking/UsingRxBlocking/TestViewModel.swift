//
//  TestViewModel.swift
//  UsingRxBlocking
//
//  Created by wgd on 2017/9/7.
//  Copyright © 2017年 dhh. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class TestViewModel {
  let inputInt = Variable(0)
  let outputValue: Driver<String>
  
  init() {
    outputValue = inputInt.asObservable()
      .map { return "\($0)" }
      .asDriver(onErrorJustReturn: "")
  }
}
