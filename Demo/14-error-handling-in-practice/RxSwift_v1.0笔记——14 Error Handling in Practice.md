## RxSwift_v1.0笔记——14 Error Handling in Practice

错误在所难免，我们需要知道如何优雅和高效的处理错误。这章，你讲学习如何处理错误，如何通过重审来管理错误恢复（how to manage error recovery through retries）。or just surrender yourself to the universe and let the errors go。

### 开始 269

这个应用是第12章的延续。在这个版本的应用中，不但你能够检索用户当前的位置并查询这个位置的天气，而且也请求城市名并查看那个位置的天气。这个应用app也有activity indicator用来做视觉反馈。

像之前一样在ApiController.swift,中替换你的key，pod install

```swift
let apiKey = BehaviorSubject(value: "[YOUR KEY]")
```

运行程序确保当你所说城市时能够检索天气。

### 管理错误 269

任何应用都无法避免错误。不幸的是，没有人能保证应用绝不会出错，因此你需要某种类型d的错误处理机制。

应用中大部分普遍的错误有：

- **没有网络连接**：这十分普遍。如果应用需要网络连接检索和处理数据，要是设备掉线了，你需要能够适当的检测并做出响应。
- **无效输入**：有时你需要一个确定格式的输入，但是用户输入的可能完全不同。在你的应用中可能有一个电话号码字段（field），但是用户不理睬需求并输入了字母。
- **API错误或HTTP错误**：API的错误可能有很大差异。他们可能是标准的HTTP错误（响应代码从400到500），或作为响应中的错误，例如在JSON响应中使用状态字段。

在RxSwift，错误处理是框架的一部分并能够以两种方式处理：

