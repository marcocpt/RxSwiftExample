# RxSwift学习之旅 - UITableView操作

原文链接：http://www.alonemonkey.com/2017/03/29/rxswift-part-seven/

### 正常开发

在正常开发中要使用`UITableView`的话，需要设置`dataSource`和`delegate`，然后实现对应的协议方法。

```
tableView.dataSource = self
tableView.delegate = self


func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    
}

func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
}
```

### 简单的例子

来个简单的例子看看`Rx`中对`UITableView`是怎么处理的。

老套路，新建项目，引入`pod`，放个`UITableView`和`UITableViewCell`。

然后初始化一些数据使用`Rx`绑定到`UITableView`。

```
let items = Observable.just(
            (0...20).map{ "\($0)" }
        )

//使用数据初始化cell   
items
    .bindTo(tableview.rx.items(cellIdentifier: "Cell", cellType: UITableViewCell.self)){
        (row, elememt, cell) in
        cell.textLabel?.text = "\(elememt) @row \(row)"
    }.disposed(by: disposeBag)

//cell的点击事件
tableview.rx
    .modelSelected(String.self)
    .subscribe(
        onNext:{
            value in
            print("click \(value)")
        }
    )
    .disposed(by: disposeBag)
```

通过简短的几行代码，就把通过设置`dataSource`和`delegate`的事来做了。

例子官方都有，下面来看看它的原理是什么？

### 原理解析

```
items
    .bindTo(tableview.rx.items(cellIdentifier: "Cell", cellType: UITableViewCell.self)){
        (row, elememt, cell) in
        cell.textLabel?.text = "\(elememt) @row \(row)"
    }.disposed(by: disposeBag)
```

这段代码，简单来说，是在里面创建了一个`dataSource`的代理对象，然后代理对象的方法会使用传入的`items`以及`cell`设置。

```
override func _tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return itemModels?.count ?? 0
}

override func _tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return cellFactory(tableView, indexPath.item, itemModels![indexPath.row])
}
```

这里调用的`itemModels`就是传入的`items`, 调用的`cellFactory`就是传入的:

```
{ (tv, i, item) in
    let indexPath = IndexPath(item: i, section: 0)
    let cell = tv.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! Cell
    configureCell(i, item, cell)
    return cell
}
```

而这个`configureCell`就是最开始的:

```
{
    (row, elememt, cell) in
    cell.textLabel?.text = "\(elememt) @row \(row)"
}
```

`modelSelected`也是`delegate`的`tableView:didSelectRowAtIndexPath:`包装了下:

```
public var itemSelected: ControlEvent<IndexPath> {
    let source = self.delegate.methodInvoked(#selector(UITableViewDelegate.tableView(_:didSelectRowAt:)))
        .map { a in
            return try castOrThrow(IndexPath.self, a[1])
        }

    return ControlEvent(events: source)
}
```

大家还是自己看看源码理一下吧~~ 

### RxDataSource

如果要显示多个`Section`的`tableview`的话，可以借助`RxDataSource`帮我们完成。

新建一个项目，pod导入

```
use_frameworks!

target 'RxSwiftTableViewSection' do
	
pod 'RxSwift'
pod 'RxCocoa'
pod 'RxDataSources'

end
```

这里要额外引入`RxDataSources`。

首先创建一个`dataSource`对象:

```
let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String, Double>>()
```

然后创建自定义的数据:

```
let items = Observable.just([
    SectionModel(model: "First", items:[
            1.0,
            2.0,
            3.0
        ]),
    SectionModel(model: "Second", items:[
        1.0,
        2.0,
        3.0
        ]),
    SectionModel(model: "Third", items:[
        1.0,
        2.0,
        3.0
        ])
    ])
```

配置`cell`:

```
dataSource.configureCell = {
        (_, tv, indexPath, element) in
        let cell = tv.dequeueReusableCell(withIdentifier: "Cell")!
        cell.textLabel?.text = "\(element) @ row \(indexPath.row)"
        return cell
    }
```

设置`section`的`title`:

```
dataSource.titleForHeaderInSection = { dataSource, sectionIndex in
    return dataSource[sectionIndex].model
}
```

把数据绑定到`dataSource`:

```
items
    .bindTo(tableview.rx.items(dataSource: dataSource))
    .disposed(by: disposeBag)
```

点击事件:

```
tableview.rx
    .itemSelected
    .map { indexPath in
        return (indexPath, dataSource[indexPath])
    }
    .subscribe(onNext: { indexPath, model in
        print("Tapped `\(model)` @ \(indexPath)")
    })
    .disposed(by: disposeBag)
```

虽然`RxDataSource`内部有一个代理对象，但是我们仍然可以设置`delegate`。

```
tableview.rx
            .setDelegate(self)
            .disposed(by: disposeBag)
```

然后实现`delegate`方法:

```
extension ViewController : UITableViewDelegate{
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
}
```

这里和上面不同的是，我们主动创建了一个`dataSource`传了进去。

### Proxy

上面我们提到了代理对象，这个代理对象到底是什么？

我们来看看源码中的解释:

[![image](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490714597458.png)](http://7xtdl4.com1.z0.glb.clouddn.com/script_1490714597458.png)

它就相当与一个中间拦截器，把原始的代码对象的方法转成一个个可被观察的序列发射出去，然后再转发给我们自定义的`delegate`。所以它既不影响我们自己设置的`delegate`，同时还可以以`Rx`的方式去处理这些事件。

本文的例子都是以为官方为例，后面会加入通过网络请求获取`Model`等操作。

[RxSwiftTableView](https://github.com/AloneMonkey/RxSwiftStudy)