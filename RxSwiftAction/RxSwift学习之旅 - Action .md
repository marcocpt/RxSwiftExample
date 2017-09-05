# RxSwift学习之旅 - Action

原文链接：http://www.alonemonkey.com/2017/04/08/rxswift-part-fourteen/

### 简介

Action是observable的一个抽象库，它定义了一个动作，传入输入的事件，然后对事件进行处理，返回处理结果。它有如下特点:

- 只有`enabled`的时候才会执行，可以传入`enabledIf`参数
- 同时只能执行一个，下次`input`必须等上次的`action`执行完
- 可以分别处理错误和next

### 创建Action

`Action`被定义为一个类`Action<Input, Element>`,`Input`是输入的元素，`Element`是`Action`处理完之后返回的元素。

一个简单的例子，没有输入也没有输出如下:

```
let buttonAction: Action<Void, Void> = Action {
    print("Doing some work")
    return Observable.empty()
}
```

或者传入用户名密码，返回登录结果:

```
let loginAction: Action<(String,String), Bool> = Action{
    (username, password) in
    print("\(username) \(password)")
    return Observable.just(true)
}
```

### 连接Button

`buttonAction`怎么使用，你可以把它和`button`的点击绑定起来:

```
button.rx.action = buttonAction
```

每次点击按钮`Action`都会执行，如果上一次的点击`Action`没有完成的话，这个的点击将会无效。

设置为`nil`去取消绑定

```
button.rx.action = nil
```

### 用户登录

我们可以把输入的账号密码绑定到上面的`loginAction`：

```
let usernameAndPassword = Observable.combineLatest(username.rx.text.orEmpty, password.rx.text.orEmpty)
        
login.rx.tap.asObservable()
    .withLatestFrom(usernameAndPassword)
    .bindTo(loginAction.inputs)
    .disposed(by: disposeBag)

loginAction.elements
    .filter{ $0 }
    .subscribe(
        onNext:{
            _ in
            print("login ok!")
        }
    )
    .disposed(by: disposeBag)

loginAction.errors
    .subscribe(
        onError:{
            error in
            print("error")
        }
    )
    .disposed(by: disposeBag)
```

输入的账号密码绑定到`loginAction.inputs`，然后订阅`loginAction`的结果。

### cell点击

可以给每个`UITableViewCell`里面的button去绑定一个`Action`：

```
let items = Observable.just(
            (0...20).map{ "\($0)" }
        )
        
items.bindTo(tableview.rx.items(cellIdentifier: "Cell", cellType: UITableViewCell.self)){
    (row, elememt, cell) in
    
    let title = cell.viewWithTag(100) as! UILabel
    
    title.text = elememt
    
    var button = cell.viewWithTag(101) as! UIButton
    
    button.rx.action = CocoaAction {
        print("to do something \(elememt)")
        return .empty()
    }
    
}.disposed(by: disposeBag)
```

### execute

除了绑定输入以外，还可以主动去执行`Action`：

```
loginAction.execute(("admin","password"))
    .subscribe{
        print($0)
    }
    .disposed(by: disposeBag)
```

通过`execute`传入账号密码，然后执行`Action`并订阅结果。

### enabledIf

只有当条件满足的时候`Action`才会执行：

```
let usernameCount = username.rx.text
            .orEmpty
            .asObservable()
            .map{
                $0.characters.count > 6
            }
        
let validateUsername:Action<String, Bool> = Action(enabledIf: usernameCount, workFactory: { input in
    print("username validating.....")
    return Observable.just(true)
})

username.rx.controlEvent(.editingDidEnd)
    .subscribe(
        onNext:{
            [unowned self] _ in
            validateUsername.execute(self.username.text ?? "")
        }
    )
    .disposed(by: disposeBag)
```

### UIAlertAction

`UIAlert`的`Action`绑定:

```
validateUsername.elements
    .observeOn(MainScheduler.instance)
    .subscribe{
        [unowned self] _ in
        print("username validate ok")
        let alertController = UIAlertController(title: "validate", message: "username validate is ok!", preferredStyle: .alert)
        var ok = UIAlertAction.Action("OK", style: .default)
        ok.rx.action = CocoaAction {
            print("Alert's OK button was pressed")
            return .empty()
        }
        alertController.addAction(ok)
        self.present(alertController, animated: true, completion: nil)
    }
    .disposed(by: disposeBag)
```

### 总结

`Action`可以用来定一个动作触发后的一个行为，也可以绑定多个动态到同一个`Action`，和`MVVM`结合的时候变得尤为合适。

代码见github:

[RxSwiftAction](https://github.com/AloneMonkey/RxSwiftStudy)