# RxSwift学习之旅 - Moya + ObjectMapper                                    

原文链接：http://www.alonemonkey.com/2017/03/30/rxswift-part-eight/

### 什么是Moya？

`Moya`是一个基于`Alamofire`封装的一个抽象层，让我们更加关注自己的业务处理。

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490776469921.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490776469921.png)

同时还可以通过中间件的方式拦截和修改请求，mock数据等等。

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490776597007.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490776597007.png)

### 使用Moya

来看一个简单的例子吧，在`Moya`中要发送一个网络请求，需要定义个枚举并实现`TargetType`协议中的方法。如下:

```
//根据不同的枚举类型来配置不同的参数
enum User{
    case list(Int,Int)
}

extension User : TargetType{
    var baseURL : URL{
        return URL(string: "http://www.alonemonkey.com")!
    }
    
    var path: String{
        switch self {
        case .list:
            return "userlist"
        }
    }
    
    var method: Moya.Method{
        switch self {
        case .list:
            return .get
        }
    }
    
    var parameters: [String: Any]?{
        switch self{
        case .list(let start, let size):
            return ["start": start, "size": size]
        }
    }
    
    var parameterEncoding: ParameterEncoding{
        return URLEncoding.default
    }
    
    var task: Task{
        return .request
    }
    
    var sampleData: Data{
        switch self {
        case .list(_, _):
            if let path = Bundle.main.path(forResource: "UserList", ofType: "json") {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                    return data
                } catch let error {
                    print(error.localizedDescription)
                }
            }
            return Data()
        }
    }
}
```

上面参数的函数大家看名字也就知道了。

然后需要一个`MoyaProvider`对象，这里使用`RxMoyaProvider`来进行响应式编程。

```
let UserProvider = RxMoyaProvider<User>(stubClosure: MoyaProvider.immediatelyStub)
```

`stubClosure: MoyaProvider.immediatelyStub`表示使用本地mock数据。

然后使用生成的`RxMoyaProvider`对象发起请求。

```
let disposeBag = DisposeBag()
UserProvider
    .request(.list(0, 10))
    .mapJSON()
    .subscribe{
        print($0)
    }
    .disposed(by: disposeBag)
```

运行就可以在控制台打印出本地`mock`的`json`数据了。

### ObjectMapper

获取了`json`数据后，需要把数据解析成对应的对象，这里我们使用`ObjectMapper`。已有`Moya-ObjectMapper`, 可以满足我们的需求。

安装

```
pod 'Moya-ObjectMapper/RxSwift'
```

首先定义`Model`:

```
struct User : Mappable{
    var name: String!
    var age: Int!
    
    init?(map: Map) {}
    
    mutating func mapping(map: Map){
        name <- map["name"]
        age  <- map["age"]
    }
}
```

然后在请求的时候可以指定`Model`去解析数据:

```
UserProvider
    .request(.list(0, 10))
    .mapArray(User.self)
    .subscribe{
        event in
        switch event{
        case .next(let users):
            for user in users{
                print("\(user.name)  \(user.age)")
            }
        default:
            break
        }
    }
    .disposed(by: disposeBag)
```

### 固定格式

上面都是直接就返回了一个`User`的数组，但是实际开发中，都会返回一个固定的格式，表示状态、消息、结果，像下面这种:

```
{
    code: 300,
    message: "xxxxxx",
    result: xxxx     //这里才是我们需要的东西
}
```

对于这情况怎么处理呢？

首先看一下`mapArray`是怎么处理的把:

```
public func mapArray<T: BaseMappable>(_ type: T.Type, context: MapContext? = nil) throws -> [T] {
	guard let array = try mapJSON() as? [[String : Any]], let objects = Mapper<T>(context: context).mapArray(JSONArray: array) else {
      throw MoyaError.jsonMapping(self)
    }
    return objects
  }
```

首先调用了`mapJSON`转成`json`，然后调用`Mapper<T>(context: context).mapArray(JSONArray: array)`转成对象数组。

我们也可以写一个类似的方法，首先定义需要解析的公共部分结构。

```
struct Status : Mappable{
    var code : Int!
    var message : String?
    var result : Any?
    
    init?(map: Map) {}
    
    mutating func mapping(map: Map) {
        code    <-      map["code"]
        message <-      map["message"]
        result  <-      map["result"]
    }
}
```

然后自己写一个`mapResult`:

```
public extension Response {
    public func mapResult<T: BaseMappable>(_ type: T.Type, context: MapContext? = nil) throws -> [T] {
        
        let status = try mapObject(Status.self)
        
         guard let array = status.result as? [[String : Any]], let objects = Mapper<T>(context: context).mapArray(JSONArray: array) else {
            throw AMError.ParseResultError(status)
        }
        
        return objects
    }
}

public extension ObservableType where E == Response {
    public func mapResult<T: BaseMappable>(_ type: T.Type, context: MapContext? = nil) -> Observable<[T]> {
        return flatMap { response -> Observable<[T]> in
            return Observable.just(try response.mapResult(T.self, context: context))
        }
    }
}
```

然后就能获取到对应的结果了，如果出错了的话，也可以获取到错误信息。

```
.subscribe{
    event in
    switch event{
    case .next(let users):
        for user in users{
            print("\(user.name)  \(user.age)")
        }
    case .error(let error):
        var message = "出错了!"
        if let amerror = error as? AMError, let msg = amerror.message{
            message = msg
        }
        print(message)
    default:
        break
    }
}
```

大家想一想如果`result`返回的是单个对象的话，应该怎么写？

### 总结

`Moya`本身提供了强大的扩展能力，可以对其进行扩展，再加上`Rx`和`ObjectMapper`，我们可以对网络请求的发送、处理以及解析通过链式调用的方法来处理，写出优雅的代码。

代码见github:

[RxSwiftMoya](https://github.com/AloneMonkey/RxSwiftStudy)