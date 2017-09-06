## RxSwift学习之旅 - 加法运算
原文链接：http://www.alonemonkey.com/2017/03/25/rxswift-part-four/

### 前言

通过前面几篇文章了解了很多`RxSwift`中的概念和序列操作。下面从一个最基础的例子来看看实际开发中的被观察者和订阅者。

这里要实现的仅仅是输入三个整数并实时把三个整数相加的结果显示出来。

### 界面设计

这里没有界面设计就是拖了几个`UITextField`。

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490431861515.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490431861515.png)

当每次上面的三个输入框输入改变了的话，就把三个值相加显示出来。

### 项目准备

首先创建一个`Swift`的项目`RxSwiftCalculator`，`Podfile`内容如下:

```
use_frameworks!

target 'RxSwiftCalculator' do

pod 'RxSwift'
pod 'RxCocoa'

end
```

因为需要用到UI控件里面的Rx扩展，所有引入了`RxCocoa`。

`pod install`后打开`RxSwiftCalculator.xcworkspace`。

把界面拖一下, 然后关联到属性。

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490434019587.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490434019587.png)

### UITextField.rx.text

在这个项目里面我们要监听`UITextField`的事件，然后把里面的数字取出来相加，最后显示到`result`这个`Label`上面。

所以本例中`UITextField`就是一个被观察者。

在`RxCocoa`里面已经对`UITextField`进行了扩展，把的里面的文本变成一个可被观察的对象`text`，源码:

```
extension Reactive where Base: UITextField {
    /// Reactive wrapper for `text` property.
    public var text: ControlProperty<String?> {
        return value
    }
    
    /// Reactive wrapper for `text` property.
    public var value: ControlProperty<String?> {
        return UIControl.rx.value(
            base,
            getter: { textField in
                textField.text
            }, setter: { textField, value in
                // This check is important because setting text value always clears control state
                // including marked text selection which is imporant for proper input 
                // when IME input method is used.
                if textField.text != value {
                    textField.text = value
                }
            }
        )
    }
    
}
```

这里返回的是一个`ControlProperty`类型的字符串，而`ControlProperty`实现了协议`ControlPropertyType`。

```
public struct ControlProperty<PropertyType> : ControlPropertyType {
    //.....
}
```

跟进`ControlPropertyType`:

```
/// Protocol that enables extension of `ControlProperty`.
public protocol ControlPropertyType : ObservableType, ObserverType {

    /// - returns: `ControlProperty` interface
    func asControlProperty() -> ControlProperty<E>
}
```

可以看到`ControlPropertyType`实现了两个协议`ObservableType`和`ObserverType`。所以它即可是一个可被观察的对象，同时也可以作为观察者。

同时，我们看到这里返回了一个`UIControl.rx.value`生成的对象，跟进去看一下：

```
static func value<C: UIControl, T>(_ control: C, getter: @escaping (C) -> T, setter: @escaping (C, T) -> Void) -> ControlProperty<T> {
    let source: Observable<T> = Observable.create { [weak weakControl = control] observer in
            guard let control = weakControl else {
                observer.on(.completed)
                return Disposables.create()
            }

            observer.on(.next(getter(control)))

            let controlTarget = ControlTarget(control: control, controlEvents: [.allEditingEvents, .valueChanged]) { _ in
                if let control = weakControl {
                    observer.on(.next(getter(control)))
                }
            }
            
            return Disposables.create(with: controlTarget.dispose)
        }
        .takeUntil((control as NSObject).rx.deallocated)

    let bindingObserver = UIBindingObserver(UIElement: control, binding: setter)

    return ControlProperty<T>(values: source, valueSink: bindingObserver)
}
```

这里创建了一个可被观察者，那么发射的值是什么时候发射的呢？ 跟进`ControlTarget`的`init`方法:

```
init(control: Control, controlEvents: UIControlEvents, callback: @escaping Callback) {
    MainScheduler.ensureExecutingOnScheduler()

    self.control = control
    self.controlEvents = controlEvents
    self.callback = callback

    super.init()

    control.addTarget(self, action: selector, for: controlEvents)

    let method = self.method(for: selector)
    if method == nil {
        rxFatalError("Can't find method")
    }
}
```

这里的`control`就传进来的`UITextField`对象，然后把它的`controlEvents`事件绑定到了`selector`,这个`selector`是:

```
let selector: Selector = #selector(ControlTarget.eventHandler(_:))
```

然后这个方法里面会调用初始化传进来的`callback`:

```
func eventHandler(_ sender: Control!) {
    if let callback = self.callback, let control = self.control {
        callback(control)
    }
}
```

然后`callback`里面调用:

```
observer.on(.next(getter(control)))
```

发射一个值，调用`getter`:

```
getter: { textField in
                textField.text
            }
```

也就是发射了一个`textField.text`。

这个时候应该明白是怎么回事了吧。

### 监听UITextField

这里测试一下监听`UITextField`的事件触发发射出来的`text`。

```
numberOne.rx.text.asObservable().subscribe{
            print($0)
        }.disposed(by: disposeBag)
```

把它变成一个可被观察者，然后订阅它。

程序启动会发射一个`Optional("")`, 获得焦点或也会发射一个`Optional("")`，然后每次输入都会把当前的文本发射出来:

```
next(Optional(""))
next(Optional(""))
next(Optional("1"))
next(Optional("12"))
next(Optional("123"))
next(Optional("1234"))
```

这里发现它是一个`Optional`的值，可以通过`orEmpty`可以把`String?`转成`String`。

```
numberOne.rx.text.orEmpty.asObservable().subscribe{
            print($0)
        }.disposed(by: disposeBag)

output:
next()
next()
next(1)
next(12)
next(123)
next(1234)
```

我们再想把空字符串过滤掉，可以使用`filter`，就不会订阅到`next()`了。

```
numberOne.rx.text.orEmpty.asObservable()
            .filter{
                return $0 != ""
            }
            .subscribe{
            print($0)
        }.disposed(by: disposeBag)
```

### combineLatest

还记得我们的目的是获取最新的`text`然后相加再显示到`result`吧，那么这里我们可以使用`combineLatest`来获取最新序列的组合。

```
Observable.combineLatest(numberOne.rx.text.orEmpty,numberTwo.rx.text.orEmpty,numberThree.rx.text.orEmpty) { (numberOneText, numberTwoText, numberThreeText) -> Int in
                return (Int(numberOneText) ?? 0) + (Int(numberTwoText) ?? 0) + (Int(numberThreeText) ?? 0)
            }.map{
                $0.description
            }.bindTo(result.rx.text)
            .disposed(by: disposeBag)
```

首先获取最新输入的字符串，然后转成`Int`， 因为字母会转换失败，所以返回的是一个`Optional`，如果转换失败就默认0，然后相加返回，再转成字符串绑定到`result.rx.text`。

这里的`bindTo`其实就是订阅序列，然后更新`result.rx.text`的值。

### 总结

虽然这个例子比较简单，但是相信大家能够体会到前面的一大堆概念在开发的应用以及带给我们的便利了，后续会继续学习复杂一点的例子。

本文代码地址: 

[RxSwiftCalculator](https://github.com/AloneMonkey/RxSwiftStudy)