- **Catch**：使用默认值从错误中恢复。

  ![](http://upload-images.jianshu.io/upload_images/2224431-2523e3c543261f9d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

- **Retry**：重试有限（或无限）次.

  ![](http://upload-images.jianshu.io/upload_images/2224431-1b4106133420725b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

本章的开始项目没有任何真正的错误处理。所有的错误用 catchErrorJustReturn捕获返回一个虚拟的版本。这听起来像是一个处理方案，但在RxSwift中有更好的处理方式，并且可以在任何一流的应用程序中保持一致和有益的错误处理方式。

#### 抛出错误 270

一个好的开始是处理RxCocoa错误，它封装了由苹果底层框架返回的系统错误。RxCocoa错误提供了你遇到的更详细类型的错误，并且也让你的错误代码更容易写。

来看看RxCocoa封装在底层（under the hood）是如果工作的，在Pods/RxCocoa/URLSession+Rx.swift.搜索下面方法：

```Swift
public func data(request: URLRequest) -> Observable<Data> {...}
```

这个方法给定NSURLRequest，返回了一个Data类型的observable。

重要的部分是返回错误的代码：

```swift
if 200 ..< 300 ~= response.statusCode {
    return data
}
else {
    throw RxCocoaURLError.httpRequestFailed(response: response, data: data)
}
```

这是一个用来说明observable如何能够发射一个错误的完美例子——具体来说，是一个定制（custom-tailored）错误，后续章节将会说明。

注意在这个闭包中没有为错误写返回。当你想在flatMap操作中输出错误，你应该像常规的Swift代码一样使用throw。这是一个很好的例子，用来说明RxSwift如何让您在必要时编写符合习惯的Swift代码，并在适当的时候使用RxSwift类型的错误处理。

### 用catch处理错误 271

解释了如何抛出错误，是时候看看怎样处理错误了。大部分基本的方式是使用catch。catch操作与普通Swift中的do-try-catch流程非常相似。执行一个observable，如果有错误产生，返回一个封装了错误的事件。

在RxSwift，有两个主要的捕获错误的操作。第一个：

```swift
func catchError(_ handler:) -> RxSwift.Observable<Self.E>
```

这是常规的操作；它接受一个闭包作为参数，并给出机会返回一个完全不同的observable。如果你还不清楚在哪里选择使用这个，考虑一个捕获策略，如果observable输出错误就返回一个先前的缓存值。你能够用这个机制来实现以下流程：

![](http://upload-images.jianshu.io/upload_images/2224431-0c21f1a6e7102873.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

 在这种情况下，catchError返回先前可用的值，而且由于某种原因，该值不再可用。

第二个是：

```swift
func catchErrorJustReturn(_ element:) -> RxSwift.Observable<Self.E>
```

在前两章你已经使用过它——它忽略错误并仅仅返回一个预先定义的值。这个操作比上一个受到更多限制，它不可能返回给定类型错误的值——不管错误是什么，对于任何错误它都返回同样的值。

#### 一个常见的陷阱 271

错误通过observable链传播，因此如果在事发现场没有进行任何处理，在observable链开始发生的错误将被转发到（be forwarded to）最终的订阅者。

这是什么意思呢？当一个observable错误发出时，错误的订阅者被通知，然后所有的订阅者被销毁。因此当一个observable错误发出时，这个observable必须终止，且跟随错误之后的任何事件将被忽略。这是observable 约定的规则。

你能够看到它被绘制到下面的时间线上。一旦网络产生一个错误，observable序列错误输出，订阅更新UI的工作将停止，实际上阻止了将来的更新：

![](http://upload-images.jianshu.io/upload_images/2224431-6464d1a6ef2a7ef2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)


为了将这个转换到实际的应用中，移除在textSearch observable中的.catchErrorJustReturn(ApiController.Weather.empty)行，启动应用，在城市搜索字段随机输入字符直到API 回应了404错误。在你的控制台中你应该看到以下相似的信息：

```
"http://api.openweathermap.org/data/2.5/weather?
q=goierjgioerjgioej&appid=[API-KEY]&units=metric" -i -v
Failure (207ms): Status 404
```

当响应后（这意味着它是一个无效的城市名），这个应用停止了工作，并且搜索在那之后不再工作。不完美的用户体验，不是吗？

### 捕获错误 272

现在你已经了解了一些原理，你可以继续更新当前项目。一旦你完成了，这个应用将通过返回一个空的Weather类型来从错误中恢复，因此这个应用的流程不会被中断。

这次，工作流包含了错误处理，将看起来像下图这样：

![](http://upload-images.jianshu.io/upload_images/2224431-e48c207658238a8a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

这很好，但如果app可以返回缓存数据，如果有得话，那将更完美。

打开ViewController.swift，创建一个简单的字典来缓存天气数据，增加它作为视图控制器的属性：

```swift
var cache = [String: Weather]()
```

这将临时的存储缓存数据。滚动到 viewDidLoad()内，找到你创建textSearch observable的行。现在通过添加 do(onNext:)更改textSearch observable来填充缓存：

```swift
let textSearch = searchInput.flatMap { text in
  return ApiController.shared.currentWeather(city: text ?? "Error")
    .do(onNext: { data in
      if let text = text {
        self.cache[text] = data
      }
    })
    .catchErrorJustReturn(ApiController.Weather.empty)
}
```

这样每个有效的天气响应将被存储在字典例。现在——怎么重用缓存结果呢？

在错误事件返回一个缓存值，替换 .catchErrorJustReturn(ApiController.Weather.empty)用：

```swift
.catchError { error in
  if let text = text, let cachedData = self.cache[text] {
    return Observable.just(cachedData)
  } else {
    return Observable.just(ApiController.Weather.empty)
  }
}
```

为了测试这个，输入3~4个城市，例如“London”, “New York”, “Amsterdam”并加载这些城市的天气。接着，断开网络搜索一个不同的城市，例如“Barcelona”；你应该接受到一个错误。保持断网并搜索一个你已经检索数据的城市，这个应用将返回缓存的版本。

这是catch的普通用法。你一定可以扩展它，使其成为一个通用和强大的缓存解决方案。

### Retry错误 274

在RxSwift捕获错误仅仅是错误处理的一种方式。你也能用retry处理错误。

当使用retry操作并且一个observable错误输出时，observable将重复它自己。重要的是要记住，retry意味着重复在observable内的整个任务

![](http://upload-images.jianshu.io/upload_images/2224431-48f0d62d02faceb4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/310)

这是建议避免在observable内部更改用户界面以免产生副作用（side effect）的主要原因之一，因为您无法控制谁将重试它！

#### Retry操作 274

retry操作有三种类型。第一个是最基础的：

```swift
func retry() -> RxSwift.Observable<Self.E>
```

这将无限次的重复observable直到他返回成功。例如，如果没有网络连接，他讲持续retry直到连接有效。这听起来像是一个粗鲁的主意，但它很耗资源，如无必要，很少会推荐retry无限次。

为了测试这个操作，注释掉complete  catchError块：

```swift
//.catchError { error in
// 	if let text = text, let cachedData = self.cache[text] {
// 		return Observable.just(cachedData)
// 	} else {
// 		return Observable.just(ApiController.Weather.empty)
// 	}
//}
```

在这个位置简单的插入retry()。运行你的app，取消网络连接并试着搜索。你将看很多的输出在控制台，它代表了应用正试着做出请求。过一会重新连接网络，一旦应用成功完成请求，你将看到显示结果。

第二个操作让你改变重复的次数

```swift
func retry(_ maxAttemptCount:) -> Observable<E>
```

这个observable会重复指定的次数。尝试一下内容：

- 移除刚增加的retry()
- 取消先前注释的代码块
- 在 catchError前插入 retry(3)

完成后的代码块显示如下：

```swift
return ApiController.shared.currentWeather(city: text ?? "Error")
  .do(onNext: { data in
    if let text = text {
      self.cache[text] = data
    }
  })
  .retry(3)
  .catchError { error in
    if let text = text, let cachedData = self.cache[text] {
      return Observable.just(cachedData)
    } else {
      return Observable.just(ApiController.Weather.empty)
    }
  }
```

如果observable产生错误，它将连续重复三次，在第四次时，错误将不被处理并将执行 catchError操作。

#### 高级retries 276

最后一个操作， retryWhen，适用于高级retry的情况。这个错误处理算子被认为是最强大的一个：

```swift
func retryWhen(_ notificationHandler:) -> Observable<E>
```

 notificationHandler是 TriggerObservable.类型。触发observable既是普通的observable或subject又被用来触发retry任意次数。

在你的应用中你将做以下操作，如果互联网连接不可用，或者API发生错误，请使用智能手法重试。

如果搜索出错，这个目标是执行一个递增的回退（back-off）策略。设计结果如下：

```
subscription -> error
delay and retry after 1 second
subscription -> error
delay and retry after 3 seconds
subscription -> error
delay and retry after 5 seconds
subscription -> error
delay and retry after 10 seconds
```

他是一个聪明而复杂的解决方案。在正常的命令式代码中，这意味着创建一些抽象，可能将任务封装在NSOperation中，或者围绕Grand Central Dispatch创建一个定制的封装 - 但是使用RxSwift，解决方案是一小段代码。

创建最终结果之前，考虑到（taking in consideration）该类型可以被忽略，并且触发可以是任意类型，思考下observable（触发）内部应该返回什么。

目标是用一个给定的延时序列retry四次。首先在 ViewController.swift内， 订阅ApiController.shared.currentWeather序列之前，在 retryWhen操作前定义最大尝试数，它将用于序列内部：

```swift
let maxAttempts = 4
```

重试这多次后，应该转发（forward on）错误。接着替换 .retry(3)：

```swift
.retryWhen { e in
  // flatMap source errors
}
```

这个observable必须与源observable返回错误的那个组合。因此当一个错误作为事件到达，这些observable的组合也将接收事件当前的索引。

你能够和你的朋友， flatMapWithIndex操作，来实现这个。替换注释“ // flatMap source errors”：

```swift
e.flatMapWithIndex { (error, attempt) -> Observable<Int> in
  // attempt few times
}
```

现在原始error observable与定义的重试之前多长延时被结合。

用一个定时器与那段代码组合，产生第一个延时时间。按如下调整代码：

```swift
e.flatMapWithIndex { (error, attempt) -> Observable<Int> in
  if attempt >= maxAttempts - 1 {
    return Observable.error(error)
  }
  return Observable<Int>.timer(Double(attempt + 1), scheduler:
    MainScheduler.instance).take(1)
}
```

包含retryWhen的完整代码块如下：

```swift
.retryWhen { e in
  return e.flatMapWithIndex { (error, attempt) -> Observable<Int> in
    if attempt >= maxAttempts - 1 {
      return Observable.error(error)
    }
    return Observable<Int>.timer(Double(attempt + 1), scheduler:
      MainScheduler.instance).take(1)
  }
}
```

当新的retry触发时，在 flatMapWithIndex的第二个return前增加如下代码输出日志

```swift
print("== retrying after \(attempt + 1) seconds ==")
```

现在运行程序，取消网络连接并执行搜索。你应该看到下面日志：

```swift
== retrying after 1 seconds ==
... network ...
== retrying after 2 seconds ==
... network ...
== retrying after 3 seconds ==
... network ...
```

下图显示了处理的过程：

![](http://upload-images.jianshu.io/upload_images/2224431-21b4fe22476e2503.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/500)

触发器可以接受源错误observable完成十分复杂的回退（back-off）策略。这展示了你怎样仅用数行RxSwift代码来创建复杂的错误处理策略。

### 自定义错误 278

创建自定义错误遵循了一般Swift原则，因此，没有什么时好的Swift开发者不知道的，但是看看如何处理错误和创建自定义操作任然是有益的。

#### 创建自定义错误 278

来至RxCocoa返回的错误十分通用，因此HTTP 404错误（页面没发现）几乎被视为502（无效网关）。这是两个完全不同的错误，所以能够以不同的方式处理它们是最好的。

如果你深入ApiController.swift，你将看到已经包含了有两个错误情况，你能够用来处理不同HTTP响应的错误：

```swift
enum ApiError: Error {
  case cityNotFound
  case serverFailure
}
```

你将在buildRequest(...)中使用这个错误类型。那个方法的最后一行返回一个数据的observable，然后隐射到JSON结构的对象。这是你必须注入检查并返回你创建的自定义错误的地方。RxCocoa的.data方便已经处理了创建自定义错误对象。

替换在 buildRequest(…)中最后flatMap快内的代码：

```swift
return session.rx.response(request: request).map() { response, data in
  if 200 ..< 300 ~= response.statusCode {
    return JSON(data: data)
  } else if 400 ..< 500 ~= response.statusCode {
    throw ApiError.cityNotFound
  } else {
    throw ApiError.serverFailure
  }
}
```

使用这个方法，你能创建自定义错误和更多高级逻辑的事件，例如当API提供了一个在JSON内部的响应信息，你能够得到JSON数据，处理message字段并将其封装到错误中抛出。在Swift中Errors是十分强大的，而在RxSwift中更强大。

#### 使用自定义错误 279

现在返回你的自定义error，你可以做些建设性的事情。

返回ViewController.swift，注释掉retryWhen {…}操作。你希望error通过链并由observable串起来。

有一个便利的叫做InfoView的视图，它在app底部闪现一个小的视图用来给出错误信息。使用很简单，只用一行代码（现在不需要输入这行）：

```swift
InfoView.showIn(viewController: self, message: "An error occurred")
```

Errors 通常用retry或捕获操作处理，但是如果你想要实现副作用并在用户界面显示消息呢？为了实现这个，用do操作。在同样的订阅中，你注释retryWhen的地方，你已经使用了一个do来执行捕获：

```swift
.do(onNext: { data in
  if let text = text {
    self.cache[text] = data
  }
```

将另一个参数（onError）添加到.do中，以便在发生错误事件时执行副作用。完整的块如下：

```swift
.do(onNext: { data in
  if let text = text {
    self.cache[text] = data
  }
}, onError: { [weak self] e in
  guard let strongSelf = self else { return }
  DispatchQueue.main.async {
    InfoView.showIn(viewController: strongSelf, message:
      "An error occurred")
  }
})
```

调度是必须的，因为这个序列在后台线程被观察；如果不这样，UIKit将给出UI通过后台线程被修改的警告。运行app，试着搜索一个随机的字符串，错误将会出现（show up）。




![](http://upload-images.jianshu.io/upload_images/2224431-9dbde86f6e01f8ed.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/320)

很好，错误是相当的普通。但是你能够很容易的在那里注入一些信息。RxSwift处理这个就像Swift，因此你能检查错误情况并显示不同信息。让代码更加清晰，增加下面新方法到视图控制器类：

```swift
func showError(error e: Error) {
  if let e = e as? ApiController.ApiError {
    switch (e) {
    case .cityNotFound:
      InfoView.showIn(viewController: self, message: "City Name is invalid")
    case .serverFailure:
      InfoView.showIn(viewController: self, message: "Server error")
    }
  } else {
    InfoView.showIn(viewController: self, message: "An error occurred")
  }
}
```

然后返回到 do(onNext:onError:)，替换 InfoView.showIn(...)这行，用：

```swift
strongSelf.showError(error: e)
```

这将提供更多的错误的上下文给用户。

### 高级错误处理 281

高级错误的情况可能难以实现。 当API返回错误时，除了向用户显示消息外，还没有一般的规则。假设你想增加认证到当前app。用户必须经过身份验证并被授权才能请求天气状况。这意味着一个会话的创建将确保用户登录并正确的授权。但是假如会话失效该做什么呢？返回一个错误或返回一个空值与一个消息字符串？

在这种情况下没有新技术（silver bullet）。这两种解决方案都适用于此，但是了解有关错误的更多信息总是有用的，因此您将会走上这条路线。

在这种情况下，推荐的方式是执行一个副作用并在会话正确创建之后立即重试。

你能够使用名为apiKey的subject并包含你的API key来模拟这个行为。

这个API key subject 能够在retryWhen closure内部被用来触发重试。缺少API key是一个明确的错误，因此在ApiError enum中增加下面的额外的错误情况：

```swift
case invalidKey
```

当服务器返回401编码时，这个错误必须被抛出。在 builderRequest(...) function函数中抛出该错误，紧跟在第一个if if 200 ..< 300：

```swift
else if response.statusCode == 401 {
  throw ApiError.invalidKey
}
```

新的错误请求也有一个新的处理。回到ViewController.swift，升级在 showError(error:)方法中的switch包含新的case：

```swift
case .invalidKey:
  InfoView.showIn(viewController: self, message: "Key is invalid")
```

现在你能够返回 viewDidLoad()并重新实现错误处理代码。由于您已经注释掉当前的 retryWhen {...}代码，您可以重新构建您的错误处理。

上面的订阅 searchInput创建了一个专门的闭包，在观察者链外部，它将作为错误处理服务：

```swift
let retryHandler: (Observable<Error>) -> Observable<Int> = { e in
  return e.flatMapWithIndex { (error, attempt) -> Observable<Int> in
    //error handling
  }
}
```

你将复制你之前使用过的代码到新的错误处理闭包中。替换//error处理注释用：

```swift
if attempt >= maxAttempts - 1 {
  return Observable.error(error)
} else if let casted = error as? ApiController.ApiError, casted == .invalidKey {
  return ApiController.shared.apiKey
    .filter {$0 != ""}
    .map { _ in return 1 }
}
print("== retrying after \(attempt + 1) seconds ==")
return Observable<Int>.timer(Double(attempt + 1), scheduler: MainScheduler.instance)
  .take(1)
```

在 invalidKey case里返回类型不重要，但是你必须保持一致。之前，它是 Observable<Int>，因此你应该坚持返回那个类型。为此，你应该使用 { _ in return 1 }。

现在，滚动到被注释的 retryWhen {…}并替换它用：

```swift
.retryWhen(retryHandler)
```

最后一步是使用API key的subject。 ViewController.swift中已经有一个名为requestKey（）的方法，它打开一个带有文本框的alert视图。 然后，用户可以键入密钥（或将其粘贴到其中）来模拟登录功能。（您可以在此进行测试;在现实生活的应用程序中，用户将输入凭据，从服务器获取密钥。）

切换到ApiController.swift。删除apiKey主题中的API key并将其设置为一个空字符串（您可能希望将密钥复制到某个地方，方便您再次使用它），如下所示：

```swift
let apiKey = BehaviorSubject(value: "")
```

运行程序，试着执行搜索，你将接收到一个错误：

![](http://upload-images.jianshu.io/upload_images/2224431-cb83368e70527a11.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/400)

点击在右下角的key按钮：

![](http://upload-images.jianshu.io/upload_images/2224431-2fd4ce76da6ece41.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/310)

应用将打开一个alert请求输入API key：

![](http://upload-images.jianshu.io/upload_images/2224431-0715b7b5c7e6144a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/300)

粘贴API key到文本框点击OK。app将重复整个observable序列，如果输入有效，将返回正确的信息。如果输入无效，将在不同的错误路径上结束（end up）。

