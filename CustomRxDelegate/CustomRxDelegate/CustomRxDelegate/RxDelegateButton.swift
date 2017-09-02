//
//  RxDelegateButton.swift
//  CustomRxDelegate
//
//  Created by wgd on 2017/9/2.
//  Copyright © 2017年 dhh. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

@objc protocol RxDelegateButtonDelegate: NSObjectProtocol {
  @objc optional func trigger()
}

class RxDelegateButton: UIButton {
  
  weak var delegate: RxDelegateButtonDelegate?
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    addTarget(self, action: #selector(RxDelegateButton.buttonTap), for: .touchUpInside)
  }
  
  
  @objc private func buttonTap() {
    delegate?.trigger?()
  }
  
}

extension Reactive where Base: RxDelegateButton {
  var delegate: DelegateProxy {
    return RxDelegateButtonDelegateProxy.proxyForObject(base)
  }
  
  var SM_trigger: ControlEvent<Void> {
    let source: Observable<Void> = delegate.sentMessage(#selector(RxDelegateButtonDelegate.trigger)).map { _ in }
    return ControlEvent(events: source)
  }
  
  var MI_trigger: ControlEvent<Void> {
    let source: Observable<Void> = delegate.methodInvoked(#selector(RxDelegateButtonDelegate.trigger)).map { _ in }
    return ControlEvent(events: source)
  }
}
