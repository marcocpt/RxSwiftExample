## RxSwift_v1.0笔记——16 Testing with RxTest

100分

以上这是给你的，为了表扬你没有略过此章节。研究表明开发者略过编写测试用例有两个原因：

1. 他们只会写没有错误的代码
2. 编写测试用例不好玩

如果你只是第一个原因，那么你被录用了！如果你也同意第二个原因，那么让我给你介绍一下我的小朋友：RxTest。基于之所以你开始阅读这本书并很激动的将RxSwift用于你的APP项目中的所有原因，RxTest（和RxBlocking）也会很快让你对用RxSwift 代码 编写测试用例感兴趣。它们会提供一个简洁的API，让编写测试用例变得简单而有趣。

这个章节将会给你介绍RxTest，稍后是RxBlocking，用来写测试

本章将向您介绍RxTest以及RxBlocking，通过针对多个RxSwift操作编写测试，并针对RxSwift产品代码编写测试。

### 开始 300

这个章节的启动设计名字叫Testing，它包含一个掌上APP，可以为输入的16进制颜色代码提供红，绿，蓝色值和颜色名字（若有）。运行安装后，打开这个workspace并运行。你可以看到这个APP用 rayWenderlichGreen开始，但是你可以输入任意16进制颜色代码并获得rgb和颜色名字。

