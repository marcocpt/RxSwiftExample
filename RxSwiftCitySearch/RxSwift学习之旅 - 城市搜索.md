# RxSwift学习之旅 - 城市搜索

原文链接：http://www.alonemonkey.com/2017/04/05/rxswift-part-twelve/

### Demo介绍

这是一个通过`SearchBar`来搜索`tableview`内容的一个简单的例子，界面如下:

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491380143544.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1491380143544.png)

### mock数据

首先添加一个`mock`数据到`tableview`。

```
//mock数据
var shownCities = [String]() // Data source for UITableView

let allCities = ["ChangSha",
                    "HangZhou",
                    "ShangHai",
                    "BeiJing",
                    "ShenZhen",
                    "New York",
                    "London",
                    "Oslo",
                    "Warsaw",
                    "Berlin",
                    "Praga"] // Our mocked API data source

//数据源
let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String, String>>()

dataSource.configureCell = {
    (_, tv, indexPath, element) in
    let cell = tv.dequeueReusableCell(withIdentifier: "Cell")!
    cell.textLabel?.text = "\(element)"
    return cell
}
```

### 获取输入

获取用户的搜索输入，并简单判断前缀来返回结果:

```
//获取输入
let searchResult = searchbar.rx
                        .text
                        .orEmpty
                        .flatMapLatest{
                            [unowned self] query -> Observable<[String]> in
                            print("\(query)")
                            if query.isEmpty{
                                return Observable.just([])
                            }else{
                                let results = self.allCities.filter{ $0.hasPrefix(query)}
                                return Observable.just(results)
                            }
                        }
                        .shareReplay(1)
```

### 绑定结果

绑定结果到`dataSource`:

```
searchResult
       .map{ [SectionModel(model:"",items:$0)] }
       .bindTo(tableview.rx.items(dataSource: dataSource))
       .disposed(by: disposeBag)
```

现在已经能使用搜索了。

### 优化

运行后发现每次输入文字，都会发送请求，可以使用`debounce`指定一段时间后不再有输入再发送请求，同时使用`distinctUntilChanged`来过滤和上次一样的输入。

```
let searchResult = searchbar.rx
            .text
            .orEmpty
            .debounce(0.5, scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .flatMapLatest{
                [unowned self] query -> Observable<[String]> in
                print("\(query)")
                if query.isEmpty{
                    return Observable.just([])
                }else{
                    let results = self.allCities.filter{ $0.hasPrefix(query)}
                    return Observable.just(results)
                }
            }
            .shareReplay(1)
```

还可以使用`filter`直接过滤空的搜索。

```
let searchResult = searchbar.rx
                        .text
                        .orEmpty
                        .debounce(0.5, scheduler: MainScheduler.instance)
                        .distinctUntilChanged()
                        .filter{ !$0.isEmpty }
                        .flatMapLatest{
                            [unowned self] query -> Observable<[String]> in
                            print("\(query)")
                            return Observable.just(self.allCities.filter{ $0.hasPrefix(query)})
                        }
                        .shareReplay(1)
```

### 总结

这里主要用到节流来处理用户输入，大家可以结合网络实时从接口获取数据，但是要主要线程切换。

代码见github:

[RxSwiftCitySearch](https://github.com/AloneMonkey/RxSwiftStudy)

