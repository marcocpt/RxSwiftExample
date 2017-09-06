//
//  ViewController.swift
//  RxSwiftRegister
//
//  Created by wgd on 2017/8/13.
//  Copyright © 2017年 wgd. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class RegisterViewController: UIViewController {
  
  @IBOutlet weak var username: UITextField!
  @IBOutlet weak var usernameValidation: UILabel!
  
  @IBOutlet weak var password: UITextField!
  @IBOutlet weak var passwordValidation: UILabel!
  
  @IBOutlet weak var repeatedPassword: UITextField!
  @IBOutlet weak var repeatedPasswordValidation: UILabel!
  
  @IBOutlet weak var registerIndicator: UIActivityIndicatorView!
  @IBOutlet weak var register: UIButton!
  
  let disposeBag = DisposeBag()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let viewModel = RegisterViewModel(input:(
      username: username.rx.text.orEmpty.asDriver(),
      password: password.rx.text.orEmpty.asDriver(),
      repeatedPassword: repeatedPassword.rx.text.orEmpty.asDriver(),
      registerTap: register.rx.tap.asDriver()
    ))
    
    register.rx.tap.asDriver()
      .drive(viewModel.registerTap)
      .disposed(by: disposeBag)
    
    viewModel.validatedUsername
      .drive(usernameValidation.rx.validationResult)
      .disposed(by: disposeBag)
    
    viewModel.validatedPassword
      .drive(passwordValidation.rx.validationResult)
      .disposed(by: disposeBag)
    
    viewModel.validatedPasswordRepeated
      .drive(repeatedPasswordValidation.rx.validationResult)
      .disposed(by: disposeBag)
    
    viewModel.registerEnabled.drive(
      onNext:{
        [unowned self] valid in
        self.register.isEnabled = valid
        self.register.alpha = valid ? 1.0 : 0.5
      }
      ).disposed(by: disposeBag)
    
    viewModel.registering
      .drive(registerIndicator.rx.isAnimating)
      .disposed(by: disposeBag)
    
    viewModel.registered.drive(
      onNext:{
        registered in
        print("User register is \(registered)")
    }
      ).disposed(by: disposeBag)
    
    //点击背景收起键盘
    let tapBackground = UITapGestureRecognizer()
    tapBackground.rx.event
      .subscribe(onNext: { [unowned self] _ in
        self.view.endEditing(true)
      })
      .disposed(by: disposeBag)
    view.addGestureRecognizer(tapBackground)
    
    username.rx.controlEvent(.editingDidEnd)
      .subscribe{
        [unowned self] _ in
        self.password.becomeFirstResponder()
      }
      .disposed(by: disposeBag)
    
    password.rx.controlEvent(.editingDidEnd)
      .subscribe{
        [unowned self] _ in
        self.repeatedPassword.becomeFirstResponder()
      }
      .disposed(by: disposeBag)
    
    repeatedPassword.rx.controlEvent(.editingDidEndOnExit)
      .bind(to: viewModel.registerTap)
      .disposed(by: disposeBag)
  }

}

