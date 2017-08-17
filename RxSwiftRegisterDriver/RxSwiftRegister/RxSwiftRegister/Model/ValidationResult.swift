//
//  ValidationResult.swift
//  RxSwiftRegister
//
//  Created by wgd on 2017/8/14.
//  Copyright © 2017年 wgd. All rights reserved.
//

import RxCocoa
import RxSwift

enum ValidationResult {
  case ok(message: String)    //验证成功和信息
  case empty                  //输入为空
  case validating
  case failed(message: String) //验证失败的原因
}

extension ValidationResult: CustomStringConvertible {
  var description: String {
    switch self {
    case .ok(let message):
      return message
    case .empty:
      return ""
    case .validating:
      return "validating ..."
    case .failed(let message):
      return message
    }
  }
}

struct ValidationColors {
  static let okColor = UIColor(
    red: 138.0 / 255.0,
    green: 221.0 / 255.0,
    blue: 109.0 / 255.0,
    alpha: 1.0)
  static let errorColor = UIColor.red
  static let otherColor = UIColor.black
}

extension ValidationResult {
  var textColor: UIColor {
    switch self {
    case .ok:
      return ValidationColors.okColor
    case .failed:
      return ValidationColors.errorColor
    case .empty, .validating:
      return ValidationColors.otherColor
    
    }
  }
  
  var isValid: Bool {
    switch self {
    case .ok:
      return true
    case .empty, .failed, .validating:
      return false
    }
  }
}

//distinctUntilChanged需要
extension ValidationResult: Equatable {
  static func ==(lhs: ValidationResult, rhs: ValidationResult) -> Bool {
    return lhs.description == rhs.description
  }
}

//扩展label能够根据对应的信息和颜色更新
extension Reactive where Base: UILabel {
  var validationResult: UIBindingObserver<Base, ValidationResult> {
    return UIBindingObserver(UIElement: base) { (label, result) in
      label.textColor = result.textColor
      label.text = result.description
    }
  }
}


