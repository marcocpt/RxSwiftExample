## RxSwift_v1.0笔记——17 Creating Custom Reactive Extensions



介绍RxSwift, RxCocoa,之后，我们学习了如何测试，你也看到了通过Apple或第三方使用RxSwift在框架顶层如何创建扩展。在关于RxCocoa的章节介绍了封装一个Apple或第三方框架的组件，因此通过这个章节的项目用你工作的方式来扩展你所学到的。

在这章，你将给NSURLSession创建一个扩展来管理同端点的通讯，也管理了缓存和其他东西，它是常规应用的普通的部分。这个例子是为教学用的；如果你想使用RxSwift到网络上，有一些库可以给你来使用，包含RxAlamofire，本书也会覆盖这方面的知识。

### 开始 315

首先你要在https://developers.giphy.com/ 注册并申请API key

打开ApiController.swift，复制你的key到下面位置：

```swift
private let apiKey = "[YOUR KEY]"
```

然后用pod install命令安装第三方库。

### 怎样创建扩展 315

在Cocoa类或框架之上创建扩展可能看起来像是不平凡的任务；您将看到该过程可能很棘手，您的解决方案可能需要一些前期的思考才能继续。

这节的目标是用rx命名空间扩展URLSession，孤立的RxSwift扩展，确保了你或你的团队在将来需要扩展这个类时，几乎也不会产生冲突。

#### 如何用.rx来扩展URLSession 315

打开URLSession+Rx.swift，增加下面代码

```swift
extension Reactive where Base: URLSession {
}
```

响应式扩展通过非常清晰的协议扩展，在URLSession上暴露.rx命名空间。这是用RxSwift扩展URLSession的第一步。现在是时候创建实际的封装了。

#### 如何创建封装的方法 315

您已经在NSURLSession上暴露了.rx命名空间，因此现在可以创建一些封装的函数来返回要公开的数据类型的Observable。

APIs能够返回多种类型的数据，正确的做法是检查你app需要的数据类型。你希望为下列类型数据创建封装：

- Data：仅仅是数据
- String：数据作为文本
- JSON：JSON对象的一个实例
- Image：图像的一个实例

这些封装将确保你期望的类型被投递。否则将发送错误，且app将输出错误而不会崩溃。

这个，和一个将被用来创建所有其他的东西的封装，是一个返回HTTPURLResponse和结果数据的封装。你的目标是给一个 Observable<Data>，它将被用来创建剩下的三个操作：

