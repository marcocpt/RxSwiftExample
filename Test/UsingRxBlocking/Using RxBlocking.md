# Using RxBlocking

http://blog.csdn.net/longshihua/article/details/72910590

RxBlocking是RxSwift中另外一个单独的框架。跟RxTest一样，也需要进行pod引入框架，需要单独倒入。最初的目的是使用toBlocking(timeout:)方法转换观察者序列（observable）到BlockingObservable。

使用RxBlocking，我们可以轻松的测试异步代码。RxBlocking将阻塞当前线程一直到观察者序列（observable）终止，或者我们指定超时时间（默认情况下是nil），如果在观察者序列终止之前到达，那么将抛出错误（RxError.timeout error）。**所以本质上是将异步操作转换为同步操作，这样使得测试代码更简单**

**RxBlocking提供了一些操作符用于测试。但是注意这些操作符仅仅是用于测试目的，不能够用于生产代码**

```Swift
extension ObservableType {  
    public func toArray() throws -> [E] {}  
}  

extension ObservableType {  
    public func first() throws -> E? {}  
}  

extension ObservableType {  
    public func last() throws -> E? {}  
}  
```



# Test toArray Operator 

```swift
func testToArray() {  
    //1  
    let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)  
    //2   
    let toArrayObservable = Observable.of("1)","2)").subscribeOn(scheduler)  
    //3  
    XCTAssertEqual(try! toArrayObservable.toBlocking().toArray(), ["1)","2)"])  
} 
```



1：创建一个并发调度者（toArray operator ）来执行异步测试，使用默认的质量服务（thedefault quality of service.）

2：创建一个观察者序列持有两个元素，并且在scheduler上订阅观察者序列

3：首先对toArrayObservable使用toBlocking()，toBlocking()源码如下：

```swift
extension ObservableConvertibleType {  
    /// Converts an Observable into a `BlockingObservable` (an Observable with blocking operators).  
    ///  
    /// - parameter timeout: Maximal time interval BlockingObservable can block without throwing `RxError.timeout`.  
    /// - returns: `BlockingObservable` version of `self`  
    public func toBlocking(timeout: RxTimeInterval? = nil) -> BlockingObservable<E> {  
        return BlockingObservable(timeout: timeout, source: self.asObservable())  
    }  
}
```
toBlocking()是将观察者序列转换为BlockingObservable，拥有timeout参数，默认为nil，指定最大的阻塞时间间隔

```swift
/** 
`BlockingObservable` is a variety of `Observable` that provides blocking operators.  
It can be useful for testing and demo purposes, but is generally inappropriate for production applications. 
If you think you need to use a `BlockingObservable` this is usually a sign that you should rethink your 
design. 
*/  
public struct BlockingObservable<E> {  
    let timeout: RxTimeInterval?  
    let source: Observable<E>  
} 
```
BlockingObservable是结构体拥有timeout和source两个属性。然后使用toArray()，将BlockingObservable<String>转换为[String]

```swift
extension BlockingObservable {  
    /// Blocks current thread until sequence terminates.  
    ///  
    /// If sequence terminates with error, terminating error will be thrown.  
    ///  
    /// - returns: All elements of sequence.  
    public func toArray() throws -> [E] {  
        var elements: [E] = Array<E>()  
        var error: Swift.Error?  
        let lock = RunLoopLock(timeout: timeout)  
        let d = SingleAssignmentDisposable()  
        defer {  
            d.dispose()  
        }  
        lock.dispatch {  
            let subscription = self.source.subscribe { e in  
                if d.isDisposed {  
                    return  
                }  
                switch e {  
                case .next(let element):  
                    elements.append(element)  
                case .error(let e):  
                    error = e  
                    d.dispose()  
                    lock.stop()  
                case .completed:  
                    d.dispose()  
                    lock.stop()  
                }  
            }  
            d.setDisposable(subscription)  
        }  
        try lock.run()  
        if let error = error {  
            throw error  
        }  
        return elements  
    }  
}  
```
最后与预期结果进行对比

# Test asynchronous code

功能：简单实现Int转换为String模拟真实的异步测试

简单的TestViewModel文件

```swift
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
```
使用传统的XCTest API写异步测试代码

```swift
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
}
```
整个测试文件代码如上：

1：创建一个expectation用于后续的实现，正如名字所表达的意思，预期，等带

2：预期结果字符串

3：定义结果值用于后续的赋值

4：为viewModel的outputValue进行订阅。但是注意：这里跳过了第一个元素，因为outputValue是Variable，会在被订阅之后重新发送初始值

5：赋值结果，用于后续比较，并调用fulfill()方法。调用fulfill()，表示期待已经完成，会执行waitForExpectations中的闭包内容,而且如果超时，闭包也会被执行即使你没有调用fulfill() 。如果有多个期待，那么就等多个期待即预期描述（expectation(description: #function)）都调用fulfill()才会执行闭包。

6：设置输入值为100

7：等待期待被fulfill，有1秒的延时，闭包内判断是否是错误事件，如果是错误，调用错误的函数

8：对比预期结果

上面看起来还不错，接下来，我们使用RxBlocking实现相同的功能

```swift
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
```
1：创建观察者序列，在并发调度者上订阅观察者序列

2：输入新值

3：使用guard来解析可选值，使用toBlocking，拥有1分钟的超时，使用do-catch捕获错误，有错误打印错误，解析成功比较结果

对比以下是不是感觉更简单一点

参考：

[RxBlocking](https://github.com/ReactiveX/RxSwift/tree/master/RxBlocking)