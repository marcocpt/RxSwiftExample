//
//  ViewController.swift
//  CustomRxDelegate
//
//  Created by wgd on 2017/9/2.
//  Copyright © 2017年 dhh. All rights reserved.
//

import UIKit
import NSObject_Rx

class RxDelegateViewController: UIViewController {

  @IBOutlet weak var delegateButton: RxDelegateButton!

  override func viewDidLoad() {
    super.viewDidLoad()
    
//    delegateButton.delegate = self

    delegateButton.rx.delegate
      .sentMessage(#selector(RxDelegateButtonDelegate.trigger))
      .map { _ in }
      .subscribe(onNext: {
        print("\(Date()) - delegate_trigger")
      })
      .addDisposableTo(rx_disposeBag)
    
    delegateButton.rx.SM_trigger
      .subscribe(onNext: {
        print("\(Date()) - SM_trigger")
      })
      .addDisposableTo(rx_disposeBag)
    
    delegateButton.rx.MI_trigger
      .subscribe(onNext: {
        print("\(Date()) - MI_trigger")
      })
      .addDisposableTo(rx_disposeBag)

  }

}

//extension RxDelegateViewController: RxDelegateButtonDelegate {
//  func trigger() {
//    print("trigger")
//  }
//}
