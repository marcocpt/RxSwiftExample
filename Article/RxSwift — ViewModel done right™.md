# RxSwift — ViewModel done right**™**

原文链接：https://medium.com/smoke-swift-every-day/rxswift-viewmodel-done-right-532c1a6ede2f

The blueprint you’ve been looking for.

你一直在寻找的蓝图

![img](https://cdn-images-1.medium.com/max/800/1*rhT1D8BwGnFmvpwcopUF4w.jpeg)

**Prerequisite:**

**Action** is a great and small module used to abstract the concept of… an action in RxSwift. [Check it out, and use it everywhere it fits](https://github.com/RxSwiftCommunity/Action)

**Action**是一个伟大而小巧的模块，在RxSwift，它用来抽象action的概念。核对并在任何适用的地方使用它。

------

**NB**: goes hand-in-hand with [ViewController done right](https://medium.com/@smokeswifteveryday/rxswift-viewcontroller-done-right-d2e557e5327) and [Coordinator pattern done right](](https://medium.com/smoke-swift-every-day/rxswift-coordinator-pattern-done-right-c8f123fdf2b2)); they are part of the same whole.

**注意**：同 [ViewController done right](https://medium.com/@smokeswifteveryday/rxswift-viewcontroller-done-right-d2e557e5327) 和 [Coordinator pattern done right](](https://medium.com/smoke-swift-every-day/rxswift-coordinator-pattern-done-right-c8f123fdf2b2))携手共进吧，它们是这个系列的一部分。

------

#### In a nutshell 简而言之

There are a lot of different ways one might structure a ViewModel, the same way one might structure an investment portfolio; **there is no “best” way but there definitely are “better” ways**. Let’s focus on what seemed to be the safest and most polyvalent option so far.

构建ViewModel有许多不同的方式，同一种方式也会有很多组合；**没有最好只有更好**。我们现在关注的是什么似乎是最安全和最多元的选择。

Some of the rules/patterns presented here might either seem weird or repetitive or overkill at first glance; bear in mind they:

这里提出的一些规则/范式可能看起来很奇怪或重复或者过度凶猛; 记住他们：

1. **provide a consistent structure and API** across ViewModels which you can confidently rely on today and 2 months from now

   在ViewModels中**提供一致的结构和API**，你就可以在今天与两个月后都自信的依赖它

2. **are insurance against your future dumb self** poking around the code trying to agile-esquely rush a new feature and smearing the code base in the process (it will of course never be refactored *even though ***you knew and said*** it was just a “quick-and-dirty” hotfix that would be reintegrated in the blablabla*)

   ​

3. **are of tremendous help in bringing existing and future colleagues up to speed **on MVVM and RxSwift as well as enabling them to review your code more efficiently

#### What should never be in a ViewModel

Whenever you make an exception to these, think long and hard before doing so.

1. A ViewModel should **NEVER** `import UIKit`, though extremely rare exceptions can be made when working with `UIImage` or another UI Type. In this case, then restrict to the bare minimum such as `import UIKit.UIImage`

   ViewModel不应该使用`import UIKit`，即使在使用`UIImage`或其他UI类型时极少能够做到。在这种情况下，应该最小限度的导入，如：`import UIKit.UIImage`

2. A ViewModel should never implement a `DisposeBag`, except for subscriptions that should be bound to the ViewModel's lifecycle (if any)

   ViewModel不应该执行`DisposeBag`，除了绑定到ViewModel生命周期的订阅（如果有的话）

3. Only use `Variables` where absolutely necessary: it's often only about re-writing a smarter `.scan`

   在绝对必要的场合只使用`Variables`:它常常代表着重写一个更简洁的`.scan`

*Caveat: let’s be honest, your ViewModel will almost always have life cycles if you are doing more than the latest FartApp. Points 3 is more of a reminder to always hold back on creating `Variables`, the use cases of which are almost always tied to point 2*.

警惕：老实说，如果你做的不只是最新的FartApp，你的ViewModel将几乎总是保持生命周期。 点3更多的是提醒人们总是坚持创建`Variables`，这里的使用情况几乎总是与点2相关。

#### Recipe for a robust ViewModel 健壮的ViewModel的秘诀

A ViewModel has only one mission: to transform inputs received from either dependency injection or its ViewController and expose outputs for its ViewController to bind to.

ViewModel只有一个任务：转换从依赖注入或其ViewController接收的输入，并暴露输出给它的ViewController来进行绑定。

Let’s take a look at the basic structure and break it down from top to bottom:

让我们从上到下来看下基本结构：

```swift
import RxSwift
import Action

protocol MyViewModelInputsType {
    // Inputs headers
}

protocol MyViewModelOutputsType {
    // Outputs headers
}

protocol MyViewModelActionsType {
    // Actions headers
}

protocol MyViewModelType: class {
    var inputs: MyViewModelInputsType { get }
    var outputs: MyViewModelOutputsType { get }
    var actions: MyViewModelActionsType { get }
}

final class MyViewModel: MyViewModelType {
    
    var inputs: MyViewModelInputsType { return self }
    var outputs: MyViewModelOutputsType { return self }
    var actions: MyViewModelActionsType { return self }
    
    // Setup
    private let myViewModelService: MyViewModelServiceType
    private let coordinator: SceneCoordinatorType
  
    // Inputs
  
    // Outputs
  
    // ViewModel Life Cycle
    
  
    init(service: MyViewModelServiceType, coordinator: SceneCoordinatorType) {
        // Setup
        self.myViewModelService = service
        self.coordinator = coordinator

        // Inputs
    
        // Outputs
      
        // ViewModel Life Cycle
    
    }

    // Actions
  
}

extension MyViewModel: MyViewModelInputsType, MyViewModelOutputsType, MyViewModelActionsType { }
```



The top 3 protocols define the purpose of the ViewModel. They follow simple rules:

最上面的3个协议定义了ViewModel的功能。它们遵循以下规则：

- **Inputs always are of type **`PublishSubject<T>`: somebody needs to push stuff with `.onNext` to the ViewModel which means inputs must be observers (duh). Sometimes, because you are smart and use `Action` , they might be of type `InputSubject<T>` which is basically the same except the latter cannot error out or complete

  Inputs总是使用 `PublishSubject<T>`类型：有人需要用`.onNext`将东西推送到ViewModel，这意味着输入必须是observers（duh）。 有时，因为你机智的使用了Action，它们可能是`InputSubject<T>`类型，但它们基本上是一样的，除了后者不能输出error或complete

- **Outputs always are of type **`Observable<T>`: somebody will observe the ViewModel (otherwise, well you don’t need one in the first place) and the only thing they need is a read-only stream to look at in order to react accordingly

  Outputs总是使用`Observable<T>`：有人会观察ViewModel（或者说，well you don’t need one in the first place），并且他们唯一需要的是只读流，以便相应地进行响应

- **Actions always are of type **`Action<T, U>` or `CocoaAction` (which is just a typealias for `Action<Void, Void>`): you don’t really have a choice though, just don’t put anything else in there that’s not from the `Action` module

  Actions总是`Action<T, U>` 或 `CocoaAction`（它是 `Action<Void, Void>`的别名） 类型：

The `MyViewModelType` protocol simply enforces the need for the same three variables to be created every time, which basically are your API to the ViewModel.

These variables are implemented as computed and return `self` which is why down at the bottom the ViewModel needs to conform to their protocol specs. They are all the way down just to visually de-clutter the code.

Now that the ViewModel skeleton is in place, let’s get to the meat:

1. **Everything happens in the **`**init**`**: **nothing gets initialized outside of it, all bindings are set up
2. **There always is a service for your ViewModel:** it represents the “building blocks” helper `struct` that it can consume/assemble from to produce outputs *[see *[*Services done right*](https://medium.com/smoke-swift-every-day/rxswift-services-done-right-dd1646c0ecd2)*]*
3. **There (almost) always is a reference to the app **`**coordinator**`**: **when the ViewModel is bound to by a controller. You do not need a reference to it when it is bound to by a view, such as a `UICollectionViewCell`
4. **There is nothing more than actions from the **`**Action**`** module below init: **every “func” you imagine to produce output observables either sits in the service `struct` as a helper or can and should be abstracted as an action

#### **Real life example**

[Send stuff to a sending list with a database upload and present a new scene.](https://gist.github.com/Herakleis/c46018237055a98f4e20d3c4548b138d#file-viewmodel-reallifeexample-swift)

*Credits to *[*Shai Mishali*](https://medium.com/@freak4pc)* for inspiring the structure.*