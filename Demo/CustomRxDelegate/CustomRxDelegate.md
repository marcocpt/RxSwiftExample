## RxDelegate

http://t.swift.gg/d/41-022-rxdelegate

### <u>根据Swift3, RxSwift 3.6进行更新</u>

> 本节示例代码均在 [RxExtensions] -> [RxDelegate]

可能我们现在正打算在已有的项目中使用 Rx ，但是 `delegate` 这种东西并不适合我们链式处理问题，好在 **RxCocoa** 中已经给了我们一个比较完善的解决方案： **DelegateProxy** 。

> 至少应对 Cocoa 的 delegate 已经不是什么很大的问题，至于自己写的 delegate ，支持起来也不是件难事。

## DelegateProxyType

你可以直接去看 [DelegateProxyType.swift](https://github.com/ReactiveX/RxSwift/blob/6df77da4745338fa13986d044f6b764af4c3d99f/RxCocoa/Common/DelegateProxy.swift) ，文件中给出了一个基本的原理解释。

```
      +-------------------------------------------+
      |                                           |                           
      | UIView subclass (UIScrollView)            |                           
      |                                           |
      +-----------+-------------------------------+                           
                  |                                                           
                  | Delegate                                                  
                  |                                                           
                  |                                                           
      +-----------v-------------------------------+                           
      |                                           |                           
      | Delegate proxy : DelegateProxyType        +-----+---->  Observable<T1>
      |                , UIScrollViewDelegate     |     |
      +-----------+-------------------------------+     +---->  Observable<T2>
                  |                                     |                     
                  |                                     +---->  Observable<T3>
                  |                                     |                     
                  | forwards events                     |
                  | to custom delegate                  |
                  |                                     v                     
      +-----------v-------------------------------+                           
      |                                           |                           
      | Custom delegate (UIScrollViewDelegate)    |                           
      |                                           |
      +-------------------------------------------+   
```

为了将 delegate 中每个逻辑分解出来，我们需要建立一个中间代理，每次触发 delegate 时，都先触发这个代理，然后这个代理作为一个序列发射值给多个订阅者，这样我们就将不相关的逻辑分开了，不需要将所有的逻辑都写在同一个 delegate 中。

事实上 RxCocoa 已经为我们提供了一些 proxy ：

- `RxCollectionViewDataSourceProxy`
- `RxCollectionViewDelegateProxy`
- `RxScrollViewDelegateProxy`
- `RxSearchBarDelegateProxy`
- `RxTableViewDataSourceProxy`
- `RxTableViewDelegateProxy`
- `RxTextViewDelegateProxy`
- `RxTextStorageDelegateProxy`
- `RxImagePickerDelegateProxy`
- ...

DataSource 的处理稍微复杂一些，我们暂时先不谈（即不谈那些带返回值的 func ）。

如果你去看我们常用的 tableView 的点击处理：

```Swift
public var itemSelected: ControlEvent<IndexPath> {
    let source = self.delegate.methodInvoked(#selector(UITableViewDelegate.tableView(_:didSelectRowAt:)))
        .map { a in
            return try castOrThrow(IndexPath.self, a[1])
        }

    return ControlEvent(events: source)
}
```

它实际上是去观察当前的 selector ，每当触发时都会发射一次值。我们完全可以参照这里的方式来处理我们自定义的 delegate （同时也适用于已有的 Cocoa 的 delegate ）。

## Custom RxDelegate

假设我们的项目中封装了一个叫做 `RxDelegateButton` 的控件，我们为之添加了一个手势，这个手势会触发一个事件，这个事件是通过 delegate 传递的：

```Swift
@objc protocol RxDelegateButtonDelegate: NSObjectProtocol {
  @objc optional func trigger()
}

class RxDelegateButton: UIButton {
  
  weak var delegate: RxDelegateButtonDelegate?
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    addTarget(self, action: #selector(RxDelegateButton.buttonTap), for: .touchUpInside)
  }
  
  
  @objc private func buttonTap() {
    delegate?.trigger?()
  }
  
}
```

大概就像这样的一个控件，你可能会问我为什么 protocol 不写成下面这个样子：

```Swift
protocol RxDelegateButtonDelegate: class {
    func trigger()
}
```

我们稍后就来解释这个问题。

在 Storyboard 中添加一个 `RxDelegateButton` ，设置好 `delegate` ,

```Swift
class RxDelegateViewController: UIViewController {

    @IBOutlet weak var delegateButton: RxDelegateButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegateButton.delegate = self

    }

}

extension RxDelegateViewController: RxDelegateButtonDelegate {
    
    func trigger() {
        print("trigger")
    }
    
}
```

对于当前控件的处理我想我们已经完成了，每当点击这个定制的 button ，都会触发 `trigger()` 。

接下来就是对 delegate 的处理了。

我们需要建立一个 `RxDelegateButtonDelegateProxy` 。

```swift
class RxDelegateButtonDelegateProxy: DelegateProxy, DelegateProxyType, RxDelegateButtonDelegate  {
  
  static func currentDelegateFor(_ object: AnyObject) -> AnyObject? {
    guard let rxDelegateButton = object as? RxDelegateButton else {
      fatalError()
    }
    return rxDelegateButton.delegate
  }
  
  static func setCurrentDelegate(_ delegate: AnyObject?, toObject object: AnyObject) {
    guard let rxDelegateButton = object as? RxDelegateButton else {
      fatalError()
    }
    if delegate == nil {
      rxDelegateButton.delegate = nil
    } else {
      guard let delegate = delegate as? RxDelegateButtonDelegate else {
        fatalError()
      }
      rxDelegateButton.delegate = delegate
    }
  }
  
}
```

基本的 Proxy 都是这样设置的，主要是要继承 `DelegateProxy` 和实现 `DelegateProxyType` ，别忘了加上我们自己的 `RxDelegateButtonDelegate` 。

对 Proxy 的使用也很简单，添加一个 extension ：

```swift
extension Reactive where Base: RxDelegateButton {
  var delegate: DelegateProxy {
    return RxDelegateButtonDelegateProxy.proxyForObject(base)
  }
  
  var SM_trigger: ControlEvent<Void> {
    let source: Observable<Void> = delegate.sentMessage(#selector(RxDelegateButtonDelegate.trigger)).map { _ in }
    return ControlEvent(events: source)
  }
  
  var MI_trigger: ControlEvent<Void> {
    let source: Observable<Void> = delegate.methodInvoked(#selector(RxDelegateButtonDelegate.trigger)).map { _ in }
    return ControlEvent(events: source)
  }
}
```

此时我们就可以直接去使用了：

```swift
delegateButton.rx.delegate
      .sentMessage(#selector(RxDelegateButtonDelegate.trigger))
      .map { _ in }
      .subscribe(onNext: {
        print("\(Date()) - delegate_trigger")
      })
      .addDisposableTo(rx_disposeBag)
    
    delegateButton.rx.SM_trigger
      .subscribe(onNext: {
        print("\(Date()) - SM_trigger")
      })
      .addDisposableTo(rx_disposeBag)
```

你还可以多添加一个：

```swift
delegateButton.rx.MI_trigger
  delegateButton.rx.MI_trigger
    .subscribe(onNext: {
      print("\(Date()) - MI_trigger")
    })
      .addDisposableTo(rx_disposeBag)
```

甚至更多，这样一来我们就不需要将每一次的逻辑都添加到同一个 `trigger()` 中了。特别是应对多个控件一个 `delegate` 的场景，就比如一个 `ViewController` 中放入多个 `UITableView` 之类的情况。逻辑是否更清晰了一些呢？

## Tips

### @objc

我们需要调用 `.observe(#selector(RxDelegateButtonDelegate.trigger))` ，而 `Selector` 是需要用 `@objc` 标记的。这在 Swift 2.2 之前使用 String 的方式虽然不会出现 Error ，但基本会因为找不到对应的方法而直接 Crash ，这在 2.2 中有所改进，也就是现在这个样子。至少在 2.2 我们不需要再担心写错 Selector 的事情了。

### 设置 delegate

我以本节的例子举例，你可以在使用 `rx_trigger` 前设置自己的一份 `delegate` ，也可以不设置。但千万不要在使用 `rx_trigger` 后再去设置 `delegate` 。重新设置 `delegate` 会解除之前的 proxy 的处理。我的建议是，永远不再设置 `delegate` 。