//
//  UsingRxBlockingTests.swift
//  UsingRxBlockingTests
//
//  Created by wgd on 2017/9/7.
//  Copyright © 2017年 dhh. All rights reserved.
//

import XCTest
import RxSwift
import RxTest
import RxBlocking

@testable import UsingRxBlocking

class UsingRxBlockingTests: XCTestCase {
  
  var viewModel: TestViewModel!
  var concurrentScheduler: ConcurrentDispatchQueueScheduler!
  
  override func setUp() {
    super.setUp()
    viewModel = TestViewModel()
    //创建一个并发调度者（concurrent scheduler）
    concurrentScheduler = ConcurrentDispatchQueueScheduler(qos: .default)
  }
  
  override func tearDown() {
    viewModel = nil
    concurrentScheduler = nil
    super.tearDown()
  }
  
  func testToArray() {
    //1
    let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
    //2
    let toArrayObservable = Observable.of("1)","2)").subscribeOn(scheduler)
    //3
    XCTAssertEqual(try! toArrayObservable.toBlocking().toArray(), ["1)","2)"])
  }
  
  //使用传统的XCTest API写异步测试代码
  func testConvertIntToString() {
    let disposeBag = DisposeBag()
    //1：
    let expect = expectation(description: #function)
    //2：
    let expectedString = "100"
    //3：
    var result: String!
    //4：
    viewModel.outputValue
      .skip(1)
      .asObservable()
      .subscribe(onNext: {
        //5:
        result = $0
        expect.fulfill()
      }).disposed(by: disposeBag)
    //6：
    viewModel.inputInt.value = 100
    //7：
    waitForExpectations(timeout: 1.0) { error in
      guard error == nil else {
        XCTFail(error!.localizedDescription)
        return
      }
      //8：
      XCTAssertEqual(expectedString, result)
    }
  }
  
  //使用RxBlocking实现相同的功能
  func testConvertIntToStringUseRxBlocking() {
    //1
    let observable = viewModel.outputValue
      .asObservable()
      .subscribeOn(concurrentScheduler)
    //2
    viewModel.inputInt.value = 100
    //3
    do {
      guard let result = try observable
        .toBlocking(timeout: 1.0)
        .first() else { return }
      XCTAssertEqual(result, "100")
    } catch {
      print(error)
    }
  }
}
