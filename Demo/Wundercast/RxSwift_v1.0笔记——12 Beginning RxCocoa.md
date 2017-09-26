本章将向你介绍另一个框架，它是原生RxSwift库的一部分：RxCocoa。

RxCocoa全平台通用。每个平台有一套自定义的封装，它提供了一套内建的扩展，给许多UI控件和其他SDK类。在本章中，您将在iPhone和iPad上使用为iOS提供的功能。

     Note: 当前，RxCocoa几乎完成了对iOS的支持，接下来是Apple Watch和macOS。macOS仍然缺少一些高级的封装实现，但它包括创建跨平台解决方案的所有基础来共享逻辑。后续章节你将看到它如何使用。

### 开始 229 

这个项目叫Wunderast，一个天气app，由OpenWeatherMap http://openweathermap.org 提供数据。项目使用CocoaPods集成了RxSwift，RxCocoa和SwiftyJSON（处理OpenWeatherMap API返回的JSON数据）框架。

RxCocoa与RxSwift一起被释放。两个框架共享相同的释放进度，通常最新RxSwift包含同样版本的RxCocoa。

在这个项目中，你将使用为 UITextField和 UILabel的Rx封装，建议先浏览这两个文件以便理解他们是如何工作的。

打开 **UITextField+Rx.swift**（RxCocoa中），这个文件很短——小于50行代码，唯一的属性是 ControlProperty<String?>类型的text。

ControlProperty<String?>是Subject专用的类型，它能被订阅也能注入新的值。text属性直接关联到 UITextField的text属性。

打开**UILabel+Rx.swift**，里面有两个属性： text 和 attributedText。它们同样关联到原始的 UILabel的属性。它们都使用了 一个新的类型UIBindingObserver。

这个observer与ControlProperty相似，它专用与同UI一起工作。 UIBindingObserver用下面的逻辑来绑定UI，它不能绑定错误。如果有错误发送给了 UIBindingObserver，在Debug模式它将调用 fatalError()，在release模式将被增加到错误日志中。

#### 配置API key 230 

打开 https://home.openweathermap.org/users/sign_up ，注册并在 https://home.openweathermap.org/api_keys 页面生成一个新的key。

复制API key 粘贴到ApiController.swift文件的下面位置：

```
private let apiKey = "[YOUR KEY]"
```

### 使用RxCocoa与基本的UIKit控件 230 

你现在准备输入一些数据并调用API来返回给定城市的天气，包括温度，湿度和城市名。

#### 使用RxCocoa显示数据 230 

如果你已经运行了这个项目，您可能会问为什么应用程序在从API中实际检索任何内容之前显示数据。这是为了让你能够确认手动注入的数据是正确的，如果有错误你就知道它是在API的处理代码中，而不会在你的Rx逻辑和UI相关代码中。

在ApiController.swift中，你将看到一个结构体，它使用Swift更易于设计，作为一个适当映射到JSON的数据结构被使用。

```swift
struct Weather {
  let cityName: String
  let temperature: Int
  let humidity: Int
  let icon: String
  ...
}
```

在ApiController.swift中查看一下函数：

```swift
func currentWeather(city: String) -> Observable<Weather> {
  // Placeholder call
  return Observable.just(
    Weather(
      cityName: city,
      temperature: 20,
      humidity: 90,
      icon: iconNameToChar(icon: "01d"))
  )
}
```

这个函数返回了一个伪造的城市名RxCity并显示了一些虚拟的数据，你使用它替代真实的数据，直到你检索了来之服务器的天气信息。

虚拟的数据可以帮助简化开发过程并给你机会用一个实际的数据结构来工作，甚至不需要网络联接。

打开 **ViewController.swift**，它是这个项目中唯一的视图控制器。这个项目的主要目标是连接这个唯一的视图控制器到 提供数据的ApiController。

结果是单向数据流：

