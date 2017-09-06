# RxSwift学习之旅 - Observable 和 Driver

原文链接：http://www.alonemonkey.com/2017/03/28/rxswift-part-six/

### 什么是Driver

`Driver`的出现是为了让我们在写UI层的响应式代码的时候更加直观。

为什么它的名字叫`Driver`？它意图更好的通过数据去驱动我们的应用程序。

比如:

- 从数据模型去驱动UI
- 使用其它UI元素的值去驱动UI
- …….

在正常开发中，由于用户操作导致错误发生可能会使我们的应用程序崩溃。

由于UI元素操作通常不是线程安全的，要保证在主线程操作。

或者某个序列在有多个订阅者者时只需要`shareReplay(1)`。

### 经典例子

先来看一下经典的例子，看看我们在正常的开发中可能会写出如下的代码:

```
let results = query.rx.text
    .throttle(0.3, scheduler: MainScheduler.instance)
    .flatMapLatest { query in
        fetchAutoCompleteItems(query)
    }

results
    .map { "\($0.count)" }
    .bind(to: resultCount.rx.text)
    .disposed(by: disposeBag)

results
    .bind(to: resultsTableView.rx.items(cellIdentifier: "Cell")) { (_, result, cell) in
        cell.textLabel?.text = "\(result)"
    }
    .disposed(by: disposeBag)
```

这段代码的意图是：

- 对用户的输入进行节流
- 每次查询连接服务器搜索结果
- 绑定结果到UI结果

我们来看看这段代码有什么问题？

- 如果`fetchAutoCompleteItems`发生了错误，网络错误或者解析出错，这个错误会导致取消所有绑定，UI界面也不会更新新的结果。
- 如果`fetchAutoCompleteItems`在后台线程返回了结果，结果可能会在后台线程绑定到UI界面，这样会导致不确定的崩溃。
- 结果绑定到了两个UI元素，意味着，每次用户搜索，会发送2次请求，这不是我们想要的行为。

所以规范一点的写法应该是这样:

```
let results = query.rx.text
    .throttle(0.3, scheduler: MainScheduler.instance)
    .flatMapLatest { query in
        fetchAutoCompleteItems(query)
            .observeOn(MainScheduler.instance)  // results are returned on MainScheduler
            .catchErrorJustReturn([])           // in the worst case, errors are handled
    }
    .shareReplay(1)                             // HTTP requests are shared and results replayed
                                                // to all UI elements

results
    .map { "\($0.count)" }
    .bind(to: resultCount.rx.text)
    .disposed(by: disposeBag)

results
    .bind(to: resultsTableView.rx.items(cellIdentifier: "Cell")) { (_, result, cell) in
        cell.textLabel?.text = "\(result)"
    }
    .disposed(by: disposeBag)
```

要保证这些所有的情况都被处理在大的系统里面是很难的，这里有一种简单的方法哪就是使用`Driver`。来看下下面的例子:

```
let results = query.rx.text.asDriver()        // This converts a normal sequence into a `Driver` sequence.
    .throttle(0.3, scheduler: MainScheduler.instance)
    .flatMapLatest { query in
        fetchAutoCompleteItems(query)
            .asDriver(onErrorJustReturn: [])  // Builder just needs info about what to return in case of error.
    }

results
    .map { "\($0.count)" }
    .drive(resultCount.rx.text)               // If there is a `drive` method available instead of `bindTo`,
    .disposed(by: disposeBag)              // that means that the compiler has proven that all properties
                                              // are satisfied.
results
    .drive(resultsTableView.rx.items(cellIdentifier: "Cell")) { (_, result, cell) in
        cell.textLabel?.text = "\(result)"
    }
    .disposed(by: disposeBag)
```

### Driver特性

上面改进后的版本发生了什么？首先第一个`asDriver`把`ControlProperty`对象转换成了`Driver`对象。

```
query.rx.text.asDriver()
```

`Driver`拥有`ControlProperty`的所有属性，其实它是在上面包了一层。

第二个改变的地方是:

```
.asDriver(onErrorJustReturn: [])
```

任何的可被观察的序列都能转成`Driver`，只要满足以下3点:

- 不能抛出错误
- 订阅在主线程
- 多个订阅者`shareReplay(1)`

`asDriver(onErrorJustReturn: [])`其实等同于:

```
let safeSequence = xs
  .observeOn(MainScheduler.instance)       // observe events on main scheduler
  .catchErrorJustReturn(onErrorJustReturn) // can't error out
  .shareReplayLatestWhileConnected         // side effects sharing
return Driver(raw: safeSequence)           // wrap it up
```

最后一点就是使用`drive`代替`bindTo`。

所以下面的代码:

```
let intDriver = sequenceOf(1, 2, 3, 4, 5, 6)
    .asDriver(onErrorJustReturn: 1)
    .map { $0 + 1 }
    .filter { $0 < 5 }
```

等价:

```
let intObservable = sequenceOf(1, 2, 3, 4, 5, 6)
    .observeOn(MainScheduler.sharedInstance)
    .catchErrorJustReturn(1)
    .map { $0 + 1 }
    .filter { $0 < 5 }
    .shareReplay(1)
```

### 总结

通过例子，大家也看到了什么时候应该使用`Driver`，如果你的代码需要满足上面三种情况的话，那么你可以使用`Driver`。否则如果你要多次切换线程、自己捕获传递错误、或者其它，可以仍用`Observable`。

大家试着把上一篇讲的注册项目改成`Driver`。

然后参考`Driver`的版本:

[RxSwiftRegisterDriver](https://github.com/AloneMonkey/RxSwiftStudy)

