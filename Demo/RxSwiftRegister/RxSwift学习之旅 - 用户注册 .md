## RxSwift学习之旅 - 用户注册
原文链接：http://www.alonemonkey.com/2017/03/27/rxswift-part-five/

### 需求

在本文开始前，我们先来理一理一个正常的注册流程中可能会有哪些需求:

- 用户名或密码是否为空
- 用户名密码是否合法
- 重复密码是否一致
- 点击注册发送网络请求
- 处理返回结果
- …….

在这里其实可以把很多处理归并到`被观察者 - 订阅者`模式，通过某种事件触发某种行为，某种行为依赖不同事件的状态，所以我们可以通过`RxSwift`很方便的去解决我们的问题。

### 界面设计

新建项目`RxSwiftRegister`，`pod`引入`RxSwift`和`RxCocoa`。先来设计一个简单的界面，界面上会有账号和密码的输入框，注册按钮，以及提示信息，然后绑定到`LoginViewController`。

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490535465031.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490535465031.png)

### 验证为空

这里需要验证用户名是不是为空，是否已经注册，密码是否为空，重复密码是否一致。

为了让逻辑与视图分离，这里我们使用`MVVM`模式，如果你还不知道`MVVM`可以自己先了解一下。

新建`LoginViewModel`文件，接受账号、密码、重复密码作为被观察者，然后对其中的`text`进行验证处理，返回一个验证的结果(暂时用Bool表示)。

文件目录:

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490539454404.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490539454404.png)

`LoginViewModel`编写如下代码:

```
class RegisterViewModel {
    let validatedUsername: Observable<Bool>
    let validatedPassword: Observable<Bool>
    let validatedPasswordRepeated: Observable<Bool>
    
    init(input:(
        username: Observable<String>,
        password: Observable<String>,
        repeatedPassword: Observable<String>,
        registerTap: Observable<Void>
        )){
        
        validatedUsername = input.username.map{
            username in
            return username == "" ? false : true
        }
        
        validatedPassword = input.password.map{
            password in
            return password == "" ? false : true
        }
        
        validatedPasswordRepeated = Observable.combineLatest(input.password, input.repeatedPassword){
            password, repeatedPassword in
            if repeatedPassword == ""{
                return false
            }
            
            if password != repeatedPassword{
                return false
            }
            
            return true
        }
    }
}
```

这里只是简单验证是否为空，后面再改进。

`RegisterViewController`代码如下:

```
class RegisterViewController: UIViewController {

    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var usernameValidation: UILabel!
    
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var passwordValidation: UILabel!
    
    @IBOutlet weak var repoatedPassword: UITextField!
    @IBOutlet weak var repeatedPasswordValidation: UILabel!
    
    @IBOutlet weak var registerIndicator: UIActivityIndicatorView!
    @IBOutlet weak var register: UIButton!
    
    let disposed = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewModel = RegisterViewModel(input:(
            username: username.rx.text.orEmpty.asObservable(),
            password: password.rx.text.orEmpty.asObservable(),
            repeatedPassword: repoatedPassword.rx.text.orEmpty.asObservable(),
            registerTap: register.rx.tap.asObservable()
        ))
        
        viewModel.validatedUsername.subscribe(
            onNext:{
                valid in
                print("username is \(valid)")
            }
        ).disposed(by: disposed)
        
        viewModel.validatedPassword.subscribe(
            onNext:{
                valid in
                print("password is \(valid)")
            }
        ).disposed(by: disposed)
        
        viewModel.validatedPasswordRepeated.subscribe(
            onNext:{
                valid in
                print("repoatedPassword is \(valid)")
            }
        ).disposed(by: disposed)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }
}
```

订阅账号、密码、重复密码是否验证成功的值打印出来，运行可以得到验证，一开始都是false，输入了后变成true。

```
username is false
password is false
repoatedPassword is false
username is false
username is true
username is true
password is false
repoatedPassword is false
password is true
repoatedPassword is false
password is true
repoatedPassword is false
repoatedPassword is false
repoatedPassword is false
repoatedPassword is false
repoatedPassword is true
```

接下来来看一些问题，当有两个订阅者去订阅用户名是否验证ok，然后在验证的时候去打印一下。

```
viewModel.validatedUsername.subscribe(
    onNext:{
        valid in
        print("username is \(valid)")
    }
).disposed(by: disposed)

viewModel.validatedUsername.subscribe(
    onNext:{
        valid in
        print("username 2 is \(valid)")
    }
).disposed(by: disposed)

-------------------------------------------

validatedUsername = input.username.map{
    username in
    print(username)
    return username == "" ? false : true
}
```

