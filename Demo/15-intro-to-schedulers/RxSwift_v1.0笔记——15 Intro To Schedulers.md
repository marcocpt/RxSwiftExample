## RxSwift_v1.0笔记——15 Intro To Schedulers

到目前为止，您已经设法使用了调度程序，但没有任何关于如何处理线程或并发的说明。 在前面的章节中，您使用了隐式使用某种并行/线程级别的方法，例如**缓冲区，延迟订阅或间隔操作**。

本章将介绍调度程序的美好之处，您将在此了解Rx抽象如何强大，为什么使用异步编程远远不如使用锁或队列那么痛苦。

```
Note:创建自定义的schedulers超出了本书的范围。RxSwift，RxCocoa提供的scheduler一般覆盖了99%的情况。始终尝试使用内建的schedulers。
```

### 什么是scheduler？ 286

概括讲，scheduler是进程发生的上下文。这个上下文可以是线程，调度队列或相似物，甚至是在 OperationQueueScheduler内部使用的 NSOperation。

下面例子很好的解释了schedulers如何使用：

![](http://upload-images.jianshu.io/upload_images/2224431-1b6f1b20481102dd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

这个图表中展示了缓存操作的概念。observable向服务器请求并接收了一些数据。这些数据被cache()函数处理，它把数据存在了某个地方。之后，数据被传递到在不同scheduler的所有的订阅者，最合适的 MainScheduler，它位于主线程顶部，用来更新UI。

#### 揭秘scheduler 286

关于scheduler的一个普遍的误解是：它们与线程相同。首先，这似乎是合乎逻辑的 - 毕竟，scheduler的工作类似于GCD调度队列。

但这不是所有的情况。如果你正在写一个自定义的scheduler，这任然不是一个推荐的方法，你应该使用同样的（very same）线程创建多个scheduler，或者在多个线程顶部创建一个scheduler。那可能很奇怪，但它会工作！

![](http://upload-images.jianshu.io/upload_images/2224431-5c1c933087781257.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/400)

记住scheduler不是线程，它们与线程没有一对一的关系。总是检查scheduler执行操作的上下文，而不是线程。后面章节你将有好的例子来帮助你理解它。

### 启动项目 287

在这个项目中，你将为macOS创建一个简单的命令行工具。为什么是命令行工具？因为你正在学习线程和并发，纯文本输出将更容易理解。

pod install 后运行app，debugger控制台应该输出如下：

```
===== Schedulers =====
00s | [D] [dog] received on Main Thread
00s | [S] [dog] received on Main Thread
Program ended with exit code: 0
```

开始前，打开Utils.swift并看看 dump() and  dumpingSubscription()的实现。

第一个方法使用[D]前缀在do(onNext :)操作内倾倒元素和当前线程的信息。第二个方法使用[S]前缀做了同样的事情，除了调用 subscribe(onNext:)外。两个方法标识了消耗的时间，因此00s代表（stand for）“0秒消耗”。

你有两种不同的方式将打印信息的副作用注入到控制台，因此你可以用 do(onNext:)链接他们，并通过用 subscribe(onNext:)订阅链接来终止链接。在下节中你将看到在schedulers之间为observablesd的链式结构切换是多么容易。

### 切换schedules 287

Rx的一个最重要的能力是能够在任意时间切换schedules，除了内部进程生成事件外，没有任何限制。

```
Note：这种限制类型的一个例子是，如果observable发出非线程安全对象，它不能被跨线程发送。在这种情况下，RxSwift将允许您切换schedulers，但您将违反底层代码的逻辑。
```

要了解调度程序的行为方式，您将创建一个简单的observable来提供一些水果。

增加以下代码到main.swift：

```
let fruit = Observable<String>.create { observer in
  observer.onNext("[apple]")
  sleep(2)
  observer.onNext("[pineapple]")
  sleep(2)
  observer.onNext("[strawberry]")
  return Disposables.create()
}
```

这个observable具有睡眠功能。虽然这不是您通常在实际应用中看到的东西，但在这种情况下，这将有助于您了解订阅和观察的工作原理。

增加下面代码订阅你已经创建的observable：

```swift
fruit
  .dump()
  .dumpingSubscription()
  .addDisposableTo(bag)
```

运行并查看控制台输出：

```
00s | [D] [dog] received on Main Thread
00s | [S] [dog] received on Main Thread
00s | [D] [apple] received on Main Thread
00s | [S] [apple] received on Main Thread
02s | [D] [pineapple] received on Main Thread
02s | [S] [pineapple] received on Main Thread
04s | [D] [strawberry] received on Main Thread
04s | [S] [strawberry] received on Main Thread
```

这就是你初始的目的，每两秒跟随一个水果。

水果在主线程生成，但最好把它移到后台线程，你需要用subscribeOn。

#### 使用subscribeOn 289

在某些情况下，您可能需要更改observables算法（computation）代码在哪个scheduler上运行，不是任何订阅操作中的代码，而是实际发出observable事件的代码。

```
Note：对于你已经创建的，自定义observable，发射事件的代码是你提供的作为Observable.create{ ... }的尾随闭包(trailing closure)的代码
```

为算法代码设置scheduler的方式是使用subscribeOn。第一感觉可能觉得这是反直觉的名字，但思考它一段时间后，就会有觉得有道理。当你想观察一个observable，你就订阅它。这个决定将在源进程发生。如果subscribeOn没有调用，RxSwift自动使用当前线程：

![](http://upload-images.jianshu.io/upload_images/2224431-d1bc0451ef9bbe44.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/500)

这个程序使用主scheduler在主线程创建事件。你使用过的 MainScheduler，它是位于主线程顶部。在主线程你想执行的所有任务必须使用这个scheduler，这就是为什么在前面的例子中，当为UI工作时使用它的原因。你将使用subscribeOn切换schedulers.

在main.swift有一个叫做 globalScheduler的预定于scheduler，它使用后台序列。这个scheduler使用全局调度序列创建，它是一个并发序列：

```swift
let globalScheduler = ConcurrentDispatchQueueScheduler(queue:
  DispatchQueue.global())
```

因此，正如类的名字建议的，由这个scheduler计算的所有任务将由全局调度队列调度和处理。

使用这个scheduler，用下面代码替换先前你创建的订阅fruits：

```swift
fruit
  .subscribeOn(globalScheduler)
  .dump()
  .dumpingSubscription()
  .addDisposableTo(bag)
```

现在在文件末尾增加以下行：

```swift
RunLoop.main.run(until: Date(timeIntervalSinceNow: 13))
```

诚然，这是一个黑客; 一旦所有操作在主线程上完成，它将杀死您的全局scheduler和observable，而上面代码将防止终端终止，它将保持终端活动13秒。

```
Note：13秒对这个例子可能太长了，但本章后续你需要这么长的时间。
```

现在你的新的scheduler就位了，运行并检查结果：

```
00s | [D] [dog] received on Main Thread
00s | [S] [dog] received on Main Thread
00s | [D] [apple] received on Anonymous Thread
00s | [S] [apple] received on Anonymous Thread
02s | [D] [pineapple] received on Anonymous Thread
02s | [S] [pineapple] received on Anonymous Thread
04s | [D] [strawberry] received on Anonymous Thread
04s | [S] [strawberry] received on Anonymous Thread
Program ended with exit code: 0
```

全局队列使用了一个没有名字的线程，因此在这种情况下 Anonymous Thread就是全局线程。

现在observable和观察者的订阅在同一个线程处理数据。

![](http://upload-images.jianshu.io/upload_images/2224431-b300928f15c0668a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

那很酷，但是如果你想改变观察者执行你操作的代码的位置你该怎么做呢？你必须使用observeOn。

#### 使用observeOn 290

观察是Rx的三个重要概念之一。它包含实体产生事件，和为这些事件的观察者。对照subscribeOn，observeOn在观察发送的位置改变scheduler。

因此，一旦结果被进入，并且Observable对所有订阅的观察者推送事件，则该运算符将确保事件在正确的scheduler中被正确地处理。

从当前的全局scheduler切换到主线程，你需要在订阅前调用observeOn。再一次，替换你的水果订阅的代码：

```swift
fruit
  .subscribeOn(globalScheduler)
  .dump()
  .observeOn(MainScheduler.instance)
  .dumpingSubscription()
  .addDisposableTo(bag)
```

运行并检查控制台输出：

```
00s | [D] [dog] received on Main Thread
00s | [S] [dog] received on Main Thread
00s | [D] [apple] received on Anonymous Thread
00s | [S] [apple] received on Main Thread
02s | [D] [pineapple] received on Anonymous Thread
02s | [S] [pineapple] received on Main Thread
04s | [D] [strawberry] received on Anonymous Thread
04s | [S] [strawberry] received on Main Thread
Program ended with exit code: 0
```

你已经实现了你想要的结果：所有的事件现在被处理在正确的线程上。主要的observable在后台线程被处理并产生事件，订阅观察者在主线程工作。

![](http://upload-images.jianshu.io/upload_images/2224431-e47be1e0b3a65177.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/600)

这是一个非常通用的样式。你必须使用后台处理来至服务器的数据，仅仅在处理最终事件和在用户界面显示数据时才切换到MainScheduler。

#### 陷阱 291

切换scheduler和线程的能力看起来很炫酷，但它也带来了一些陷阱。来看看为什么，你你将使用一个新的线程来推送事件到目标。因此你需要追踪在哪个线程上进行计算，好的解决方案是使用Thred（不是Objective-C的NSThread）。

在fruit observable之后，增加下面代码用来产生动物：

```swift
let animalsThread = Thread() {
  sleep(3)
  animal.onNext("[cat]")
  sleep(3)
  animal.onNext("[tiger]")
  sleep(3)
  animal.onNext("[fox]")
  sleep(3)
  animal.onNext("[leopard]")
}
```

命名线程以便你能够识别，接着启动它：

```swift
animalsThread.name = "Animals Thread"
animalsThread.start()
```

运行，你应该看到新的线程：

```
...
03s | [D] [cat] received on Animals Thread
03s | [S] [cat] received on Animals Thread
04s | [D] [strawberry] received on Anonymous Thread
04s | [S] [strawberry] received on Main Thread
06s | [D] [tiger] received on Animals Thread
06s | [S] [tiger] received on Animals Thread
09s | [D] [fox] received on Animals Thread
09s | [S] [fox] received on Animals Thread
12s | [D] [leopard] received on Animals Thread
12s | [S] [leopard] received on Animals Thread
```

完美——你有了创建在专用线程的动物。现在在全局线程处理结果。

用下面代码替换源订阅为动物subject：

```swift
animal
  .dump()
  .observeOn(globalScheduler)
  .dumpingSubscription()		
  .addDisposableTo(bag)
```

运行并查看结果：

```
...
03s | [D] [cat] received on Animals Thread
03s | [S] [cat] received on Anonymous Thread
04s | [D] [strawberry] received on Anonymous Thread
04s | [S] [strawberry] received on Main Thread
06s | [D] [tiger] received on Animals Thread
06s | [S] [tiger] received on Anonymous Thread
09s | [D] [fox] received on Animals Thread
09s | [S] [fox] received on Anonymous Thread
12s | [D] [leopard] received on Animals Thread
12s | [S] [leopard] received on Anonymous Thread
```

现在你正在切换线程，几乎运行到13秒的限制！

如果您想在全局队列上观察进程，但是你又想要处理主线程上的订阅怎么办？ 对于第一种情况，observeOn已经是正确的，但是对于第二种情况，必须使用subscribeOn。

替换动物订阅：

```swift
animal
  .subscribeOn(MainScheduler.instance)
  .dump()
  .observeOn(globalScheduler)
  .dumpingSubscription()
  .addDisposableTo(bag)
```

运行，你将看到以下输出：

```
03s | [D] [cat] received on Animals Thread
03s | [S] [cat] received on Anonymous Thread
04s | [D] [strawberry] received on Anonymous Thread
04s | [S] [strawberry] received on Main Thread
06s | [D] [tiger] received on Animals Thread
06s | [S] [tiger] received on Anonymous Thread
09s | [D] [fox] received on Animals Thread
09s | [S] [fox] received on Anonymous Thread
12s | [D] [leopard] received on Animals Thread
12s | [S] [leopard] received on Anonymous Thread
```

为什么计算没有发生在正确的scheduler？这是一个常见和危险的陷阱，它将Rx视为异步或多线程，默认情况下并不是这样。

Rx和general abstraction是自由线程的；当处理数据时，没有神奇的线程切换。如果没有指定，则始终在原始线程进行计算。

```
Note：任何线程切换的发生，在由编程者使用subscribeOn and observeOn发出一个明确的请求之后。
```

认为Rx在默认情况下执行一些线程处理是一个普遍落入的陷阱。 上面发生的原因是对 Subject的滥用。 原始的计算是在一个特定的线程上发生的，并且那些事件使用Thread（）{...}推送到该线程中。 由于Subject的性质，Rx无法切换原始计算schedule并移动到另一个线程，因为没有直接控制越过subject被推送的位置。

为什么水果线程能够通过？那是因为使用 Observable.create把Rx放进 Thread块内部控制（That’s because using

Observable.create puts Rx in control of what happens inside the Thread block），因此你能够更好的自定义线程处理。

这个意外的结果通常被成为"Hot and Cold" observables问题。

在上面的情况中，你正在用**hot** observable处理。在订阅期间observable没有任何副作用，但它确实有自己的上下文来生成事件，RxSwift无法控制它（即它运行自己的线程）。

与此相反（in contrast）**cold** observable在任何观察者订阅它之前不会产生任何元素。这实际上意味着它没有自己的上下文，紧跟着订阅后，它创建一些上下文并开始生成元素。

#### Hot vs. cold 294

上文简略提到了hot and cold的observables话题。hot and cold的observables的话题颇有深度并引起了很多争议，所有让我们在这里简要介绍下。这个概念可以简化为一个很简单的问题：

![](http://upload-images.jianshu.io/upload_images/2224431-ac5a1ffb2cb2d5b4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/500)

以下是一些副作用的例子：

- 启动一个请求到服务器
- 编辑本地数据库
- 写入到文件系统
- 发射火箭:]

副作用的世界是无尽的，因此你需要紧跟着订阅决定是否你的observable实例执行副作用。如果你无法确定，需要执行更多分析或更深入到挖掘你的源代码。在每个订阅上启动火箭可能不是你想要实现的...

另一个描述这个的普遍的方式是询问是否observable共享副作用。如果紧跟着订阅你不执行副作用，就代表副作用不共享。否则，副作用共享到所有订阅者。

这是一个相当普遍的规则，适用于任何ObservableType对象，如subject和相关子类型。

正如你注意到的那样，本书迄今为止我们还没有讲过hot and cold observables。 这是反应式编程中的一个常见问题，但是在Rx中，只有在上述的Thread示例或需要像测试这样更好的控件的特定情况下才会遇到这个概念。

将本节作为参考点，因此，如果您需要在hot or cold observables方面解决问题，则可以快速打开本书，并以此更新自己的观念。



### 最佳实践和内建schedulers 295

Schedulers是一个很重要的话题，因此它们为大部分通用的情况提供了一些最佳的例子。在本节中，你将快速了解串行和并发schedulers,，了解它们如何处理数据，并查看哪种类型对于特定上下文更有效。

#### 串行vs并行schedulers 295

考虑到调度程序只是一个上下文，可以是任何内容（调度队列，线程或自定义上下文），并且所有运算符转换序列都需要保留隐式保证，您需要确保使用正确的调度程序。

- 如果你正在使用一个**串行scheduler**，Rx将进行连续算法。为一个串行调度队列，scheduler将也能在其下执行它自己的优化。
- 在**并发scheduler**，Rx将试着同时运行代码，但 observeOn和subscribeOn在需要被执行的任务中将保护这个队列，并确保你的订阅代码在正确的scheduler结束。

#### MainScheduler 295

 MainScheduler位于主线程的顶部。这个scheduler被用来处理在用户界面上的改变，并执行其他高优先级的任务。作为在iOS，tvOS或macOS上开发应用程序的一般做法，不应使用此scheduler执行长时间运行的任务，因此可以避免像服务器请求或其他繁重的任务。

此外，如果你执行副作用更新UI，你必须切换到MainScheduler以确保这些更新显示在屏幕上。

当使用Units时，MainScheduler也被用来执行所有的计算，更具体的说，是Driver。在早期的章节讨论中，Driver确保了计算一直在MainScheduler上执行，它给你直接绑定数据到你应用的用户界面的能力。

#### SerialDispatchQueueScheduler 296

SerialDispatchQueueScheduler设法抽象出一个串行 DispatchQueue的工作。 这个scheduler在使用observeOn时有很多优化。

你能够使用这个scheduler处理后台工作，在**串行模式**下它是最好的scheduler。例如，如果你有一个应用与服务器的单个端点（像是在Firebase或GraphQL应用中）通讯，你可能想避免调度多重的，并发的请求，因为这将对接收端造成太大压力。这个scheduler绝对是你希望的为任何像串行任务队列那样步进的任务工作的。

#### ConcurrentDispatchQueueScheduler 296

它与 SerialDispatchQueueScheduler类似，在DispatchQueue上管理抽象工作。主要的不同是这个scheduler使用**并发队列**。当使用observeOn时这种scheduler没有被优化，因此当决定使用哪种scheduler时要记住账号。

对多重的，长时间运行的任务，他们需要同时结束，并发scheduler可能是一个好的选择。用一个块操作合并多个observables，这样当准备好时所有的结果被合并到一起，在他们最佳状态时能够阻止来至串行scheduler的执行。同时，并发scheduler可以执行多个并发任务并优化结果的收集。

#### OperationQueueScheduler 296

OperationQueueScheduler类似于ConcurrentDispatchQueueScheduler，但是不是通过DispatchQueue抽象工作，而是通过NSOperationQueue执行作业。 有时你需要更多的控制正在运行的并发作业，而你不能使用并发 DispatchQueue。

#### TestScheduler 296

TestScheduler是一种特殊的类型。 它只用于测试，所以尽量不要在生产代码中使用此scheduler。 这个特殊的scheduler简化了操作员测试 它是RxTest库的一部分。 您将在有关测试的专门章节中查看使用此scheduler，但让我们可以快速浏览一下自动执行scheduler。

该scheduler的一个很好的用例由RxSwift的测试套件提供。 打开用于测试延迟操作的专用的Observable + TimeTest.swift文件，并搜索名为testDelaySubscription_TimeSpan_Simple的单个测试用例。 在这个测试案例中，你有初始的scheduler：

```swift
let scheduler = TestScheduler(initialClock: 0)
```

接着你定义了observable来测试：

```swift
let xs = scheduler.createColdObservable([
  next(50, 42),
  next(60, 43),
  completed(70)
  ])
```

而就在对期望的定义之前，您有如何获得结果的声明：

```swift
let res = scheduler.start {
  xs.delaySubscription(30, scheduler: scheduler)
}
```

res将由使用先前定义的xs observable的scheduler所创建。这个结果包含有关事件发送以及由测试scheduler跟踪的事件的所有信息。

有了这个，你可以写一个这样的测试用例

```swift
XCTAssertEqual(res.events, [
  next(280, 42),
  next(290, 43),
  completed(300)
  ])
```

为什么事件发生在280而不是80（原50加30）？这是由 testScheduler的特性决定的，它200后开启所有到 ColdObservable的订阅。这个技巧确保了cold observable不会在一个不确定的时间启动。

同样的事情不适用于HotObservable，因为HotObservable会立即开始推送事件。

 当你正在测试delaySubscription的操作时，仅仅测试事件发送和它们的时间信息是不够的。你需要额外的关于订阅的时间的信息来确保每件事获得预期效果。

用xs.subscriptions，你能获得订阅的列表来做最后部分的测试：

```swift
XCTAssertEqual(xs.subscriptions, [
  Subscription(230, 300)
  ])
```

第一个数字代表了第一个订阅启动的时间。第二个订阅销毁的时间。在这种情况下，第二个数字匹配完成事件，应为完成将销毁所有订阅。