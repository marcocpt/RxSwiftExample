//
//  RxDelegateButtonDelegateProxy.swift
//  CustomRxDelegate
//
//  Created by wgd on 2017/9/2.
//  Copyright © 2017年 dhh. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class RxDelegateButtonDelegateProxy: DelegateProxy, RxDelegateButtonDelegate, DelegateProxyType  {
  
  static func currentDelegateFor(_ object: AnyObject) -> AnyObject? {
    guard let rxDelegateButton = object as? RxDelegateButton else {
      fatalError()
    }
    return rxDelegateButton.delegagte
  }
  
  static func setCurrentDelegate(_ delegate: AnyObject?, toObject object: AnyObject) {
    guard let rxDelegateButton = object as? RxDelegateButton else {
      fatalError()
    }
    if delegate == nil {
      rxDelegateButton.delegagte = nil
    } else {
      guard let delegate = delegate as? RxDelegateButtonDelegate else {
        fatalError()
      }
      rxDelegateButton.delegagte = delegate
    }
  }
  
}
