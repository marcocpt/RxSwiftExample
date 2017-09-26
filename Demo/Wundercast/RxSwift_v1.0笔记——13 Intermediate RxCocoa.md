## RxSwift_v1.0笔记——13 Intermediate RxCocoa

这章将学习一些高级的RxCocoa集成技巧，围绕原生的UIKit组件进行自定义封装


     Note: 本章不讨论RxSwift构架，也不包括RxSwift/RxCocoa项目的最佳结构。这些讨论将放在23章“MVVM withRxSwift”


###  开始

在ApiController.swift中替换你的 API key。如果没有，可在 https://home.openweathermap.org/users/sign_up 这个网站申请key
```swift
private let apiKey = "[YOUR KEY]"
```
###当搜索时显示activity
当用户点击搜索按钮时，应用没有反馈，这节将练习增加这个功能。
下图是这个功能的逻辑

![](http://upload-images.jianshu.io/upload_images/2224431-e7039cafcbcaaa9c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

为了完成这个任务，你需要拆分事件流，以便当用户按按键后，服务器数据到达时你会收到通知。

打开ViewController.swift，在 viewDidLoad()方法的style()函数下增加如下代码：

```swift
let searchInput =
  searchCityName.rx.controlEvent(.editingDidEndOnExit).asObservable()
    .map { self.searchCityName.text }
    .filter { ($0 ?? "").characters.count > 0 }
```

当用户按下搜索键且输入的字符串不为空时， searchInput observable为搜索提供文本。

现在不用重头创建了，你可以使用 searchInput observable来修改 search observable。

```swift
let search = searchInput.flatMap { text in
  return ApiController.shared.currentWeather(city: text ?? "Error")
    .catchErrorJustReturn(ApiController.Weather.dummy)
  }
  .asDriver(onErrorJustReturn: ApiController.Weather.dummy)
```

现在，当应用调用API为忙时，你有两个observables 可以用来标示。你可以选择绑定两个observables，正确的映射到 UIActivityIndicatorView的 isAnimating属性，然后用 isHidden属性为所有的labels做同样的事。这看起来简单，但在Rx有更简洁的方法。

searchInput 和search能合并到一个observable，依据是否正在接受事件来决定是true还是false。

在刚增加的代码块下面增加：

```swift
let running = Observable.from([
  searchInput.map { _ in true },
  search.map { _ in false }.asObservable()
  ])
  .merge()
  .startWith(true)
  .asDriver(onErrorJustReturn: false)
```

组合后的结果如下：

![](http://upload-images.jianshu.io/upload_images/2224431-3ee07a010ee0cf03.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

.asObservable()帮助类型转换
.startWith(true)避免了在应用启动时手动隐藏所有labels     

现在，创建绑定将会非常简单。下面代码可以防止绑定到labels之前或之后，他们没有区别：

```swift
running
  .skip(1)
  .drive(activityIndicator.rx.isAnimating)
  .addDisposableTo(bag)
```

第一个值是手动注入的，因此你必须略过，否则应用在打开时activity indicator将立即显示。

Then add the following to hide and show the labels accordingly to the status:

```swift
running
  .drive(tempLabel.rx.isHidden)
  .addDisposableTo(bag)
running
  .drive(iconLabel.rx.isHidden)
  .addDisposableTo(bag)
running
  .drive(humidityLabel.rx.isHidden)
  .addDisposableTo(bag)
running
  .drive(cityNameLabel.rx.isHidden)
  .addDisposableTo(bag)
```

the application now should look like the following when it’s making an API request:

![](http://upload-images.jianshu.io/upload_images/2224431-55d4f43e0ce0dc96.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/310)

All labels should be hidden, but the activity indicator should not display

### 扩展CCLocationManager用来获得当前的位置

A weather application that doesn’t know its current location is a bit odd, to say the least. You can fix this by using some of the components provided in RxCocoa.

##### 创建扩展

第一步封装CoreLocation框架。打开 CLLocationManager+Rx.swift文件。

为保持风格一致所有的扩展加上了“.rx"命名空间。聪明的实现方法是使用RxSwift提供的Reactive代理

打开RxSwift库的 Reactive.swift文件，你会发现一个结构体Reactive<Base>、一个协议 ReactiveCompatible和一个扩展 ReactiveCompatible,它有用来创建命名空间rx的变量。

这个文件的最后一行是：

```swift
/// Extend NSObject with `rx` proxy.
extension NSObject: ReactiveCompatible { }
```

这显示了继承至 NSObject的类如何获得rx命名空间。你的任务是为 CLLocationManager创建专用的rx扩展，并且暴露给其他类使用。

导航到RxCocoa文件夹，你会发现一些Objective-C 文件 _RxDelegateProxy.h 、 _RxDelegateProxy.m也有 DelegateProxy.swift /和 DelegateProxyType.swift.这些文件包含了聪明的解决了桥接RxSwift与其他框架的实现，它使用代理（数据源）作为供应数据的主要资源。

DelegateProxy伪造了一个代理对象，它将代理获得的所有数据接收到专用的observables。

![](http://upload-images.jianshu.io/upload_images/2224431-0968b64a3fe0f22f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

DelegateProxy和 在Reactive的正确使用的组合将使你的CLLocationManager扩展看起来就像所有其他RxCocoa扩展程序一样。

CLLocationManager需要一个delegate,，因此你需要创建一个必要的proxy，将所有来自必要的位置管理数据delegates到专用的observable中。映射是一个简单的一对一关系，因此单个协议函数将对应于返回给定数据的单个observable。

在 CLLocationManager+Rx.swift中增加以下代码：

```swift
class RxCLLocationManagerDelegateProxy: DelegateProxy,
  CLLocationManagerDelegate, DelegateProxyType {
}
```

RxCLLocationManagerDelegateProxy将成为你的proxy，在一个observable创建并有一个订阅后立刻附加到 CLLocationManager实例。

这时(at this point)，你需要为proxy delegate增加setter和getter。首先增加setter：

```swift
class func setCurrentDelegate(_ delegate: AnyObject?, toObject object:
AnyObject) {
  let locationManager: CLLocationManager = object as! CLLocationManager
  locationManager.delegate = delegate as? CLLocationManagerDelegate
}
```

然后是getter：

```swift     
class func currentDelegateFor(_ object: AnyObject) -> AnyObject? {
  let locationManager: CLLocationManager = object as! CLLocationManager
  return locationManager.delegate
}
```

通过使用这两个函数，你能够获取并设置 delegate，这将是proxy用来推动来至 CLLocationManager实例的数据连接到observables。这就是如何扩展一个类来使用RxCocoa的delegate proxy模式。

现在使用你刚刚创建的proxy delegate创建observables来观察位置的改变，增加以下代码：

```swift
extension Reactive where Base: CLLocationManager {
  var delegate: DelegateProxy {
    return RxCLLocationManagerDelegateProxy.proxyForObject(base)
  }
}
```

对于 CLLocationManager的一个实例，使用Reactive扩展将暴露该扩展中的rx命名空间中的方法。对于每一个 CLLocationManager实例，你现在有一个暴露的扩展rx可用。但是不幸的是，你没有真实的observables来获得真实的数据。

为了修复这个问题，在你刚刚创建的扩展中增加以下代码：

```swift
var didUpdateLocations: Observable<[CLLocation]> {
  return
    delegate.methodInvoked(#selector(CLLocationManagerDelegate
      .locationManager(_:didUpdateLocations:)))
  .map { parameters in
    return parameters[1] as! [CLLocation]
  }
}
```

用这个函数，delegate当做proxy来监听所有的 didUpdateLocations的调用，来获得数据并投递到一个 CLLocation数组中。 methodInvoked(_:)是在RxCocoa中的Objective-C代码的一部分，也是作为delegates的低等级的观察者

不管什么时候methodInvoked(_:)方法被调用，它都会返回一个observable发送next事件。这些事件中包含的元素是调用该方法的参数的数组。你用 parameters[1]访问这个数组，然后投递它到一个 CLLocation数组中。

现在你可以在你的应用中继承这个扩展了。

##### 用按钮获得当前的位置

你已经创建了扩展，现在你能够使用在左下角的定位按钮：

![](http://upload-images.jianshu.io/upload_images/2224431-037490fe7dc383b1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

切换到ViewController.swift，处理按钮逻辑前，需要做些准备工作。第一，导入 CoreLocation框架

```swift
import CoreLocation
```

下一步，增加定位管理到视图控制器：

```
let locationManager = CLLocationManager()
```

你需要确保应用有足够的权限访问用户的位置。从iOS8后，在应用获取位置数据前，操作系统必须获得用户许可。因此，首先你需要的是，当用户点击位置按钮时，请求许可然后更新数据。

在 viewDidLoad()中增加以下代码实现：

```swift
geoLocationButton.rx.tap
  .subscribe(onNext: { _ in
    self.locationManager.requestWhenInUseAuthorization()
    self.locationManager.startUpdatingLocation()
  })
  .addDisposableTo(bag)
```

为了测试应用是否接收到了用户的位置，使用下面的临时片段测试：

```Swift
locationManager.rx.didUpdateLocations
  .subscribe(onNext: { locations in
    print(locations)
  })
  .addDisposableTo(bag)
```

当你构建并允许程序后，你应该能够看到类似下图中控制台输出：

![](http://upload-images.jianshu.io/upload_images/2224431-f62de778e0c07253.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

     Note：当使用仿真器时，你可以伪造位置，通过Debug\Location，然后选择一个仿真的位置。

在 ApiController.swift里有一个专用的函数，它基于用户的经纬度检索来至服务器的数据。

```Swift
func currentWeather(lat: Double, lon: Double) -> Observable<Weather>
```

在 viewDidLoad()，创建一个observable， 返回最新的有效位置：

```Swift
let currentLocation = locationManager.rx.didUpdateLocations
  .map { locations in
    return locations[0]
  }
  .filter { location in
    return location.horizontalAccuracy < kCLLocationAccuracyHundredMeters
  }
```

didUpdateLocations发射了一个抓取位置的数组，但你只需要一个，这就是为什么你使用map获得第一个位置。然后您使用filter来防止使用完全不同的数据，并确保位置准确到一百米以内。

##### 用当前的数据更新天气

你有一个observable用来返回用户的位置，并且有一个机制，基于经纬度来获得天气。一个自然的组合在RxSwift中应该是：

![](http://upload-images.jianshu.io/upload_images/2224431-3f92b98156c35cb7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

模拟observables的请求，用下面代码替换 已经存在的geoLocationButton.rx.tap：

```swift
let geoInput = geoLocationButton.rx.tap.asObservable()
  .do(onNext: {
    self.locationManager.requestWhenInUseAuthorization()
    self.locationManager.startUpdatingLocation()
  })
let geoLocation = geoInput.flatMap {
  return currentLocation.take(1)
}
```
上面代码确保了位置管理器正在更新并提供关于当前位置的信息，并且仅转发单个值。这样可以防止应用程序每次从位置管理器更新新值。
现在创建一个新的observable检索天气数据

```swift
let geoSearch = geoLocation.flatMap { location in
    return ApiController.shared.currentWeather(lat:
        location.coordinate.latitude, lon: location.coordinate.longitude)
        .catchErrorJustReturn(ApiController.Weather.dummy)
}
```

上面代码生成了一个天气类型的observable的geoSearch，这与使用城市名称作为输入的调用相同。两个observables返回同样的天气类型，执行同样的任务，这听起来像是代码需要重构！

是的，上面的代码与城市名作为输入的代码，能够用observable进行合并。这个新的特性给了你同样的结果而不必重构整个应用。

我们的目标是保持search作为Weather的Driver，并且作为当前应用状态的observable来运行。为了实现第一个目标，删除当前的search observable，并在你声明searchInput之后创建一个中间量：

```swift
let textSearch = searchInput.flatMap { text in
    return ApiController.shared.currentWeather(city: text ?? "Error")
        .catchErrorJustReturn(ApiController.Weather.dummy)
}
```

现在你能够用 geoSearch合并 textSearch，来创建一个新的搜索observable，在前面的块后面附加：

```swift
let search = Observable.from([geoSearch, textSearch])
    .merge()
    .asDriver(onErrorJustReturn: ApiController.Weather.dummy)
```

这将传递一个Weather对象到与源相关的UI，既可以是城市名也可以是用户的当前位置。最后一步是提供反馈并确保搜索时正确的显示activity indicator，在请求完成后隐藏它。

现在，跳转到定义 running observable.的位置，改变第一行代码以便 geoInput包含在源中，如下：

```swift
let running = Observable.from([
  searchInput.map { _ in true },
  geoInput.map { _ in true },
  search.map { _ in false }.asObservable()
  ])
```

现在不管是用户搜索城市还是点击位置按钮，应用的行为将完全一致。

你使用合并操作增加了一个额外的源来扩展应用的功能，它转换你的扁平的，单一数据流转换为多源合一的数据流：

![](http://upload-images.jianshu.io/upload_images/2224431-2d9ed393641ab594.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

也有一些运行状态的改变：

![](http://upload-images.jianshu.io/upload_images/2224431-1c4ece25b612388f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/500)

你已经创建了一个相当高级的应用：你开始用一个单一的文本源，现在你有了两个与前一章代码逻辑相似的数据源。
### 怎样扩展UIKit view

现在是时候探索如何扩展UIKit组件去超越RxCocoa所提供的了。

应用现在显示了用户位置的天气，但是在滚动和导航的同时，您可以在地图上探索周围的天气。

这听起来像是你将创建新的reactive扩展，这次是MKMapView类。

#### 使用MKMapView扩展UIKit views

开始扩展 MKMapView，你将开始用你扩展 CLLocationManager所使用的相同的样式：为 MKMapView base 类创建一个delegate proxy RxMKMapViewDelegateProxy 和 extend Reactive。

打开 MKMapView+Rx.swift，你可以在Extensions目录找到它，然后创建扩展的基础：

```swift
class RxMKMapViewDelegateProxy: DelegateProxy, MKMapViewDelegate,
  DelegateProxyType {

}
extension Reactive where Base: MKMapView {

}
```

在RxMKMapViewDelegateProxy内部，创建delegate的setter和getter以使proxy到位：

```swift
class func currentDelegateFor(_ object: AnyObject) -> AnyObject? {
  let mapView: MKMapView = (object as? MKMapView)!
  return mapView.delegate
}
class func setCurrentDelegate(_ delegate: AnyObject?, toObject object:
  AnyObject) {
  let mapView: MKMapView = (object as? MKMapView)!
  mapView.delegate = delegate as? MKMapViewDelegate
}
```

下一步，通过增加以下的Reactive扩展来创建proxy：

```swift
public var delegate: DelegateProxy {
  return RxMKMapViewDelegateProxy.proxyForObject(base)
}
```

你已经创建了proxy。现在你能够扩展 MKMapView到代理委派的方法到observables。

在扩展 MKMapView之前，需要确保当前项目能够正确的显示map视图。

在视图控制器右下角已经有了这个按钮：

![](http://upload-images.jianshu.io/upload_images/2224431-74ec49b44da73ff0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

现在增加代码到 viewDidLoad()，以便在按钮按下时用来显示或隐藏地图视图：

```swift
mapButton.rx.tap
  .subscribe(onNext: {
    self.mapView.isHidden = !self.mapView.isHidden
  })
  .addDisposableTo(bag)
```

构建并运行项目，然后重复点击map按钮来查看地图的显示和隐藏：

![](http://upload-images.jianshu.io/upload_images/2224431-ee8cf75c17a7a3ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/310)

#### 在地图上显示叠加层 260

现在地图已经准备接收和显示数据，但是首先你需要增加天气叠加层。你需要执行以下delegate方法：

```swift
func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) ->
MKOverlayRenderer
```

在Rx上封装一个有返回类型的delegate是非常困难的，有以下两个原因：

- 具有返回类型的Delegate方法不适用于观察，而是用于定制行为。
- 定义自动的默认值可以工作在任何情况下是一个不平常的taskIdentifier。


你能够使用Subject观察这个值，但是这样的话它将提供非常小的值

考虑所有这些情况，最后的解决方案是将此调用转发(forward)给delegate的classic实现

![](http://upload-images.jianshu.io/upload_images/2224431-2369495fad2a07d0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

基本上你获得了最好的两个世界：您希望使用返回值符合代理的方法，就像使用普通UIKit开发一样实用，但是你也希望能够使用来至代理函数的observables。这次，只有一次，你能同事拥有他们

MKMapViewDelegate不是唯一的，有代理函数协议需要一个返回类型的协议，有一个现成的方法帮助你解决：

```swift
public static func installForwardDelegate(_ forwardDelegate: AnyObject,
retainDelegate: Bool, onProxyForObject object: AnyObject) -> Disposable
```

如果你想查看函数的实现，在RxCocoa中查找 DelegateProxyType.swift。

你希望转发在Rx proxy中没有封装的代理方法。为MKMapView增加Reactive扩展：

```swift
public func setDelegate(_ delegate: MKMapViewDelegate) -> Disposable {
  return RxMKMapViewDelegateProxy.installForwardDelegate(
    delegate,
    retainDelegate: false,
    onProxyForObject: self.base
  )
}
```

用这个函数，你现在能够安装一个转发代理，它将转发调用，如果需要，它也提供返回值。

增加下面代码到 viewDidLoad()的结尾，设置视图控制器作为delegate, 来接收来至你RxProxy的所有未处理的调用。

```swift
mapView.rx.setDelegate(self)
  .addDisposableTo(bag)
```

编译器会报错（协议没有实现）。在文件末尾增加下面代码：

```swift
extension ViewController: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) ->
    MKOverlayRenderer {
      if let overlay = overlay as? ApiController.Weather.Overlay {
        let overlayView = ApiController.Weather.OverlayView(overlay:
          overlay, overlayIcon: overlay.icon)
        return overlayView
      }
      return MKOverlayRenderer()
  }
}
```

OverlayView是需要通过MKMapView实例来渲染覆盖在地图上的信息的类型。这里的目标是简单的在地图上显示天气图标——不需要提供任何额外的信息。稍后，将详细介绍 OverlayView。

到这你几乎完成了：你解决了delegate返回类型的问题，创建了转发proxy，设置了覆盖显示。现在是时候用RxSwift处理这些overlays。

导航到MKMapView+Rx.swift，增加下面绑定观察者到Reactive扩展，这将抓取 MKOverlay的所有实例并把它们注入到当前的地图中：

```swift
var overlays: UIBindingObserver<Base, [MKOverlay]> {
  return UIBindingObserver(UIElement: self.base) { mapView, overlays in
    mapView.removeOverlays(mapView.overlays)
    mapView.addOverlays(overlays)
  }
}
```

使用 UIBindingObserver让你可以使用 bindTo或drive函数——非常方便！

overlays内部绑定了observable,先前的overlays将被移除并重新创建

考虑应用的范围，这儿没有任何优化的必要。同一时刻不可能超过10个overlays，所以删除所有内容并增加新内容是一个公平妥协。如果不需要处理更多，你能够使用diff algorithm来改进性能并减少开销。

#### 使用已创建的绑定 262

打开 ApiController.swift并检查 Weather结构体。这里有两个嵌套的类：**Overlay和OverlayView**。

**Overlay**是NSObject的子类并实现了 MKOverlay协议。这是你将传递到 OverlayView的，渲染实际数据并覆盖在地图上的数据的信息对象。你仅仅需要知道， Overlay只保持了在地图上显示图标的必要信息：坐标，显示数据的矩形和当前使用的图标。

**OverlayView**的责任是渲染overlay。为了避免导入图片， **imageFromText**将把文本转换为图片，因此图标作为overlay能够容易的显示在地图上。 OverlayView只需要原始的overlay实例和图标字符串来创建一个新的实例。

在Wearther 结构体中，你将看到一个便利的函数，它转换了结构体到一个有效的Overlay：

```swift
func overlay() -> Overlay { ... }
```

切换到ViewController.swift并增加以下代码到 viewDidLoad()：

```swift
search.map { [$0.overlay()] }
  .drive(mapView.rx.overlays)
  .addDisposableTo(bag)
```

这绑定了最新送达的数据到你前面创建的overlays目标，并映射Weather到正确的overlay。

构建并运行程序，搜索一个城市，然后打卡地图，滚动到那个城市，你应该看到像下图所示：

![](http://upload-images.jianshu.io/upload_images/2224431-6a175757f0f60467.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/250)



#### 观察地图滚动事件

用绑定属性扩展 MKMapView后，是时候看看怎样为delegates实现更多便利的通知机制。与你定义的 CLLocationManager没有什么是不同的，你可以用同样的样式。

现在的目标是监听来之地图视图的用户拖动事件和其他导航事件。一旦用户停止浏览(navigate around)，你将为地图的中心位置更新天气状况并显示它。

 MKMapViewDelegate提供了以下方法来观察这个变化：

```swift
func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated:
Bool)
```

在你实现这个代理方法时，每次用户拖动地图到一个新的区域都会被调用。这是一个创建reactive扩展的好机会。在MKMapView+Rx.swift的扩展内增加：

```swift
public var regionDidChangeAnimated: ControlEvent<Bool> {
  let source = delegate
    .methodInvoked(#selector(MKMapViewDelegate
      .mapView(_:regionDidChangeAnimated:)))
    .map { parameters in
      return (parameters[1] as? Bool) ?? false
  }
  return ControlEvent(events: source)
}
```

为了安全，如果投递失败，该方法范围false。

#### 响应regionDidChangeAnimated事件

剩下的部分是使用先前创建的 ControlEvent

切换到 ViewController.swift，你需要做以下改变：

- 创建mapInput，它将使用先前创建的observable。

- 创建mapSearch，它将为位置触发搜索。

- 更新search的observable来处理mapSearch的结果。

- 更新running的observable来正确的处理地图事件和天气结果。

第一个改变是相当的简单，并且必须在 `let textSearch = …`之后完成

```swift
let mapInput = mapView.rx.regionDidChangeAnimated
    .skip(1)
    .map { _ in self.mapView.centerCoordinate }
```

skip（1）可以防止应用程序在mapView初始化之后立即触发搜索。

下一步使用 mapInput创建 mapSearch observable，来抓取地图的天气数据：

```swift
let mapSearch = mapInput.flatMap { coordinate in
    return ApiController.shared.currentWeather(lat: coordinate.latitude,
                                               lon: coordinate.longitude)
        .catchErrorJustReturn(ApiController.Weather.dummy)
}
```

接下来需要更新搜索结果和运行状态的observable

```swift
let search = Observable.from([geoSearch, textSearch, mapSearch])
```

你仅仅添加mapSearch在数组末端。最后要做的以下列方式来修改observable的调用运行：

```swift
let running = Observable.from([searchInput.map { _ in true },
                               geoInput.map { _ in true },
                               mapInput.map { _ in true},
                               search.map { _ in false }.asObservable()])
    .merge()
    .startWith(true)
    .asDriver(onErrorJustReturn: false)
```

像以前一样，简单的增加` mapInput.map { _ in true}`到数组而不需要改变链式代码。

构建并运行你的应用，浏览(navigate around)地图，查看每个滚动后显示当地天气状况的天气图标！

### RxCocoa总结

在这两个章节，你在RxSwift上浏览了惊人的扩展的大部分有趣的部分。RxCocoa不是强制性的，你可以完全不使用它来写你的应用，但是猜想你已经知道了它对你应用是有用的。

下面列出了RxCocoa的优点：

- 它已经为大部分常用的组件集成了许多扩展
- 它超越(goes beyond)了基本的UI组件
- 它很容易与bindTo或drive一起使用
- 它提供了所有用来创建你自定义扩展的机制

在开始下章前，浏览下RxCocoa来增加使用更多通用扩展的信心，下章将使用非常广泛。

### 挑战

#### 挑战1：添加绑定属性以将地图聚焦在给定点上

#### 挑战2：使用MKMapView来浏览位置并显示附近的天气条件