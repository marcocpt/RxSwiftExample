//
//  ViewController.swift
//  RxSwiftCalculator
//
//  Created by wgd on 2017/8/13.
//  Copyright © 2017年 wgd. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {
  
  @IBOutlet weak var numberOne: UITextField!
  @IBOutlet weak var numberTwo: UITextField!
  @IBOutlet weak var numberThree: UITextField!
  @IBOutlet weak var result: UILabel!

  let disposeBag = DisposeBag()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    // orEmpty可以把String?转成String
    numberOne.rx.text
      .orEmpty
      .asObservable()
      .filter {
        return $0 != ""
      }
      .subscribe {
        print($0)
      }
      .disposed(by: disposeBag)
    
    Observable
      .combineLatest(numberOne.rx.text.orEmpty,numberTwo.rx.text.orEmpty,numberThree.rx.text.orEmpty) {
        (numberOneText, numberTwoText, numberThreeText) -> Int in
        return (Int(numberOneText) ?? 0) + (Int(numberTwoText) ?? 0) + (Int(numberThreeText) ?? 0)
      }
      .map{
        $0.description
      }
      .bind(to: result.rx.text)
      .disposed(by: disposeBag)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


}

