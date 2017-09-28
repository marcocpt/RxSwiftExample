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

When you modularize an extension like you just did, you allow for better composability. For example the last observable can be visualized in the following way:

![](http://upload-images.jianshu.io/upload_images/2224431-913ac4250560b299.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### How to create custom operators 319

In the chapter about RxCocoa you created a function to cache data.

The caching strategy will be a simple Dictionary;

**Create the cache dictionary** at the top, **before the RxURLSessionError’s definition**:

```swift
fileprivate var internalCache = [String: Data]()
```

Then create the extension which will target only observables of Data type:

```swift
extension ObservableType where E == (HTTPURLResponse, Data) {
}
```

Inside this extension you can create the cache() function as shown:

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

To use the cache, make sure to **modify the data(request:)'s return** statement to **cache** the response before returning its own result like so (you can simply **insert only the .cache() part**):

```swift
return response(request: request).cache().map { (response, data) -> Data
in
//...
}
```

To check if the data is already available, **instead of firing a network request every time**, add the following to the **top of data(request:), before the return**:

```swift
if let url = request.url?.absoluteString, let data = internalCache[url] {
  return Observable.just(data)
}
```

You now have a very basic caching system that **extends only a certain type of Observable**:

![](http://upload-images.jianshu.io/upload_images/2224431-92a8a90e0be2853f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

You can reuse the same procedure to cache other kinds of data, considering this is an extremely generic solution.

### Use custom wrappers 320

Now it’s time to fetch some results and display some funny cat GIFs.

Open **ApiController.swift** and have a look at the **search()** method.just returns an empty observable instead (since this is placeholder code).

Modify the return statement like so:

```swift
return URLSession.shared.rx.json(request: request).map() { json in
  return json["data"].array ?? []
}
```

but the data is still not displayed. There’s one last step to be performed before the GIF actually pos up on screen.

Add the following to **GifTableViewCell.swift,** right at the end of downloadAndDisplay(gif stringUrl:):

```swift
let s = URLSession.shared.rx.data(request: request)
  .observeOn(MainScheduler.instance)
  .subscribe(onNext: { imageData in
    self.gifImageView.animate(withGIFData: imageData)
    self.activityIndicator.stopAnimating()
  })
disposable.setDisposable(s)
```

in prepareForReuse() there are these two lines

```swift
disposable.dispose()
disposable = SingleAssignmentDisposable()
```

The SingleAssignmentDisposable() will ensure **only one subscription is ever alive** at a given time for every single cell so you won’t bleed resources.

Build and run, type something in the search bar and you’ll see the app come alive.

![](http://upload-images.jianshu.io/upload_images/2224431-4fda76821c3195e3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/300)

### Testing custom wrappers 321

Test suites ensure the wrapper around a framework stays in good shape, and will help you find where the code is failing due to a breaking change or a bug.

#### How to write tests for custom wrappers 322

in this chapter you’ll use a common library used to write tests on Swift called Nimble, along with its wrapper RxNimble.

RxNimble makes tests easier to write and helps your code be more concise. Instead of writing the classic:

```swift
let result = try! observabe.toBlocking().first()
expect(result) != 0
```

You can write the much shorter:

```swift
expect(observable) != 0
```

Open the test file **iGifTests.swift.** Checking the import section, you can see the **Nimble, RxNimble, OHHTTPStubs used to stub network requests** and **RxBlocking necessary to convert an asynchronous operation into a blocking ones.**

**At the end of the file** you can also find a short **extension for BlockingObservable** with a single function:

```swift
func firstOrNil() -> E? {}
```

This would **avoid abusing the try? method** all through the test file. You’ll see this in use shortly.

At the top of the file, you’ll find a dummy JSON object to test with:

```swift
let obj = ["array": ["foo", "bar"], "foo": "bar"] as [String: Any]
```

**Using this predefined data** makes it easier to write tests for Data, String and JSON requests.

**The first test** to write is the one for the **data request**. **Add** the following test to the test case class to **check that a request is not returning nil:**

```swift
func testData() {
  let observable = URLSession.shared.rx.data(request: self.request)
  //原报错：use beNil() to match nils
  //expect(observable.toBlocking().firstOrNil()) != nil
  expect(observable.toBlocking().firstOrNil()).notTo(beNil())
}
```

Click on the button and run the test.

the next one to test is the observable that **handles String**. Considering the original data is a JSON representation, and considering that keys are sorted, the expected result should be:

```swift
{"array":["foo","bar"],"foo":"bar"}
```

Add the following, taking in（以） consideration that the JSON string has to be escaped:

```swift
func testString() {
  let observable = URLSession.shared.rx.string(request: self.request)
  let string = "{\"array\":[\"foo\",\"bar\"],\"foo\":\"bar\"}"
  expect(observable.toBlocking().firstOrNil()) == string
}
```

move on to testing JSON parsing.The test requires a JSON data structure to compare with.Add the following code to convert the string version to Data and process it as JSON:

```swift
func testJSON() {
  let observable = URLSession.shared.rx.json(request: self.request)
  let string = "{\"array\":[\"foo\",\"bar\"],\"foo\":\"bar\"}"
  let json = JSON(data: string.data(using: .utf8)!)
  expect(observable.toBlocking().firstOrNil()) == json
}
```

The last test is to make sure that **errors are returned properly**. **Comparing two errors is a rather uncommon procedure**, so it doesn’t make sense to have an equal operator for an error. Therefore the **test should use do, try and catch** for the unknown error.

Add the following:

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

You’ve created your own extensions on top of URLSession and you also created some cool tests which will ensure your wrapper is behaving correctly. 

### Common available wrappers 324

You can find a list of up-to-date wrappers at http://community.rxswift.org.

Here’s a quick overview of the most common wrappers at present:

#### RxDataSources 324

 RxDataSources is a  **UITableView and  UICollectionView data source** for RxSwift with some really nice features such as:

- O(N) algorithm for calculating differences
- Heuristics to send the minimal number of commands to sectioned view
- Support for extending already implemented views
- Support for hierarchical animations

my favorite is the **O(N) algorithm** to differentiate two data sources – it **ensures** the application **isn’t performing unnecessary calculations** when managing table views.

Consider the code you write with the built-in RxCocoa table binding:

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

This works perfectly with **simple data sets, but lacks animations, support for multiple sections, and doesn’t extend very well.**

**With RxDataSource** correctly configured, the code becomes **more robust**:

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

And the **minimal configuration of the data source** that needs to be done in advance looks like so:

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

Since **binding table and collection views** is an important every day task, you'll look into RxDataSources in **more detail in a dedicated cookbook-style chapter later in this book**.

#### RxAlamofire 325

RxAlamofire is a wrapper around the elegant Swift **HTTP networking library** Alamofire.

 RxAlamofire features the following **convenience extensions**:

```swift
func data(_ method:_ url:parameters:encoding:headers:)
  -> Observable<Data>
```

This method **combines all the request** details into one call and **returns** the server response as **Observable<Data>**.

Further, the library offers:

```swift
func string(_ method:_ url:parameters:encoding:headers:)
  -> Observable<String>
```

This one **returns** an **Observable** of the content response as **String**.

Last, but no less important:

```swift
func json(_ method:_ url:parameters:encoding:headers:)
  -> Observable<Any>
```

It’s important to know that this method **doesn’t return a JSON object** like the one you created before.

#### RxBluetoothKit 326

RxBluetoothKit abstracts some of the most painful parts of working with Bluetooth and delivers some cool features:

- CBCentralManger support
- CBPeripheral support
- Scan sharing and queueing

To start using RxBluetoothKit, you have to create a manager:

```swift
let manager = BluetoothManager(queue: .main)
```

The code to scan for peripherals looks something along the lines of:

```swift
manager.scanForPeripherals(withServices: [serviceIds])
  .flatMap { scannedPeripheral in
  let advertisement = scannedPeripheral.advertisement
}
```

And to connect to one:

```swift
manager.scanForPeripherals(withServices: [serviceId])
  .take(1)
  .flatMap { $0.peripheral.connect() }
  .subscribe(onNext: { peripheral in
  print("Connected to: \(peripheral)")
  })
```

It’s also possible to observe the current state of the manager:

```swift
manager.rx_state
  .filter { $0 == .poweredOn }
  .timeout(1.0, scheduler)
  .take(1)
  .flatMap { manager.scanForPeripherals(withServices: [serviceId]) }
```

In addition to the manager, there are also super-convenient abstractions for characteristics and peripherals. For example, to connect to a peripheral you can do the following:

```swift
peripheral.connect()
  .flatMap { $0.discoverServices([serviceId]) }
  .subscribe(onNext: { service in
  print("Service discovered: \(service)")
  })
```

And if you want to discover a characteristic:

```swift
peripheral.connect()
  .flatMap { $0.discoverServices([serviceId]) }
  .flatMap { $0.discoverCharacteristics([characteristicId])}
  .subscribe(onNext: { characteristic in
  print("Characteristic discovered: \(characteristic)")
  })
```

RxBluetoothKit also features functions to properly perform connection restorations, to monitor the state of Bluetooth and to monitor the connection state of single peripheral.

### Where to go from here? 327

There’s no real written rule about when an abstraction is necessary, but the recommendation is to apply this strategy if the framework meets one or more of these conditions:

- Uses callbacks with completion and failure information
- Uses a lot of delegates to return information asynchronously
- The framework needs to inter-operate with other RxSwift parts of the application