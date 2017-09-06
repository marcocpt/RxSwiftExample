# RxSwift学习之旅 - 使用Result传递Error                                    

原文链接：http://www.alonemonkey.com/2017/03/31/rxswift-part-nine/

### 前言

我们知道一个可被观察序列在它们收到`error`或者`completed`事件的时候会终止，终止也就意味着它的订阅者不会收到任何新的消息了。当我们开始学习`Rx`的时候可能还不会意识到这条规则的后果。

### example

很多的应用通常会在点击某个按钮的时候发网络请求，下面来看看这个例子。

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490794130730.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490794130730.png)

点击`Success`模拟调用一个api请求，返回成功，同样，点击`Failure`触发`error`，点击会增加计数。

### code

首先把成功的点击返回`true`，失败的点击返回`false`，然后合并成单个序列。

```
let successCount = Observable
        .of(success.rx.tap.map { true }, failure.rx.tap.map { false })
        .merge()
        .flatMap {
            [unowned self] performWithSuccess in
            return self.performAPICall(shouldEndWithSuccess: performWithSuccess)
        }.scan(0) { accumulator, _ in
            return accumulator + 1
        }.map { "\($0)" }
    
    successCount.bindTo(self.successCount.rx.text)
        .disposed(by: disposeBag)
    
    successCount.subscribe(
        onDisposed:{
            print("dispose")
        }
    ).disposed(by: disposeBag)
  
private func performAPICall(shouldEndWithSuccess: Bool) -> Observable<Void> {
	if shouldEndWithSuccess {
		return .just(())
	} else {
		return .error(SampleError())
	}
```

当点击`Success`的时候会增加成功次数，但是当你点击`Failure`的时候，整个可被观察序列会被释放，之后不管你怎么点`Success`都不会再增加成功次数。

当`performAPICall`返回了一个错误的事件的时候，其实和你在发送网络请求的时候也会出现。所以使用`flatMap`也会把内部的`next`和`error`事件传到主序列。

结果，主序列收到`error`事件，就终结了。。。

### 如何处理？

上面的情况假如`Success`按钮是登录按钮，那么在错误后就不能点击了，这不是我们想要的。

这里我们可以借助`Result`来传递错误信息。

其实在上一篇`Moya`里面很多地方都有使用到`Result`来传递错误。

创建一个`Result`:

```
enum Result<T>{
    case success(T)
    case failure(Swift.Error)
}
```

修改`performAPICall`返回`Result`:

```
private func performAPICall2(shouldEndWithSuccess: Bool) -> Observable<Result<Void>> {
    if shouldEndWithSuccess {
        return .just(Result.success())
    } else {
        return .just(Result.failure(SampleError()))
    }
}
```

然后分别处理成功和失败的情况:

```
successCount
    .flatMap{
        $0.filterValue()
    }
    .scan(0) { accumulator, _ in
        return accumulator + 1
    }
    .map { "\($0)" }
    .bindTo(self.successCount.rx.text)
    .disposed(by: disposeBag)

successCount
    .flatMap{
        $0.filterError()
    }
    .scan(0) { accumulator, _ in
        return accumulator + 1
    }
    .map { "\($0)" }
    .bindTo(self.failureCount.rx.text)
    .disposed(by: disposeBag)
```

这里增加了`filterValue`和`filterError`来获取我们想要的值。

如果不关心原来的错误，只处理成功，也可以增加如下方法:

```
func map<T>(transform: (Value) throws -> T) -> Result<T> {
    switch self {
    case .Success(let object):
        do {
            let nextObject = try transform(object)
            return Result<T>.Success(nextObject)
        } catch {
            return Result<T>.Failure(error)
        }
    case .Failure(let error):
        return Result<T>.Failure(error)
    }
}
```

错误接着往下传，执行逻辑，成功返回，发生错误传递错误。

### 使用RxSwiftExt

除了上面的方式，也可以使用`RxSwiftExt`提供的`materialize`操作。

它会把`Observable<T>`into`Observable<Event<T>>` , 通过下面两个方法分别获取值和错误:

- elements() which returns Observable
- errors() which returns Observable

```
let result = Observable
            .of(success.rx.tap.map { true }, failure.rx.tap.map { false })
            .merge()
            .flatMap { [unowned self] performWithSuccess in
                return self.performAPICall(shouldEndWithSuccess: performWithSuccess)
                    .materialize()
    }.share()  //share 
    
    result.elements()
        .scan(0) { accumulator, _ in
            return accumulator + 1
        }.map { "\($0)" }
        .bindTo(successCount.rx.text)
        .disposed(by: disposeBag)
    
    result.errors()
        .scan(0) { accumulator, _ in
            return accumulator + 1
        }.map { "\($0)" }
        .bindTo(failureCount.rx.text)
        .disposed(by: disposeBag)
    
    result.subscribe(
        onDisposed:{
            print("dispose")
        }
    ).disposed(by: disposeBag)
```

和上次一样的把元素和错误一起包裹了一下，往下传递。

本文相关代码:

[RxSwiftResult](https://github.com/AloneMonkey/RxSwiftStudy)