会发现，多了一个订阅者后，验证的逻辑会执行两次，这并不是我们想要的效果，当验证是一个网络请求的话，会发出两个一样的。同一个值只需要验证一次，然后告诉所有的订阅者就行了。这里需要使用到`shareReplay(1)`，保证多个订阅者共享单个订阅，并重播最新的一次`replay`。

```
validatedUsername = input.username.map{
    username in
    print(username)
    return username == "" ? false : true
}.shareReplay(1)
```

同样对密码和重复密码也只需要共享一次。

### 绑定错误到Label

上面只是通过控制台打印了验证的对或错，但是并不知道错的原因，也没有显示到`label`上，现在来实现这个效果，我们要定义个表示不同验证结果和信息的枚举。

```
enum ValidationResult {
    case ok(message: String)    //验证成功和信息
    case empty                  //输入为空
    case validating
    case failed(message: String)      //验证失败的原因
}
```

然后修改返回结果类型为`ValidationResult`:

```
enum ValidationResult {
    case ok(message: String)
    case empty
    case validating
    case failed(message: String)
}

class RegisterViewModel {
    let validatedUsername: Observable<ValidationResult>
    let validatedPassword: Observable<ValidationResult>
    let validatedPasswordRepeated: Observable<ValidationResult>
    
    init(input:(
        username: Observable<String>,
        password: Observable<String>,
        repeatedPassword: Observable<String>,
        registerTap: Observable<Void>
        )){
        
        validatedUsername = input.username.map{
            username in
            return username == "" ? .empty : .ok(message: "验证通过")
        }.shareReplay(1)
        
        validatedPassword = input.password.map{
            password in
            return password == "" ? .empty : .ok(message: "验证通过")
        }.shareReplay(1)
        
        validatedPasswordRepeated = Observable.combineLatest(input.password, input.repeatedPassword){
            password, repeatedPassword in
            if repeatedPassword == ""{
                return .empty
            }
            
            if password != repeatedPassword{
                return .failed(message:"两次输入的密码不一致")
            }
            
            return .ok(message: "验证通过")
        }.shareReplay(1)
    }
}
```

然后绑定错误到`label`，为了让`ValidationResult`能绑定到`label`，需要给出不同结果的文字颜色和文字信息，这时需要给`ValidationResult`扩展一下。

```
extension ValidationResult: CustomStringConvertible {
    var description: String {
        switch self {
        case let .ok(message):
            return message
        case .empty:
            return ""
        case .validating:
            return "validating ..."
        case let .failed(message):
            return message
        }
    }
}

struct ValidationColors {
    static let okColor = UIColor(red: 138.0 / 255.0, green: 221.0 / 255.0, blue: 109.0 / 255.0, alpha: 1.0)
    static let errorColor = UIColor.red
}

extension ValidationResult {
    var textColor: UIColor {
        switch self {
        case .ok:
            return ValidationColors.okColor
        case .empty:
            return UIColor.black
        case .validating:
            return UIColor.black
        case .failed:
            return ValidationColors.errorColor
        }
    }
}
```

同样为了使`label`能够根据对应的信息和颜色更新，需要提供:

```
extension Reactive where Base: UILabel {
    var validationResult: UIBindingObserver<Base, ValidationResult> {
        return UIBindingObserver(UIElement: base) { label, result in
            label.textColor = result.textColor
            label.text = result.description
        }
    }
}
```

然后绑定:

```
viewModel.validatedUsername
    .bindTo(usernameValidation.rx.validationResult)
    .disposed(by: disposeBag)
        
viewModel.validatedPassword
    .bindTo(passwordValidation.rx.validationResult)
    .disposed(by: disposeBag)

viewModel.validatedPasswordRepeated
    .bindTo(repeatedPasswordValidation.rx.validationResult)
    .disposed(by: disposeBag)
```

效果如下:

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490545656582.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490545656582.png)

### 注册按钮状态

接下来需要根据上面的验证结果来确定注册按钮的可点击状态，只有当账号、密码、重复密码都验证通过之后才会变成可点击的状态。

+++++++++++++++++++++++++++++++++++++

**需要首先增加ValidationResult扩展isValid属性**

```swift
extension ValidationResult {
  var isValid: Bool {
    switch self {
    case .ok:
      return true
    case .empty, .failed, .validating:
      return false
    }
  }
}
```

+++++++++++++++++++++++++++++++++++++

