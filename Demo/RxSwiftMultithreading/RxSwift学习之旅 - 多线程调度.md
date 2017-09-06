# RxSwift学习之旅 - 多线程调度

原文链接：http://www.alonemonkey.com/2017/04/06/rxswift-part-thirteen/

### 介绍

在前面我们基本都是在讲如何将事件转成序列，然后去驱动数据，很少考虑到当前在什么线程。

如果某些操作是耗时的、耗内存的是不应该在主线程进行，这样会阻塞主线程，导致界面卡顿等等。

所以我们要在不同的线程去执行不同的操作。

### 调度器

当`Rx`进行一些操作时，如果不去主动切换线程，那么它将一直在同一个线程进行。

但是调度器并不等同于线程，准确的说它是一个处理发生的上下文，这个上下文可以是一个线程也是是一个调度队列，甚至`OperationQueueScheduler`里面使用的`NSOperation`。
你可以在同一线程创建多个调度器，或者在不同线程使用同一个调度器，虽然有点奇怪，但是确定可以。

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491484089713.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491484089713.png)

有两种类型的调度器，串行调度器和并行调度器。

下面有几种不同的内建的调度器:

- 当前线程调度器(CurrentThreadScheduler)(串行调度器)

当前线程的调度，也是默认的调度器

- 主调度器(MainScheduler)(串行调度器)

主线程的调度

- 串行调度队列调度器(SerialDispatchQueueScheduler)(串行调度)

特殊队列调度`dispatch_queue_t`

- 并行调度队列调度器(ConcurrentDispatchQueueScheduler)(并发调度)

特殊队列调度`dispatch_queue_t`

- 操作队列调度器(OperationQueueScheduler)(并发调度)

特殊队列调度`NSOperationQueue`，适合在后台处理大块的工作。

传一个并行队列给串行调度器，会把它转化成串行队列。传一个串行队列给并行调度器，也不会引起任何问题，但是还是要避免这么做。

### subscribeOn() & observeOn()

#### SubscribeOn

指定Observable自身在哪个调度器上执行

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491488110688.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491488110688.png)

#### ObserveOn

指定一个观察者在哪个调度器上观察这个Observable

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491488168714.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491488168714.png)

- `SubscribeOn`的调用切换之前的线程。
- `ObserveOn`的调用切换之后的线程。
- `ObserveOn`之后，不可再调用`SubscribeOn`切换之后的线程。

再来看下两者的组合使用:

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491488363703.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491488363703.png)

### Example

来看一个简单的例子，使用`RxAlamofire`从`github`搜索他人的项目，然后使用`ObjectMapper`解析json，最后展示到界面。由于涉及到网络以及解析，还有UI操作所以需求切换线程。

老套路，创建项目，导入`pod`:

```
use_frameworks!

target 'RxSwiftMultithreading' do

pod 'RxAlamofire/RxCocoa'
pod 'ObjectMapper'

end
```

### UI

界面还是一个`UITableView`和`UISearchBar`。

然后获取搜索的输入:

```
var rx_searchBarText: Observable<String> {
    return searchbar
        .rx.text
        .orEmpty
        .filter { $0.characters.count > 0 } // notice the filter new line
        .throttle(0.5, scheduler: MainScheduler.instance)
        .distinctUntilChanged()
}
```

### 网络和解析

创建`Model`类:

```
class Repository: Mappable {
    var identifier: Int!
    var language: String!
    var url: String!
    var name: String!
    
    required init?(map: Map) { }
    
    func mapping(map: Map) {
        identifier <- map["id"]
        language <- map["language"]
        url <- map["url"]
        name <- map["name"]
    }
}
```

然后发起网络请求，正常的写法那就是这样:

```
private func fetchRepositories() -> Driver<[Repository]> {
    return repositoryName
        .flatMapLatest { text in
            return RxAlamofire
                .requestJSON(.GET, "https://api.github.com/users/\(text)/repos")
                .debug()
                .catchError { error in
                    return Observable.never()
                }
        }
        .map { (response, json) -> [Repository] in
            if let repos = Mapper<Repository>().mapArray(json) {
                return repos
            } else {
                return []
            }
        }
        .asDriver(onErrorJustReturn: [])
}
```

把输入的文字转成网络请求序列，然后对请求的结果进行`map`转成`Repository`数组，最后返回。这里使用了`Driver`保证回到主线程，并不抛出错误。

然后在`ViewController`里面订阅结果：

```
searchViewModel
    .rx_repositories
    .drive(tableview.rx.items(cellIdentifier: "Cell", cellType: UITableViewCell.self)) { (row, repository, cell) in
        cell.textLabel?.text = repository.name
    }
    .disposed(by: disposeBag)

searchViewModel
    .rx_repositories
    .drive(
        onNext: {
            repositories in
            if repositories.count == 0 {
                let alert = UIAlertController(title: "sorry!", message: "No repositories for this user.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                if self.navigationController?.visibleViewController?.isMember(of: UIAlertController.self) != true {
                    self.present(alert, animated: true, completion: nil)
                }
            }

        }
    )
    .disposed(by: disposeBag)
```

### 多线程优化

我们要确保网络请求和json解析在后台线程运行，所以使用`observeOn`主动切换线程，如果还要在之前或者之前才操作UI的话，也要切换线程如下:

```
fileprivate func fetchRepositories() -> Driver<[Repository]> {
    return repositoryName
        .subscribeOn(MainScheduler.instance) // Make sure we are on MainScheduler
        .do(onNext: { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        })
        .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        .flatMapLatest { text in // .background thread, network request
            return RxAlamofire
                .requestJSON(.get, "https://api.github.com/users/\(text)/repos")
                .debug()
                .catchError { error in
                    return Observable.never()
            }
        }
        .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        .map { (response, json) -> [Repository] in // again back to .background, map objects
            if let repos = Mapper<Repository>().mapArray(JSONObject: json) {
                return repos
            } else {
                return []
            }
        }
        .observeOn(MainScheduler.instance) // switch to MainScheduler, UI updates
        .do(onNext: { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        })
        .asDriver(onErrorJustReturn: []) // This also makes sure that we are on MainScheduler
}
```

### 总结

在编写代码的时候要能意识到当前是在哪个线程进行的操作，并且把一些耗时操作放到后台，UI更新操作放到主线程。

代码见github:

[RxSwiftMultithreading](https://github.com/AloneMonkey/RxSwiftStudy)