![](http://upload-images.jianshu.io/upload_images/2224431-88a66da950cac692.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

首先创建主要响应函数的框架，这样你就知道要返回的内容了。在你刚刚创建的扩展内部增加：

```swift
func response(request: URLRequest) -> Observable<(HTTPURLResponse, Data)>
{
  return Observable.create { observer in
    // content goes here
    return Disposables.create()
  }
}
```

现在很清楚扩展应该返回什么了。URLResponse是需要你检查的部分，当数据到达时，用来确保处理成功，当然，实际的数据用它返回。

URLSession是基于回调和任务的。例如内建方法 dataTask(with:completionHandler:) 会发送一个请求并接收来至服务器的响应。这个函数使用回调来管理结果，因此你的observable的逻辑必须在请求闭包内部被管理。

为了实现以上内容，在Observable.create内部增加：

```swift
let task = self.base.dataTask(with: request) { (data, response, error) in
}
task.resume()
```

创建的任务必须被恢复（或启动），因此resume()函数将发出请求，然后通过回调来适当地处理结果。

```
Note：使用resume()函数是所谓的“命令式编程”。 稍后你会看到这些意味着什么。
```

现在这个任务已经就位了，在继续之前需要做一个改变。 在上一个块中，您返回了一个Disposable.create()，如果Observable被销毁，这将什么都不做。 最好取消请求，以免浪费任何资源。

为了实现以上内容，用以下内容替换return Disposables.create()：

```swift
return Disposables.create(with: task.cancel)
```

现在，您已经拥有了具有正确生命周期策略的Observable，现在是时候确保在给这个实例发送任何事件前，数据是正确的了。 要实现这一点，请将以下内容添加到task.resume()上方的task闭包中：

```swift
guard let response = response, let data = data else {
  observer.on(.error(error ?? RxURLSessionError.unknown))
  return
}
guard let httpResponse = response as? HTTPURLResponse else {
  observer.on(.error(RxURLSessionError.invalidResponse(response:
    response)))
  return
}
```

两个guard申明在通知所有订阅前，确保了请求已经成功执行。

保证请求正确完成后，这个observable需要一些数据。在你刚增加的代码下面增加以下代码：

```swift
observer.on(.next(httpResponse, data))
observer.on(.completed)
```

这将事件发送到所有订阅，然后立即完成。 触发请求并接收其响应是单次Observable的用法。 保持可观察的活动并执行其他请求是没有意义的，这更适合于socket通信等。

这是封装URLSession的最基本的操作。 您将需要包装更多的东西，以确保应用程序正在处理正确的数据类型。 好消息是，您可以重用此方法来构建其他便利方法。 首先添加一个返回Data实例的：

```swift
func data(request: URLRequest) -> Observable<Data> {
  return response(request: request).map { (response, data) -> Data in
    if 200 ..< 300 ~= response.statusCode {
      return data
    } else {
      throw RxURLSessionError.requestFailed(response: response, data:
        data)
    }
  }
}
```

Data observable是所有其他的根基。Data能够装换为String，JSON对象或UIImage。

增加下面方法来返回String：

```swift
func string(request: URLRequest) -> Observable<String> {
  return data(request: request).map { d in
    return String(data: d, encoding: .utf8) ?? ""
  }
}
```

JSON数据结构是一个简单的结构，所以专用的转换是受欢迎的。 增加：

```swift
func json(request: URLRequest) -> Observable<JSON> {
  return data(request: request).map { d in
    return JSON(data: d)
  }
}
```

最后，实现最后一个用来返回UIImage实例的方法：

```swift
func image(request: URLRequest) -> Observable<UIImage> {
  return data(request: request).map { d in
    return UIImage(data: d) ?? UIImage()
  }
}
```

当您像您刚才那样模块化扩展时，您可以实现更好的组合性。 例如，最后一个可观察值可以通过以下方式可视化：

![](http://upload-images.jianshu.io/upload_images/2224431-913ac4250560b299.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

一些RxSwift的操作，如map，可以智能的组合，以避免处理开销，因为多个map链将被优化为单个调用。 不要担心链接或包含太多的闭包。

#### 如何创建自定义运算 319

在关于RxCocoa的章节里，你创建了一个缓存数据的函数。考虑到GIFs的尺寸，这看起来像是一个好的方法。同样，一个好的应用应该尽可能的减少加载时间。

在这个情况下，好的方法是创建一个专用的操作来缓存数据，它仅仅用于 (HTTPURLResponse, Data)类型的observables。这个的目的是尽可能多的缓存，因此创建这个操作仅仅为(HTTPURLResponse, Data)类型是合理的，并且使用这个响应对象来检索请求绝对的URL，然后将它作为字典的key来使用。

缓存策略是一个简单的字典；你能够稍后扩展它的基本行为来固化缓存，并当重新打开app时加载它，但是这超出了当前项目的范围。

在顶部， RxURLSessionError的定义之前，创建缓存字典：

```swift
fileprivate var internalCache = [String: Data]()
```

然后创建扩展，它的目标仅为Data类型的observables

```swift
extension ObservableType where E == (HTTPURLResponse, Data) {
}
```

在这个扩展内部，你可以创建以下 cache() 函数：

```swift
func cache() -> Observable<E> {
  return self.do(onNext: { (response, data) in
    if let url = response.url?.absoluteString, 200 ..< 300 ~=
      response.statusCode {
      internalCache[url] = data
    }
  })
}
```

为了使用这个缓存，确保在返回它拥有的结果前像下面这个样（你可以简单的插入.cache()部分），来修改 data(request:)的返回状态来缓存响应：

```swift
return response(request: request).cache().map { (response, data) -> Data
in
//...
}
```

为了检测数据是否已经有效，增加下面代码到 data(request:)顶部，return前，来替代每次启动一个网络请求：

```swift
if let url = request.url?.absoluteString, let data = internalCache[url] {
  return Observable.just(data)
}
```

现在你有了一个基本的缓存系统，它仅仅扩展了一个确定类型的Observable：

![](http://upload-images.jianshu.io/upload_images/2224431-92a8a90e0be2853f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

你可以重复同样的步骤来缓存其他类型的数据，这是一个极其普遍的解决方案。

### 使用自定义封装 320

你已经创建了一些关于URLSession的封装，也对一些特定类型的observables自定义了操作目标。是时候抓取一些结果来显示一些有趣的猫的GIFs了。

当前项目已经包含了batteries，因此你仅仅需要提供来自Giphy的API提供的JSON结构的列表。

打开ApiController.swift并查看 search()方法。代码内部准备了一个适当的请求到Giphy的API，但在最底部，它没有做网络调用，而是仅仅返回一个空的observable（因为这是一个占位代码）。

现在你已经完成了你的URLSession响应式扩展，在这个定制的方法中，你能够用它来从网络获取数据。像下面这样修个返回状态：

```swift
return URLSession.shared.rx.json(request: request).map() { json in
  return json["data"].array ?? []
}
```

这将为给定的查询字符串处理请求，但是数据任然没有显示。在GIF实际上显示屏幕之前，最后一步要执行。

增加下面代码到GifTableViewCell.swift中 downloadAndDisplay(gif stringUrl:):的末尾

```swift
let s = URLSession.shared.rx.data(request: request)
  .observeOn(MainScheduler.instance)
  .subscribe(onNext: { imageData in
    self.gifImageView.animate(withGIFData: imageData)
    self.activityIndicator.stopAnimating()
  })
disposable.setDisposable(s)
```

SingleAssignmentDisposable()的使用是强制性的，以保持效果良好。 当GIF的下载开始时，如果用户滚动并且不等待渲染图像，则应确保它已停止。 为了正确平衡这一点，在prepareForReuse())中有这两行（已经包含在起始代码中，现在不需要键入它们）：

```swift
disposable.dispose()
disposable = SingleAssignmentDisposable()
```

SingleAssignmentDisposable()将确保每个单个单元格在给定时间只有一个订阅活动，所以您不会浪费资源。

构建并运行，在搜索栏中输入内容，您将看到应用程序活着。

![](http://upload-images.jianshu.io/upload_images/2224431-4fda76821c3195e3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/300)

### 测试自定义封装 321

虽然它看起来一切正常，但请创建一些测试来确保当你将来开发代码时一切都保持工作正常。这是一个好习惯，尤其是当你封装第三方框架时。

测试用例确保框架围绕的封装保持良好的形状，并且将帮助您找到代码由于更改或错误而发生故障的位置。

#### 如何为自定义封装写测试 322

在上一章中介绍了测试; 在本章中，您将使用用于在Swift上编写测试的通用库，称为Nimble，以及其封装RxNimble。

RxNimble使测试更易于编写，并使你的代码更简洁。代替普通的写法：

```swift
let result = try! observabe.toBlocking().first()
expect(result) != 0
```

你可以写的更短：

```swift
expect(observable) != 0
```

打开测试文件iGifTests.swift。查看import部分，你可以看到Nimble，RxNimble，OHHTTPStubs用于存储网络请求，RxBlocking将异步操作转换为阻塞请求。

在文件末尾你也能够找到用单一的函数来为 BlockingObservable进行的扩展

```swift
func firstOrNil() -> E? {}
```

这样做可以避免滥用try? 方法全部通过测试文件。 你会很快看到这个的使用。

在文件顶部，你将找到一个伪造的JSON对象来测试：

```swift
let obj = ["array": ["foo", "bar"], "foo": "bar"] as [String: Any]
```

使用这个预定义的数据让你更容易为Data，String和JSON请求写测试。

第一个要写的测试时为data请求。增加下列测试到test实例类来检查请求不是返回nil：

```swift
func testData() {
  let observable = URLSession.shared.rx.data(request: self.request)
  //原报错：use beNil() to match nils
  //expect(observable.toBlocking().firstOrNil()) != nil
  expect(observable.toBlocking().firstOrNil()).notTo(beNil())
}
```

在这个方法中，一旦你完成（wrap up）输入，Xcode将在编辑器槽中显示一个菱形按钮，很像这样（行号可能会有所不同）：

![](http://upload-images.jianshu.io/upload_images/2224431-a6e4df457673b05a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

点击这个按钮并运行测试。如果测试成功，按钮将变绿；如果它失败，它将变红。如果你顺利的输入所有正确的代码，你将看到按钮变为绿色的检查标志。

一旦observable返回被测的数据并工作正确，下一步是测试observable来处理字符串。考虑到原始数据是JSON形式，并且keys被分类了，期望的结果应该是：

```swift
{"array":["foo","bar"],"foo":"bar"}
```

接下来的测试写起来真的很简单。添加以下内容，考虑到必须转义JSON字符串：

```swift
func testString() {
  let observable = URLSession.shared.rx.string(request: self.request)
  let string = "{\"array\":[\"foo\",\"bar\"],\"foo\":\"bar\"}"
  expect(observable.toBlocking().firstOrNil()) == string
}
```

点击测试按钮来测试新的测试用例，一旦完成，继续测试JSON解析。这个测试需要一个JSON数据结构来进行比较。增加下列代码来转换字符串版本到Data并处理它为JSON：:

```swift
func testJSON() {
  let observable = URLSession.shared.rx.json(request: self.request)
  let string = "{\"array\":[\"foo\",\"bar\"],\"foo\":\"bar\"}"
  let json = JSON(data: string.data(using: .utf8)!)
  expect(observable.toBlocking().firstOrNil()) == json
}
```

最后一个测试是确保错误返回正确。 比较两个错误是一个相当不寻常的过程，因此对于错误而言具有相等的运算符是没有意义的。 因此测试应该使用do，try并catch未知错误。

增加下列代码：

```swift
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
```

此时您的项目已完成。 您已经在URLSession之上创建了自己的扩展，并且还创建了一些很酷的测试，这将确保您的封装的行为正确。 对你所建立的封装进行测试是非常重要的，因为Apple框架和其他第三方框架可以在主要版本中变化 - 所以如果测试中断并且封装停止工作，您应该准备快速行动。

### 常见的有效封装 324

RxSwift社区非常活跃，有许多扩展和封装已经可用。一些事基于Apple的组件，一些是基于在许多iOS和macOS项目上使用广泛的第三方库。

你可以在下面网站找的最新的（up-to-date）封装列表：http://community.rxswift.org

#### RxDataSources 324

RxDataSources是一个用于RxSwift的UITableView和UICollectionView数据源，具有一些非常好的功能，如：

- 用于计算差异的O(N)算法
- 启发式发送最少数量的命令到sectioned视图
- 支持扩展已实施的视图
- 支持层次动画

这些都是重要的功能，但我最喜欢的是用于区分两个数据源的O(N)算法 - 它确保了在管理表视图时应用程序不执行不必要的计算。
考虑使用内置的RxCocoa表绑定编写的代码：

```swift
let data = Observable<[String]>.just(
  ["1st place", "2nd place", "3rd place"]
)
data.bindTo(tableView.rx.items(cellIdentifier: "Cell")) { index, model,
  cell in
  cell.placeLabel.text = model
}
.addDisposableTo(disposeBag)
```

这个用简单的数据设置完美工作，但是缺少动画和对多个sections的支持，并且不能很好地扩展。

通过RxDataSource正确配置，代码变得更加健壮：

```swift
//configure sectioned data source
let dataSource =
  RxTableViewSectionedReloadDataSource<SectionModel<String, String>>()
//bind data to the table view, using the data source
Observable.just(
  [SectionModel(model: "Position", items: ["1st", "2nd", "3rd"])]
)
.bindTo(tableView.rx.items(dataSource: dataSource))
.addDisposableTo(disposeBag)
```

并且需要预先完成的数据源的最小配置如下所示：

```swift
dataSource.configureCell = { dataSource, tableView, indexPath, item in
  let cell = tableView.dequeueReusableCell(
  	withIdentifier: "Cell", for: indexPath)
  cell.placeLabel.text = item
  return cell
}
dataSource.titleForHeaderInSection = { dataSource, index in
  return dataSource.sectionModels[index].header
}
```

由于绑定table和collection视图是重要的每日任务，您将在本书后面的专用章节cookbook-style中更详细地查看RxDataSources。

#### RxAlamofire 325

RxAlamofire是优雅的Swift HTTP网络库Alamofire的封装。 Alamofire是最受欢迎的第三方框架之一。
RxAlamofire具有以下便利扩展功能：

```swift
func data(_ method:_ url:parameters:encoding:headers:)
  -> Observable<Data>
```

此方法将所有请求详细信息合并到一个调用中，并将服务器响应作为Observable <Data>返回。

而且，这个库还提供了：

```swift
func string(_ method:_ url:parameters:encoding:headers:)
  -> Observable<String>
```

它返回一个String类型的Observable的内容响应

最后，但同样重要：

```swift
func json(_ method:_ url:parameters:encoding:headers:)
  -> Observable<Any>
```

它返回一个对象的实例。 重要的是要知道，此方法不会返回像之前创建的JSON对象

#### RxBluetoothKit 326

使用蓝牙可能很复杂。 一些调用是异步的，调用的顺序对于从设备或外围设备正确连接，发送数据和接收数据至关重要。

RxBluetoothKit抽象了一些使用蓝牙的最痛苦的部分，并提供了一些很酷的功能：

- CBCentralManger 支持
- CBPeripheral 支持
- 扫描共享和排队

开始使用RxBluetoothKit，你必须创建一个manager：

```swift
let manager = BluetoothManager(queue: .main)
```

扫描外设的代码看起来像：

```swift
manager.scanForPeripherals(withServices: [serviceIds])
  .flatMap { scannedPeripheral in
  let advertisement = scannedPeripheral.advertisement
}
```

并连接到一个：

```swift
manager.scanForPeripherals(withServices: [serviceId])
  .take(1)
  .flatMap { $0.peripheral.connect() }
  .subscribe(onNext: { peripheral in
  print("Connected to: \(peripheral)")
  })
```

也可以观察当前manager的现状：

```swift
manager.rx_state
  .filter { $0 == .poweredOn }
  .timeout(1.0, scheduler)
  .take(1)
  .flatMap { manager.scanForPeripherals(withServices: [serviceId]) }
```

除了manager外，还有特色和外设的超级方便抽象。 例如，要连接外设，您可以执行以下操作：

```swift
peripheral.connect()
  .flatMap { $0.discoverServices([serviceId]) }
  .subscribe(onNext: { service in
  print("Service discovered: \(service)")
  })
```

如果你想发现一个特征:

```swift
peripheral.connect()
  .flatMap { $0.discoverServices([serviceId]) }
  .flatMap { $0.discoverCharacteristics([characteristicId])}
  .subscribe(onNext: { characteristic in
  print("Characteristic discovered: \(characteristic)")
  })
```

RxBluetoothKit还具有正确执行连接恢复功能，监控蓝牙状态和监视单个外设连接状态的功能。

### 何去何从? 327

在本章中，您将了解如何实现和封装Apple框架。 有时，抽象官方Apple 框架或第三方库是非常有用的，它可以更好地与RxSwift连接。当抽象是必要的时候，没有真正的书面规则，但是如果框架满足以下一个或多个条件，建议应用这一策略：

 - 使用回调与完成和失败信息
 - 使用很多代表异步返回信息
 - 框架需要与应用程序的其他RxSwift部分进行互操作

您还需要知道框架是否对数据必须处理哪个线程有限制。 因此，在创建RxSwift包装之前，先阅读文档是一个好主意。 不要忘了寻找现有的社区扩展 - 或者，如果你已经写了一个，那么考虑与社区共享它！：]