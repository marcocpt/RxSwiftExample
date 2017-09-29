/*
 * Copyright (c) 2014-2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import XCTest
import RxSwift
import RxBlocking
import Nimble
import RxNimble
import OHHTTPStubs
import SwiftyJSON

@testable import iGif

class iGifTests: XCTestCase {
  
  let obj = ["array":["foo","bar"], "foo":"bar"] as [String : Any]
  let request = URLRequest(url: URL(string: "http://raywenderlich.com")!)
  let errorRequest = URLRequest(url: URL(string: "http://rw.com")!)
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
    stub(condition: isHost("raywenderlich.com")) { _ in
      return OHHTTPStubsResponse(jsonObject: self.obj, statusCode: 200, headers: nil)
    }
    stub(condition: isHost("rw.com")) { _ in
      return OHHTTPStubsResponse(error: RxURLSessionError.unknown)
    }
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
    OHHTTPStubs.removeAllStubs()
  }
  
  func testData() {
    let observalbe = URLSession.shared.rx.data(request: self.request)
    expect(observalbe.toBlocking().firstOrNil()).notTo(beNil())
  }
  
  func testString() {
    let observable = URLSession.shared.rx.string(request: self.request)
    let string = "{\"array\":[\"foo\",\"bar\"],\"foo\":\"bar\"}"
    expect(observable) == string
  }
  
  func testJSON() {
    let observable = URLSession.shared.rx.json(request: self.request)
    let string = "{\"array\":[\"foo\",\"bar\"],\"foo\":\"bar\"}"
    let json = JSON(data: string.data(using: .utf8)!)
    expect(observable) == json
  }  
  func testError() {
    var erroredCorrectly = false
    let observable = URLSession.shared.rx.json(request: self.errorRequest)
    do {
      let _ = try observable.toBlocking().first()
      assertionFailure()
    } catch (RxURLSessionError.unknown) {
      erroredCorrectly = true
    } catch {
      assertionFailure()
    }
    expect(erroredCorrectly) == true
  }

  func test() {
    let a = Observable.of(1.2)
    expect(a) ≈ 1.191 ± 0.01
  }
}

extension BlockingObservable {
  func firstOrNil() -> E? {
    do {
      return try first()
    } catch {
      return nil
    }
  }
}

public func firstBeCloseTo<O: ObservableType>(_ expectedValue: Double, within delta: Double = DefaultDelta) -> Predicate<O> where O.E == Double {
  return Predicate.define(matcher: { (actualExpression) -> PredicateResult in
    let actualValue = try actualExpression.evaluate()?.toBlocking().first()
    let errorMessage = "be close to <\(stringify(expectedValue))> (within \(stringify(delta)))"
		let matches = (actualValue != nil) && (abs(actualValue!.doubleValue - expectedValue.doubleValue) < delta)
    return PredicateResult(bool: matches,
                           message: .expectedCustomValueTo(errorMessage, "<\(stringify(actualValue))>"))
  })
}

infix operator ≈ : ComparisonPrecedence
public func ≈<O: ObservableType>(lhs: Expectation<O>, rhs: Double) where O.E == Double {
  lhs.to(firstBeCloseTo(rhs))
}

public func ≈<O: ObservableType>(lhs: Expectation<O>, rhs: (expected: Double, delta: Double)) where O.E == Double {
  lhs.to(firstBeCloseTo(rhs.expected, within: rhs.delta))
}

infix operator ± : PlusMinusOperatorPrecedence
public func ±(lhs: Double, rhs: Double) -> (expected: Double, delta: Double) {
  return (expected: lhs, delta: rhs)
}



