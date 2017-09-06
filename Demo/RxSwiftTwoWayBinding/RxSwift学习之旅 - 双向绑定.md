# RxSwift学习之旅 - 双向绑定

原文链接：http://www.alonemonkey.com/2017/04/01/rxswift-part-ten/

### 抛出问题

首先来看几个问题吧，我们知道监听`UITextField`可以通过如下的方式:

```
textfield.rx.text
        .asObservable()
        .subscribe{
            print($0)
        }
        .disposed(by: disposeBag)
```

但是如果我们这样去改变它的值，是订阅不到的。

```
textfield.text = "这是我修改的值"
```

还有`UILabel`不是一个可被观察对象，所以下面这么写是会报错的:

```
label.rx.text
            .asObservable()
```

但是`UITextView`既可以被订阅，修改`text`也可以被订阅到。

```
textview.rx.text
    .asObservable()
    .subscribe{
        print("textview: \($0)")
    }
    .disposed(by: disposeBag)

textview.text = "这是我修改的值"
```

为什么都是`UI`控件差别这么大(捂脸

### why？

其实这个时候你要思考一下，为什么他们能被观察为什么又不可以？

`UITextField`我们前面讲过，它的`.allEditingEvents`和`.valueChanged`事件会发射值，所以它可以作为被观察对象。

但是`textfield.text = "这是我修改的值"`并不会触发上面两种事件，所以你这样修改并没有被订阅到。

`UILabel`是继承`UIView`不是继承`UIControl`所以它不会响应事件，也就不能作为可被观察对象。

`UITextView`来看下它是怎么发射值的。

从源码可以看到它是通过`NSTextStorageDelegate.textStorage(_:didProcessEditing:range:changeInLength:)`这个`delegate`的回调来发射值的。所以可以作为一个被观察者。

当我们`textview.text = "这是我修改的值"`这样去修改`text`的时候，会触发上面`delegate`的回调，所以会被订阅到。

### 解决？

问题已经找到了，怎么去解决这些问题？

比如我想要

`textfield.text = "这是我修改的值"`

这样去赋值也会发射事件。

这里我们可以用到双向绑定，把`UITextField`的修改和赋值绑定到一个`Subject`，同时还可以被订阅。

首先重载`<->`操作符，后面我们通过这个操作符去进行双向绑定。

```
func <-> <Base: UITextInput>(textInput: TextInput<Base>, variable: Variable<String>) -> Disposable {
    let bindToUIDisposable = variable.asObservable()
        .bindTo(textInput.text)
    let bindToVariable = textInput.text
        .subscribe(onNext: { [weak base = textInput.base] n in
            guard let base = base else {
                return
            }
            
            let nonMarkedTextValue = nonMarkedText(base)
            
            /**
             In some cases `textInput.textRangeFromPosition(start, toPosition: end)` will return nil even though the underlying
             value is not nil. This appears to be an Apple bug. If it's not, and we are doing something wrong, please let us know.
             The can be reproed easily if replace bottom code with
             
             if nonMarkedTextValue != variable.value {
             variable.value = nonMarkedTextValue ?? ""
             }
             
             and you hit "Done" button on keyboard.
             */
            if let nonMarkedTextValue = nonMarkedTextValue, nonMarkedTextValue != variable.value {
                variable.value = nonMarkedTextValue
            }
            }, onCompleted:  {
                bindToUIDisposable.dispose()
        })
    
    return Disposables.create(bindToUIDisposable, bindToVariable)
}
```

使用`<->`双向绑定：

```
let text = Variable("双向绑定")
        
    _  = textfield.rx.textInput <-> text
    
    textfield.rx.text
        .asObservable()
        .subscribe{
            print("textfield: \($0)")
        }
        .disposed(by: disposeBag)
```

那么这样去修改`text`就能被订阅到了。

再来扩展一下`UILabel`:

```
extension UILabel {
    public var rx_text: ControlProperty<String> {
        // 观察text
        let source: Observable<String> = self.rx.observe(String.self, "text").map { $0 ?? "" }
        let setter: (UILabel, String) -> Void = { $0.text = $1 }
        let bindingObserver = UIBindingObserver(UIElement: self, binding: setter)
        return ControlProperty<String>(values: source, valueSink: bindingObserver)
    }
}
```

观察`text`的改变，改变的时候发射值，代码可以这么写了:

```
textfield.rx.text
        .asObservable()
        .subscribe{
            print("textfield: \($0)")
        }
        .disposed(by: disposeBag)
    
    textfield.text = "这是我修改的值"
```

### 总结

所以现在知道了为什么前面有几种不同的表现了吧。

其实很多`UIControl`的子类控件，都可以通过这种双向绑定的方式，以便我们修改它的值时能够被订阅者订阅到。

代码见github:

[RxSwiftTwoWayBinding](https://github.com/AloneMonkey/RxSwiftStudy)