![](http://upload-images.jianshu.io/upload_images/2224431-52d3297b42b34ee5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/400)

这个APP是使用MVVM设计模式组织起来的，你可以在MVVM章节学习MVVM的相关知识。简单来说就是逻辑代码被封住在视图模型中，视图控制器用来控制视图。除了枚举流行的颜色名称之外，整个应用程序都运行在这个逻辑上，您将在本章稍后部分中写出测试：

```swift
color = hexString.asObservable()
  .map { hex in
    guard hex.characters.count == 7 else { return .clear }
    let color = UIColor(hex: hex)
    return color
  }
  .asDriver(onErrorJustReturn: .clear)

rgb = color.asObservable()
  .map { color in
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0

    color.getRed(&red, green: &green, blue: &blue, alpha: nil)
    let rgb = (Int(red * 255.0), Int(green * 255.0), Int(blue * 255.0))
    return rgb
  }
  .asDriver(onErrorJustReturn: (0, 0, 0))

colorName = hexString.asObservable()
  .map { hexString in
    let hex = String(hexString.characters.dropFirst())

    if let color = ColorName(rawValue: hex) {
      return "\(color)"
    } else {
      return "--"
    }
  }
  .asDriver(onErrorJustReturn: "")
```

在投入这个代码到testing之前，编写两个针对RxSwift操作的测试用例对学习RxTest 是很用帮助的。

```
Note：这个章节是假设你很熟悉在iOS系统中用XCTest编写单元测试，如果你是新手，可以找下我们的视频课程（原失效）https://www.raywenderlich.com/150521/updated-course-ios-unit-ui-testing
```

### 用RxTest测试操作 301

```
Note：因为Swift包管理的问题，RxTest已经重命名为“RxTests”。因此如果你在野外（out in the wild）看到了“RxTests”，它很可能是指RxTest。
```

RxTest是RxSwift的独立库。 它在RxSwift repo内托管(host)，但需要单独的pod安装和导入。 RxTest为测试RxSwift代码提供了许多有用的补充，例如TestScheduler，它是一个虚拟时间scheduler，可以精确控制测试时间线性操作，包括 next(_:_:)， completed(_:_:)，和 error(_:_:)，可以在测试中的指定时间将这些事件添加到observables。 它还添加了冷和热observables，你可以把它想象成冷热三明治。不，不是真的。

#### 什么的是热和冷的observables？ 301

RxSwift用了大量的篇幅去简化你的Rx代码，并且他们有办法让你明白热的和冷的区别，当谈到observables，在RxSwift里更多的考虑的是observables的特点是而不是具体类型。这有点像一点补充的细节，但是它值得你多加关注，因为在RxSwift 的测试内容以外是没有这么多讨论热的和冷的observable的。

热observables：

- 使用资源是否有订阅者。
- 产生元素是否有订阅者。
- 主要用于状态类型，如Variable。

冷observables：

- 仅仅在订阅时消耗资源
- 有订阅者才产生元素
- 主要使用异步操作，例如网络。

你稍后写的单元测试将使用热observables。 但是，如果您需要使用另一个需求，请了解不同之处。

打开在TestingTests组中的TestingOperators.swift。在类 TestingOperators的顶部定义了两个属性：

```swift
var scheduler: TestScheduler!
var subscription: Disposable!
```

 scheduler是 TestScheduler的一个实例，你将使用在每个test中，并且 subscription将保持你每个test中的订阅。改变setUP()的定义：

```swift
override func setUp() {
  super.setUp()

  scheduler = TestScheduler(initialClock: 0)
}
```

在setUP()方法中，在每个测试用例开始都会调用它。你用TestScheduler (initialClock: 0)初始化一个新的scheduler。它的意思是你希望在测试开始时启动测试 scheduler。这很快就会变得有意义。

现在改变 tearDown()的定义：

```swift
override func tearDown() {

  scheduler.scheduleAt(1000) { 
    self.subscription.dispose()
  }

  super.tearDown()
}
```

 tearDown()在每个测试完成时调用。在它里面，在1000毫秒后你调度测试订阅的销毁。你写的每个测试将运行至少1秒，因此在1秒后销毁测试的订阅是安全的。

现在朋友，是时候写测试了。在 tearDown()的定义后面增加一个新的test到TestingOperators：

```swift
//1
func testAmb() {

  //2
  let observer = scheduler.createObserver(String.self)
}
```

你做了以下内容：

1. 像所有使用XCTest的tests一样，方法名必须以test开头。你建立了一个名叫amb的测试。
2. 你使用scheduler的 createObserver(_:)方法与String类型的示意创建了一个观察者

观察者将记录它接收到的每个事件的时间戳，就像在RxSwift中的debug操作，但不会打印任何输出。在Combining Operators章节你已经学习了amb操作。amb被用在两个observables之间，哪个observable首先发射，它就只传播它发射的事件。你需要创建两个observables。增加下面代码到test：

```swift
//1
let observableA = scheduler.createHotObservable([
  // 2
  next(100, "a)"),
  next(200, "b)"),
  next(300, "c)")
  ])
// 3
let observableB = scheduler.createHotObservable([
  // 4
  next(90, "1)"),
  next(200, "2)"),
  next(300, "3)")
  ])
```

这个代码做了：

1. 使用 scheduler的createHotObservable(_:)创建一个observableA。
2. 使用next(_:_:)方法在指定的时间（毫秒）添加.next事件到observableA上 ，第二个参数作为值传递。
3. 创建 名为observableB的热observable
4. 用规定的值在指定的时间增加 .next事件到 observableB

要知道amb将只传播第一个发射事件的observable的事件。你能够猜到这个这个测试就是为了测这个。

为了测试这个，增加下面的代码来使用amb操作并分配结果到一个本地常量：

```swift
let ambObservable = observableA.amb(observableB)
```

Option-click在ambObservable上，你将看到它是 Observable<String>类型。

![](http://upload-images.jianshu.io/upload_images/2224431-e5e21e06c3f4c389.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/640)

```
Note：如果你的Xcode又出了毛病(on the fritz)，你可能会看到<<error type>>，不要担心，运行测试时Xcode会识别它。
```

下一步，你需要告诉scheduler来调度在指定时间的动作。增加下面代码：

```swift
scheduler.scheduleAt(0) { 
  self.subscription = ambObservable.subscribe(observer)
}
```

这里你调度了 ambObservable在0时订阅到observer，并分配订阅到 subscription属性。这样一来，tearDown()将销毁订阅。

为了确实地开始（kick off）测试然后确认结果，增加下面代码：

```swift
scheduler.start()
```

这将启动虚拟时间调度程序，并且观察者将收到您通过amb操作指定的.next事件。

现在你能够收集和分析结果。输入以下代码：

```swift
let results = observer.events.map {
  $0.value.element!
}
```

在观察者的事件属性上你使用map访问每个事件的元素。现在你能断言这些实际的结果通关增加下面代码来匹配你期望的结果

```swift
XCTAssertEqual(results, ["1)", "2)", "3)"])
```

点击函数 testAmb()左侧沟槽（gutter）中的钻石按钮来执行测试。

![](http://upload-images.jianshu.io/upload_images/2224431-997568e5026b5f64.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

当测试结束后，你应该看到完成了（又叫（aka）通过）

![](http://upload-images.jianshu.io/upload_images/2224431-e0825e94a953172f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

通常你将创建一个负面测试来补充这个，例如测试接收到的结果与你知道的他们应该不是这个的结果不一致。这章节完成之前你还有更多的测试要写，因此要快速测试你的测试是否工作，按以下内容更改断言：

```swift
XCTAssertEqual(results, ["1)", "2)", "No you didn't!"])
```

再次运行测试确保出现以下错误信息：

```swift
XCTAssertEqual failed: ("["1)", "2)", "3)"]") is not equal to ("["1)", "2)", "No you didn't!"]")
```

撤销上面的改变再运行测试确保它再次通过。

你花了一整章节来学习过滤操作，为什么不测试一个呢？增加下面的测试到 TestingOperators，它与 testAmb()保持了一样的格式：

```swift
func testFilter() {
  // 1
  let observer = scheduler.createObserver(Int.self)
  // 2
  let observable = scheduler.createHotObservable([
    next(100, 1),
    next(200, 2),
    next(300, 3),
    next(400, 2),
    next(500, 1)
    ])
  // 3
  let filterObservable = observable.filter {
    $0 < 3
  }
  // 4
  scheduler.scheduleAt(0) {
    self.subscription = filterObservable.subscribe(observer)
  }
  // 5
  scheduler.start()
  // 6
  let results = observer.events.map {
    $0.value.element!
  }
  // 7
  XCTAssertEqual(results, [1, 2, 2, 1])
}
```

从头开始：

1. 创建一个观察者，时间类型为Int。
2. 创建一个热observable，它每秒schedulers一个.next事件，共5秒。
3. 创建 filterObservable来保存在observable上使用过滤的结果，过滤条件为判断元素的值小于3。
4. 在0时开始调度订阅并分配它到订阅属性以便它将在 tearDown()被销毁。
5. 启动scheduler。
6. 收集结果。
7. 断言你期望的结果。

点击这个测试旁沟槽的钻石图标运行测试，你将得到绿勾指示了测试成功。

这些测试已经同步。当你想测试异步操作，你有两个选择。你将首先学习容易的一个，使用RxBlocking。

#### 使用RxBlocking 306

RxBlocking是封装（housed）在RxSwift repo内部的另一个库，像RxTest一样，有它自己的pod且必须分开导入。它的主要目的是通过它的 toBlocking(timeout:)方法，转换一个observable到 BlockingObservable。这样做会阻塞当前线程，直到observable终止，或者如果指定了一个超时值（默认情况下为零），并且在observable终止之前达到超时，则会引发RxError.timeout错误。 这基本上将异步操作转换为同步操作，使测试变得更加容易。

增加下面在RxBlocking内的三行测试代码到 TestingOperators来测试 toArray操作：

```swift
func testToArray() {
  // 1
  let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
  // 2
  let toArrayObservable = Observable.of("1)",
                                        "2)").subscribeOn(scheduler)
  // 3
  XCTAssertEqual(try! toArrayObservable.toBlocking().toArray(), ["1)",
                                                                 "2)"])
}
```

它做了的如下：

1. 使用默认的服务质量，创建并发scheduler来运行异步测试
2. 创建observable来保持在scheduler上，订阅到两个字符串的observable的结果。
3. 对toArrayObservable调用toBlocking（）的结果使用toArray，并断言toArray的返回值等于预期结果。

 toBlocking()转换 toArrayObservable为一个阻塞observable，阻止由scheduler产生的线程，直到它终止。运行测试你应该看到成功。仅用三行代码就测试了一个异步操作——哇！你将用简洁的RxBlocking做更多工作，但现在是时候离开操作的测试并写一些针对（against）应用产品代码的测试。

### 测试RxSwift的产品代码 307

首先打开在Testing组中的ViewModel.swift。在顶部，你将看到一些属性定义：

```swift
let hexString = Variable<String>("")
let color: Driver<UIColor>
let rgb: Driver<(Int, Int, Int)>
let colorName: Driver<String>
```
 hexString接收来至视图控制器的输入。color，rgb和colorName是输出，视图控制器将绑定到视图。在视图模型的初始中，通过转换另一个observable并把返回结果作为Driver。这是显示在章节开始处的代码。

接下来初始化的是一个枚举类型，定义到模型的常见的颜色名。

```swift
enum ColorName: String {
  case aliceBlue = "F0F8FF"
  case antiqueWhite = "FAEBD7"
  case aqua = "0080FF"
  // And many more...
```

现在打开ViewController.swift，聚焦到 viewDidLoad()的实现上。

```swift
override func viewDidLoad() {
  super.viewDidLoad()

  configureUI()

  guard let textField = self.hexTextField else { return }

  textField.rx.text.orEmpty
    .bindTo(viewModel.hexString)
    .addDisposableTo(disposeBag)

  for button in buttons {
    button.rx.tap
      .bindNext {
        var shouldUpdate = false

        switch button.titleLabel!.text! {
        case "⊗":
          textField.text = "#"
          shouldUpdate = true
        case "←" where textField.text!.characters.count > 1:
          textField.text = String(textField.text!.characters.dropLast())
          shouldUpdate = true
        case "←":
          break
        case _ where textField.text!.characters.count < 7:
          textField.text!.append(button.titleLabel!.text!)
          shouldUpdate = true
        default:
          break
        }

        if shouldUpdate {
          textField.sendActions(for: .valueChanged)
        }
      }
      .addDisposableTo(self.disposeBag)
  }

  viewModel.color
    .drive(onNext: { [unowned self] color in
      UIView.animate(withDuration: 0.2) {
        self.view.backgroundColor = color
      }
    })
    .addDisposableTo(disposeBag)

  viewModel.rgb
    .map { "\($0.0), \($0.1), \($0.2)" }
    .drive(rgbTextField.rx.text)
    .addDisposableTo(disposeBag)

  viewModel.colorName
    .drive(colorNameTextField.rx.text)
    .addDisposableTo(disposeBag)
}
```

从头开始：

1. 绑定文本框的文本（或者一个空的字符串）到视图模型的hexString输入observable
2. 循环遍历按钮出口的集合，绑定tap并转换按钮的标题来决定怎样更新文本框的文字，与文本框是否应该发送valueChanged控制事件。
3. 使用视图模型的color驱动来更新视图的背景颜色。
4. 使用视图模型的rgb驱动来更新rbgTextField的文本。
5. 使用实体模型的coloName驱动来更新colorNameTextField的文本。

通过预览app是如何工作的，你现在能够针对它来写测试。在TestingTests组内打开TestingViewModel.swift，按如下修改setUP()的实现：

```swift
override func setUp() {
  super.setUp()
  viewModel = ViewModel()
  scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
}
```

这里，你分配app ViewModel类的一个实体给viewModel属性，用默认服务质量的一个并发scheduler给scheduler属性。

现在你可以开始针对app的视图模型来写测试了。首先，你将使用传统的XCTest API编写一个异步测试。增加视图模型颜色驱动（使用传统方式）的测试到TestingViewModel：

```swift
func testColorIsRedWhenHexStringIsFF0000_async() {
  let disposeBag = DisposeBag()
  // 1
  let expect = expectation(description: #function)
  // 2
  let expectedColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha:
    1.0)
  // 3
  var result: UIColor!
}
```

你做了一下工作：

1. 创建一个稍后实现的预期。
2. 创建 expectedColor等于红色的预期的测试结果。
3. 定义结果稍后分配。

这仅仅是起始代码。现在将以下代码添加到测试以订阅视图模型的color驱动程序：

```swift
// 1
viewModel.color.asObservable()
  .skip(1)
  .subscribe(onNext: {
    // 2
    result = $0
    expect.fulfill()
  })
  .addDisposableTo(disposeBag)
// 3
viewModel.hexString.value = "#ff0000"
// 4
waitForExpectations(timeout: 1.0) { error in
  guard error == nil else {
    XCTFail(error!.localizedDescription)
    return
  }
  // 5
  XCTAssertEqual(expectedColor, result)
}
```

1. 创建一个订阅到视图模型的color驱动。注意你略过了第一个元素，因为驱动将在订阅上重放初始元素。
2. 分配.next事件元素到result并在expect上调用fulfill()。
3. 在视图模型的hexString上增加一个新的值输入给observable（一个Variable）。
4. 用1秒来超时等待expectation的完成，并在闭包中为error提供guard
5. 断言期望的color等于实际的result。

很简单但有点冗长。运行测试确保它通过。

现在使用RxBlocking来实现同样的事情：

```swift
func testColorIsRedWhenHexStringIsFF0000() {
  // 1
  let colorObservable =
    viewModel.color.asObservable().subscribeOn(scheduler)
  // 2
  viewModel.hexString.value = "#ff0000"
  // 3
  do {
    guard let result = try colorObservable.toBlocking(timeout:
      1.0).first() else { return }
    XCTAssertEqual(result, .red)
  } catch {
    print(error)
  }
}
```

1. 创建coloObservable来保存订阅在并发scheduler上的observable结果。
2. 在视图模型的hexString上增加一个新值输入给observable。
3. 使用guard来选择将调用toBlocking()的结果与1秒的超时绑定，如果抛出，捕获并打印错误，然后断言实际的结果与预期的匹配。

运行测试确保它是成功的。这个测试本质上与前一个相同。你只是不需要那么努力。

接下来，添加此代码以测试视图模型的rgb驱动为给定的hexString输入发出预期的红色，绿色和蓝色值：

```swift
func testRgbIs010WhenHexStringIs00FF00() {
  // 1
  let rgbObservable =
    viewModel.rgb.asObservable().subscribeOn(scheduler)
  // 2
  viewModel.hexString.value = "#00ff00"
  // 3
  let result = try! rgbObservable.toBlocking().first()!
  XCTAssertEqual(0 * 255, result.0)
  XCTAssertEqual(1 * 255, result.1)
  XCTAssertEqual(0 * 255, result.2)
}
```

1. 创建rgbObservable来保存在scheduler上的订阅。
2. 在视图模型的hexString上增加一个新值输入给observable。
3. 检索在rgbObservable上调用toBlocking的第一个结果，然后断言每个值与期望的匹配。

0~1转换到0~255仅仅是为了匹配测试名并让接下来的事情更加容易。运行这个测试确保它成功通过。

还有一个要测试的驱动程序 将此测试添加到TestingViewModel，来测试视图模型的colorName驱动为给定的hexString输入发出正确的元素：

```
func testColorNameIsRayWenderlichGreenWhenHexStringIs006636() {
  // 1
  let colorNameObservable =
    viewModel.colorName.asObservable().subscribeOn(scheduler)
  // 2
  viewModel.hexString.value = "#006636"
  // 3
  XCTAssertEqual("rayWenderlichGreen", try!
    colorNameObservable.toBlocking().first()!)
}
```

1. 创建observable
2. 增加测试值。
3. 断言实际的结果来匹配期望的结果。

这是我想起了短语”漂洗和重复“，这是一个好的方式。写测试就是应该简单。按Command-U运行在项目中的所有测试，所有测试都应该通过。

使用RxText and RxBlocking写测试是使用RxSWift和RxCocoa写数据和UI绑定（以及其他）。这章没有挑战，因为你将在MVVM章中做更多的视图模型测试。测试真高兴！