![](http://upload-images.jianshu.io/upload_images/2224431-c8f3f4c52883e09d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/400)

如前几章所述，RxSwift（更准确地说，observables）能够接收数据并让所有订阅者知道数据已经到达，并推送要处理的值。因此，在视图控制器工作时，订阅observable的正确位置是在 viewDidLoad内。这是因为你需要尽可能早的订阅，但仅仅在加载视图后。订阅晚了可能导致丢失事件，或是部分UI在你绑定数据前消失了。

要检索数据，请在 viewDidLoad:末尾增加下面代码

```swift
ApiController.shared.currentWeather(city: "RxSwift")
  .observeOn(MainScheduler.instance)
  .subscribe(onNext: { data in
    self.tempLabel.text = "\(data.temperature)° C"
    self.iconLabel.text = data.icon
    self.humidityLabel.text = "\(data.humidity)%"
    self.cityNameLabel.text = data.cityName
  })
```

构建并运行APP，将看到如下：

![](http://upload-images.jianshu.io/upload_images/2224431-2cbfcf59904b8714.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/200)

现在还有两个问题：

1. 有一个编译器警告
2. 你没有使用文本框输入

第一个问题显示如下：

![](http://upload-images.jianshu.io/upload_images/2224431-815920eb9813c8eb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

当视图控制器消失时订阅必须被取消。增加下面属性到视图控制器类：

```swift
let bag = DisposeBag()
```

增加 .addDisposableTo(bag)

```swift
ApiController.shared.currentWeather(city: "RxSwift")
  .observeOn(MainScheduler.instance)
  .subscribe(onNext: { data in
    self.tempLabel.text = "\(data.temperature)° C"
    self.iconLabel.text = data.icon
    self.humidityLabel.text = "\(data.humidity)%"
    self.cityNameLabel.text = data.cityName
  })
  .addDisposableTo(bag)
```

无论何时，视图控制器被施放，它将取消并销毁订阅

现在需要来处理文本框。RxCocoa在Cocoa之上增加了许多，因此你能够开始使用这个功能完成你的宏伟目标。这个框架使用了强大的协议扩展（protocol extensions）并给许多UIKit组件增加了rx命名空间。也就是说你能够输入 searchCityName.rx.查看到可用的属性和方法：

![](http://upload-images.jianshu.io/upload_images/2224431-e2b02e35a0a06156.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/500)

有一个你之前已经探究过的：**text**。这个函数返回一个**observable**，它是一个 **ControlProperty<String?>**类型，它遵循了 **ObservableType** 和**ObserverType**，因此你能够订阅它，也能够发射新的值。

了解了 ControlProperty的基本背景知识后，你能够改进代码，利用文本框的优势在虚拟数据中来显示城市名。增加到 viewDidLoad():

```swift
searchCityName.rx.text
  .filter { ($0 ?? "").characters.count > 0 }
  .flatMap { text in
    return ApiController.shared.currentWeather(city: text ?? "Error")
      .catchErrorJustReturn(ApiController.Weather.empty)
  }
```

上面的代码将返回一个新的observable与要显示的数据。 currentWeather不接收nil或者empty值，所以你需要将他们滤掉。然后你使用 ApiController类来抓取天气数据。在先前的章节你已经完成了相似的涉及网络的任务，因此你不需要在意这些细节。

继续先前的代码块，切换到正确的线程并显示数据：

```swift
.observeOn(MainScheduler.instance)
.subscribe(onNext: { data in
  self.tempLabel.text = "\(data.temperature)° C"
  self.iconLabel.text = data.icon
  self.humidityLabel.text = "\(data.humidity)%"
  self.cityNameLabel.text = data.cityName
})
.addDisposableTo(bag)
```

你切换到主线程用当前的天气数据来更新UI。下图可视化了这个流程：

![](http://upload-images.jianshu.io/upload_images/2224431-df303ae1592440fc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

无论你什么时候改变输入，label将更新城市名——但是现在它将一直返回你虚拟的数据。应用显示虚拟数据是正确的，是时候获得来至API的真实数据了。

     Note:catchErrorJustReturn会再以后解释。 当你接收了一个来至API的错误时，需要防止observable被销毁。例如，无效的城市名称返回404作为NSURLSession的错误。在这种情况下，您需要返回一个空值，以免应用程序遇到错误时停止工作。
#### 检索来至OpenWeather API的数据 234

API返回结构化的JSON响应，以下是有效的位：

```json
{
  "weather": [
    {
      "id": 741,
      "main": "Fog",
      "description": "fog",
      "icon": "50d"
    }
  ],
}
```

上面的数据被关联到当前的天气；图标元素为当前的条件显示正确的图标。下面这段分配了温度和湿度的数据。

```Json
  "main": {
    "temp": 271.55,
    "pressure": 1043,
    "humidity": 96,
    "temp_min": 268.15,
    "temp_max": 273.15
  }
}
```

上面的温度单位为Kelvin

在**ApiController.swift**，有一个叫 **iconNameToChar**的函数，输入字符串（更准确说是来至JSON的图标数据）并返回另一个字符串，它使用UTF-8编码，在你的应用中形象化的呈现天气图标。还有一个方便的函数 **buildRequest**用来创建网络请求。它使用RxCocoa封装让 NSURLSession执行网络请求。这个函数有以下任务：

- 获得基本的URL并附加组件来正确的构造GET(或POST)请求
- 使用你的API key
- 给 application/json设置请求类型
- 请求度量单位（在这里是degrees Kelvin）
- 返回的数据映射到JSON对象

最后一行**return**语句如下：

```swift
//[...]
return session.rx.data(request: request).map { JSON(data: $0) }
```

它围绕 NSURLSession，使用了RxCocoa的rx扩展的data函数。返回 Observable<Data>。这个数据作为map函数的输入被使用，它用来转换原始数据到JSON类型的SwiftyJSON数据结构。

下图可以帮助你更好的理解 ApiController内部的原理：

![](http://upload-images.jianshu.io/upload_images/2224431-b68afc3dc176144c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

从虚拟数据切换到实际数据请求很简单。你需要用一个真实的网络请求数据替换 Observable.just([…])的调用。OpenWeatherMap的API文档 http://openweathermap.org/current 解释了如何通过api.openweathermap.org/data/2.5/weather?q={city name} 来获得给定城市当前的天气。

在ApiController.swift，用下列实现替换虚拟的 currentWeather(city:)：

```swift
func currentWeather(city: String) -> Observable<Weather> {
  return buildRequest(pathComponent: "weather", params: [("q", city)])
    .map { json in
      return Weather(
        cityName: json["name"].string ?? "Unknown",
        temperature: json["main"]["temp"].int ?? -1000,
        humidity: json["main"]["humidity"].int ?? 0,
        icon: iconNameToChar(icon: json["weather"][0]["icon"].string ??
          "e")
      )
  }
}
```

这个请求返回一个JSON对象，它能够同一些回调值转换到你期望的Weather的数据结构，然后给你的用户界面。
构建并运行，输入London，你将看到下面结果：

![](http://upload-images.jianshu.io/upload_images/2224431-54a0c893cc7a4c5b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/200)

你的应用现在可以显示来自服务器检索的数据了。你已经使用了一些RxCocoa特性，下节你将使用更多RxCocoa的高级特性。

     Note: 如果你想了解更多(going the extra mile)，移除flatmap内部的catchErrorJustReturn。一旦你收到404错误因为一个无效的城市名，(你将在log中看到)，这个应用将停止工作因为你的observable由于错误被销毁了。

### 绑定observables 237

绑定稍微有些争议——例如，苹果绝不会在iOS上释放他们的Cocoa Bindings系统（即使它很长一段时间已经是macOS的重要部分）。mac绑定非常高级并且在macOS SDK中与苹果提供的专用类有些许结合。

RxCocoa中提供了一些简单的解决方案，它只依赖框架中包含的几种类型。既然你已经感觉RxSwift编码很舒适，所以你会非常快速的看出绑定。

在RxCocoa，绑定是单向的数据流。本书中不会覆盖到双向绑定。

#### 什么是绑定observables 237

容易理解绑定的方式是想想两个实体之间的连接关系

![](http://upload-images.jianshu.io/upload_images/2224431-51c038eb4f66cf0f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

- 生产者，生产值
- 接受者，处理来自生产者的值

接受者不能够返回值。这是RxSwift绑定的基本规则。



![](http://upload-images.jianshu.io/upload_images/2224431-3f85cd40b88b7de7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

	Note：如果你想试验双向绑定(例如在数据模型属性和文本框之间)，你应该使用四个实体模组化：两个生产者和两个接受者。你可以想象这会是相当复杂的。

绑定的函数叫 bindTo(_:)。要绑定observable到另一个实体，接收者必须遵循 ObserverType。前面章节已经解释过这个实体：它是一个能够处理值的Subject，也能手动写。Subject同Cocoa的重要特性一起工作是极其重要的，考虑到框架的组件，例如UILabel，UITextField和UIImageView，它们有可变的数据，能够被设置或检索。

 bindTo(_:)也能用作其他目的——不仅仅绑定用户界面到源（underlaying）数据。例如，你应该使用 bindTo(_:)创建依赖进程，以便一个确定的observable将触发一个对象去执行一些后台任务，而在前台不用显示任何东西。

总得来说， bindTo(_:)是一个特殊的经过裁剪的 subscribe(_:)的版本，当调用bindTo(_:)时没有副作用或其他情况。

#### 使用绑定observables显示数据 238

现在你可以集成绑定到你的应用。这将让整个代码更加简洁并且转换搜索结果到可重用的数据源。

第一步重构很长的observable，用 subscribe(onNext:)分配数据到当前的标签。打开ViewController.swift，在viewDidLoad()中，用以下代码替换全部的 searchCityName订阅代码：

```swift
let search = searchCityName.rx.text
  .filter { ($0 ?? "").characters.count > 0 }
  .flatMapLatest { text in
    return ApiController.shared.currentWeather(city: text ?? "Error")
      .catchErrorJustReturn(ApiController.Weather.empty)
  }
  .observeOn(MainScheduler.instance)
```

这个改变，尤其是 flatMapLatest，使得搜索结果可重用，并将一次性的数据源转换到多重使用的observable。这一变化的能力将在专门针对MVVM的章节中介绍，现在只用简单知道，在Rx中observable是能够被大量地（heavily）重用的实体，正确的建模可以使一个长期，难以阅读的一次性观察者变成一个多用途和易于理解的观察者。

![](http://upload-images.jianshu.io/upload_images/2224431-fbc29245f085857e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/500)

通过这个小小的改变，它可以处理来自不同订阅的每个参数，映射到值来请求显示。例如，这里是如何将温度作为字符串从共享数据源中获取的observable：

```swift
search.map { "\($0.temperature)° C" }
```

这将创建一个observable，它返回需要显示温度的字符串。试着创建你的第一个绑定，使用bindTo 来连接原始数据源到温度标签。在 viewDidLoad()中增加：

```swift
search.map { "\($0.temperature)° C" }
  .bindTo(tempLabel.rx.text)
  .addDisposableTo(bag)
```

构建并运行，使用新的RxCocoa绑定能力来显示温度

![](http://upload-images.jianshu.io/upload_images/2224431-0a96ea4603857d57.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/300)



现在应用只显示温度，但你可以简单的在剩余的labels上应用同样的样式来实现前面的功能：

```swift
search.map { $0.icon }
  .bindTo(iconLabel.rx.text)
  .addDisposableTo(bag)

search.map { "\($0.humidity)%" }
  .bindTo(humidityLabel.rx.text)
  .addDisposableTo(bag)

search.map { $0.cityName }
  .bindTo(cityNameLabel.rx.text)
  .addDisposableTo(bag)
```

现在应用程序使用单一的一个叫做search的源observable来显示你请求的来自服务器的数据，并绑定数据块到屏幕上的每个标签：

![](http://upload-images.jianshu.io/upload_images/2224431-abd6c04754622a30.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/300)

另一个不错的清晰的作用是，由编译器检查来确保正确类型的使用。基本上不可能由于类型不同问题导致app崩溃。

	Note：当绑定到UI组件时，RxCocoa将检查观察是否在主线程。如果不上，它将调用fatalError()，应用将崩溃输出下面的信息：fatal error: Element can be bound to user interface only on MainThread.
### 使用Units来改善代码 240

RxCocoa提供更高级的功能，使Cocoa和UIKit的工作变得轻而易举。除了bindTo，它还提供了observable的特殊实现，它们专门用于与UI配合使用：Units。Units是一组类，专用于observable，当与UI一起工作时，它让写代码变得更容易和简单。让我们看看吧！

#### 什么是ControlProperty和Driver? 241

Units的官方文档是这样描述的：

	Units有助于通讯并保证observable序列属性与交互界面绑定。
没有上下文这听起来相对抽象，当给用户界面控件绑定observables时，让我们考虑一些通用的概念。观察需要一直订阅在主线程确保能够更新UI，你常常需要分享订阅来绑定多个UI组件，并且你不想有错误中断UI。

经过以上思考，下面是Units的实际特性列表：

- Units 不能输出错误
- Units在主调度表上被观察
- Units在主调度表上被订阅
- Units共享副作用

这些特性的存在确保了用户界面一直显示一些东西，且显示的数据一直被正确的方式加工过，这样UI就能处理它。Units框架的两个主要组成部分如下：

-  ControlProperty 和 ControlEvent
-  Driver

**ControlProperty**不是新知识；你在不久前（a little while ago）刚刚使用过它，使用专用的rx扩展绑定数据到正确的用户界面组件。

**ControlEvent**被用来监听UI控件的某些事件，像是在编辑文本框时，在键盘上按“返回”按钮。如果该组件使用UIControlEvents来跟踪(keep track of)其当前状态，控制事件就是有效的。

**Driver**是一个特殊的observable，具有与前面相同的约束，它不能输出错误。所有处理必须取保在主线程执行，避免在后台线程改变UI。

Units通常是框架的可选部分，你不需要一定使用它。毫无忌讳的连接observables和subjects来确保正在正确的调度表中做正确的任务——但是如果你想要更好的编译检查和明确的UI约束，Units是强大和节省时间的组件。不使用Untis，就容易忘记调用 .observeOn(MainScheduler.instance)，最后（end up）会尝试在后台进程更新你的UI。

 Driver 和 ControlProperty现在看起来难以理解，不用担心。像许多Rx一样，一旦你深入代码，就会更有感觉。

####  使用Driver and ControlProperty改善项目 241

原理讲完了，是时候应用这些好的概念到你的应用。

第一步，转换天气数据observable到driver。 在viewDidLoad()中找到你定义search 常量的位置，用下面代码替代它：

```swift
let search = searchCityName.rx.text
  .filter { ($0 ?? "").characters.count > 0 }
  .flatMapLatest { text in
    return ApiController.shared.currentWeather(city: text ?? "Error")
      .catchErrorJustReturn(ApiController.Weather.empty)
  }
  .asDriver(onErrorJustReturn: ApiController.Weather.empty)
```

关键代码时底部的： .asDriver(…)。它把observable转换为了Driver。 onErrorJustReturn在observable出错是返回默认值——这为driver自己消除了发射错误的可能。

你可能也注意到自动完成提供了asDriver(onErrorJustReturn:)的另一个变体：

-  asDriver(onErrorDriveWith:)它可以手动处理错误，返回为此目的生成的新序列。
-  asDriver(onErrorRecover:)这一个与另一个现有的驱动程序一起使用。这将会恢复仅仅出现错误的当前驱动程序。

现在用drive替换所有的4个订阅的bindTo。

```
search.map { "\($0.temperature)° C" }
  .drive(tempLabel.rx.text)
  .addDisposableTo(bag)

search.map { $0.icon }
  .drive(iconLabel.rx.text)
  .addDisposableTo(bag)

search.map { "\($0.humidity)%" }
  .drive(humidityLabel.rx.text)
  .addDisposableTo(bag)

search.map { $0.cityName }
  .drive(cityNameLabel.rx.text)
  .addDisposableTo(bag)
```

drive的工作与bindTo十分相似；名称的差异更好地表达使用Units的意图。

你任然有一些地方需要改进。应用使用了太多的资源并产生了太多API请求——因为它在每次输入字符时触发（fire ）一个请求。 有点过分，你不觉得吗？ 

节流（ throttle）将是一个好的选择，但它任然会导致一些非必要的请求。另一个好的选择应该是使用文本框的 ControlProperty并且仅仅当用户点击键盘上的搜索按钮是才出发请求。

下面这行：

```
let search = searchCityName.rx.text
```

用下面代码替换

```
let search =
  searchCityName.rx.controlEvent(.editingDidEndOnExit).asObservable()
    .map { self.searchCityName.text }
```

为了保证输入有效，最好略过空字符串并过滤搜索observable。然后继续链式代码：

```
.flatMap { text in
  return ApiController.shared.currentWeather(city: text ?? "Error")
}
.asDriver(onErrorJustReturn: ApiController.Weather.empty)
```

现在应用仅仅当用户点击搜索按钮才检索天气。没有网络请求被浪费，并且代码由Units在编译时控制。你也移除了 catchErrorJustReturn(_:)

![](http://upload-images.jianshu.io/upload_images/2224431-cd964f7856d6be2a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

原模式使用单observable更新UI；通过多个块的分解，您已从订阅切换到bindTo，并在视图控制器中重复使用相同的可观察值。这种方式让代码易于使用和复用。

例如，如果你想增加当前的大气压显示在用户界面，你所要所的是增加属性到结构体，映射JSON值，然后增加另一个UILabel，并映射那个属性到新标签，简单！

### 销毁RxCocoa 244

本章的最后的主题是纯理论的，超越了这个项目。正如本章开始所说的，在视图控制器有一个bag，当视图控制器施放时，它负责销毁所有的订阅。但是在这个例子中，为什么在闭包中没有使用weak或者unowned？

答案很简单：此应用是单视图控制器，且当app运行时一直在屏幕上，因此不需要用guard来防止循环引用或浪费内存。

#### unowned vs weak with RxCocoa 244

当用Cocoa处理RxCocoa或RxSwift时，很难判断什么时候用weak或unowned。当闭包能够在将来的某个时间内调用，当前self对象已经施放时，你使用weak。为此，self变为可选值。unowned避免了可选的self。但是代码必须确保在闭包获得调用前，对象没有施放——否则app将崩溃。

以下是一些使用weak，unowned或nothing的一些建议：

- nothing：在单例或一个视图控制器中绝不会施放
- unowned：闭包执行之后才施放的所有视图控制器内
- weak：其他情况

这些规则防止经典的EXC_BAD_ACCESS错误。如果你一直遵守这些规则，你将不会遇到内存管理方面的问题。如果你想确保安全，raywenderlich.com Swift Guidelines  https://github.com/raywenderlich/swift-style-guide#extending-object-lifetime 不推荐使用unowned。

### 何去何从？ 245

RxCocoa是一个很大的框架。现在你仅仅使用了很小的一部分。

在接下来的章节，你将会看到，如何通过增加专用的函数来扩展RxCocoa来改善这个应用，如何使用RxSwift和RxCocoa来增加更多高级特性。

在开始之前，让我们花些时间来学习下RxCocoa和.rx扩展。我们来看一组例子：

#### UIActivityIndicatorView

 UIActivityIndicatorView是一个常用的UIKit组件。这个扩展包含了如下属性：

```swift
public var isAnimating: UIBindingObserver<Base, Bool>
```

它的名称已经说明了它是关联到原始的isAnimation属性。正如你所看到的，类似与UILabel，这个属性是UIBindingObserver类型，并且结果是它能够绑定到一个observable来通知后台指示器。正如你在第10张的挑战中所使用的。

#### UIProgressView

UIProgressView不是一个常用的组件，但是它也在RxCocoa中，且有下列属性：

```swift
public var progress: UIBindingObserver<Base, Float>
```

像所有其他类似组件一样， UIProgressBar能够绑定到一个observable。例如，假设有一个 uploadFile()，它正在处理一个上传文件到服务器的任务的observable，提供了发送字节的中间事件和总字节数。这个代码应该应该看起来像这样：

```swift
let progressBar = UIProgressBar()
let uploadFileObs = uploadFile(data: fileData)
uploadFileObs.map { sent, totalToSend in
  return sent / totalToSend
  }
  .bindTo(progressBar.rx.progress)
  .addDisposableTo(bag)
```

结果是：在每一个中间值被提供的时间点更新progress bar，并且用户有任务进度的虚拟指示。

现在改轮到你了。你在扩展中画的时间越多，你将会在后续章节和将来的应用中更安逸的使用它们。

```
Note: RxCocoa是一个持续改进的框架。如果你认为缺少任何控件或扩展，你可以创建它们并提交一个pull请求到官方的仓库。社区欢迎和鼓励你的贡献。
```