```
let registerEnabled: Observable<Bool>

registerEnabled = Observable.combineLatest(validatedUsername, validatedPassword, validatedPasswordRepeated){
    username, password, repeatedPassword in
    username.isValid &&
    password.isValid &&
    repeatedPassword.isValid
    }
    .distinctUntilChanged()
    .shareReplay(1)

viewModel.registerEnabled.subscribe(
    onNext:{
        [weak self] valid in
        guard let `self` = self else{
            return
        }
        self.register.isEnabled = valid
        self.register.alpha = valid ? 1.0 : 0.5
    }
).disposed(by: disposeBag)
```

这里有几点：

- 只需要共享一次，使用`shareReplay`
- 不用每次改变都发射给订阅者，只有当发生改变时再发射，使用`distinctUntilChanged`
- 捕获`self`的弱引用，然后再里面转成强引用

### 网络验证

前面只是在本地做了一个简单的验证，现在想要验证输入的账号是否能注册，就需要发送网络请求去验证。

这里参考官方给出的例子，通过url判断是否有效:

```
class GitHubAPI{
    let URLSession: URLSession
    
    static let sharedAPI = GitHubAPI(
        URLSession: Foundation.URLSession.shared
    )
    
    init(URLSession: URLSession){
        self.URLSession = URLSession
    }
    
    func usernameAvailable(_ username: String) -> Observable<Bool>{
        let url = URL(string: "https://github.com/\(username.URLEscaped)")!
        let request = URLRequest(url: url)
        return self.URLSession.rx.response(request: request)
            .map{
                (response, _) in
                return response.statusCode == 404
            }
            .catchErrorJustReturn(false)
    }
}
```

如果url存在就认为已注册，否则就是没有。

那么用户名验证可以改为：

```
//flatMapLatest 如果有新的值发射出来，则会取消原来发出的网络请求
//flatMap 则不会
validatedUsername = input.username
    .flatMapLatest{
    username -> Observable<ValidationResult> in
    //是否为空
    if username.characters.count == 0{
        return Observable.just(.empty)
    }
    
    //是否是数字和字母
    if username.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil {
        return  Observable.just(.failed(message: "Username can only contain numbers or digits"))
    }
    
    let loadingValue = ValidationResult.validating
    
    return API.usernameAvailable(username)
            .map{
                available in
                if available {
                    return .ok(message: "Username available")
                }
                else {
                    return .failed(message: "Username already taken")
                }
            }
            .startWith(loadingValue)  //开始发射一个正在验证的值
            .observeOn(MainScheduler.instance)   //将监听事件绑定到主线程
            .catchErrorJustReturn(.failed(message: "Error contacting server"))
}.shareReplay(1)
```

同样把密码和重复密码也改下。

### 注册请求

这里和官方例子一样，模拟下注册过程。

```
func register(_ username: String, password: String) -> Observable<Bool>{
    let registerResult = arc4random() % 5 == 0 ? false : true
    return Observable.just(registerResult)
            .delay(1.0, scheduler: MainScheduler.instance)  //延迟一秒
}
```

然后绑定注册的点击事件，执行注册请求。

```
//合并注册点击和账号密码序列，每次注册点击，从第二个序列取最新的值
let usernameAndPassword = Observable.combineLatest(input.username, input.password) { ($0, $1) }
        
registered = input.registerTap.withLatestFrom(usernameAndPassword)
    .flatMapLatest{
        (username, password) in
        return API.register(username, password: password)
                .observeOn(MainScheduler.instance)
                .catchErrorJustReturn(false)
                .trackActivity(registering)
    }.shareReplay(1)
```

`trackActivity`是官方例子里面的，用于监控序列的计算中和结束。

到此这个例子就结束了，如图:

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490618590053.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490618590053.png)

### 项目优化

有几点交互需要优化一下:

- 点击背景收起键盘
- 点击键盘的`Next`调到下一个`UITextField`
- 点击`Go`触发注册流程

```
//点击背景收起键盘
let tapBackground = UITapGestureRecognizer()
tapBackground.rx.event
    .subscribe(onNext: { [unowned self] _ in
        self.view.endEditing(true)
    })
    .disposed(by: disposeBag)
view.addGestureRecognizer(tapBackground)
```

```
username.rx.controlEvent(.editingDidEnd)
    .subscribe{
        [unowned self] _ in
        self.password.becomeFirstResponder()
    }
    .disposed(by: disposeBag)

password.rx.controlEvent(.editingDidEnd)
    .subscribe{
        [unowned self] _ in
        self.repoatedPassword.becomeFirstResponder()
    }
    .disposed(by: disposeBag)

repoatedPassword.rx.controlEvent(.editingDidEndOnExit)
    .bindTo(viewModel.registerTap)
    .disposed(by: disposeBag)
```

完整源码见Github

[RxSwiftRegister](https://github.com/AloneMonkey/RxSwiftStudy)