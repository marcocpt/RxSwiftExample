## \RxSwift_v1.0笔记——23 MVVM with RxSwift

RxSwift是一个很大的话题，本书之前没有覆盖任何应用构架的细节。是因为RxSwift不会强迫在你的应用上使用任何特定的构架。不过，因为RxSwift与MVVM一起工作更合适，本章将专注于讨论讨论特殊的构架样式。

### Introducing MVVM 353

MVVM代表了Model-View-ViewModel；它与Apple的亲儿子MVC有略微不同的实现。

用一个开放的思想来处理MVVM是很重要的。MVVM不是软件构架的万能药；当然，考虑到MVVM是一个软件范式，使用它是朝着好的应用构架迈出的第一步，尤其是你开始是MVC的思维方式。

#### Some background on MVC 354

现在你对MVVM和MVC可能感觉有一点矛盾（tension）。它们之间有什么联系？它们非常相似，甚至你可以认为它们是远房亲戚。但是解释它们之间的不同点任然是必要的。

在本书（和其他关于编程的书）中的大部分的例子使用MVC样式来写代码示例。MVC是对许多简单的app来说是简单的样式，它看起来像这样：

![](http://upload-images.jianshu.io/upload_images/2224431-97d0be927ef20650.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

每个类分配一个类别：controller类扮演中间角色让model和view能够更新，views仅仅在屏幕上显示数据并发送事件（如手势）到controller。最后models读和写数据来固化app状态。

MVC是简单的样式，它能暂时（for a while）为你服务，但是当你的app成长后，你将注意到许多类既不是view又不是model，所以只能是controllers。你开始掉入一个普遍的陷阱，在一个controller类中增加了越来越多的代码。由于你是从iOS应用程序启动视图控制器，最简单的方法是将所有代码放入该视图控制器类。因此，MVC代表“Massive View Controller”的老笑话，因为控制器可以成长为数百甚至数千条行。

过载你的类是一个不好的做法，但不一定是MVC模式的缺点。例如：苹果的许多开发人员都是MVC的粉丝，他们生产（turn out）了非常好的macOS和iOS软件。

```
Note：你可以阅读更多关于MVC在苹果专用的文档页面：https://developer.apple.com/library/content/documentation/General/Conceptual/DevPedia-CocoaCore/MVC.html
```

#### MVVM to the rescue 354

MVVM看起来很像MVC，但一定感觉更好。喜欢MVC的人通常也喜欢MVVM，这个新的样式让他们更容易解决许多MVC普遍的问题。

与MVC明显不同的是一个叫ViewModel的新种类：

![](http://upload-images.jianshu.io/upload_images/2224431-c96ce393aa7983f9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

ViewModel在构架中作为一个核心角色：它负责业务逻辑并与模型和视图进行对话。

MVVM有以下简单的规则：

- **Models**不直接与其他类对话，但是他们能发射关于数据变化的通知。
- **View Models**与**Models**对话并暴露数据给**View Controllers**。
- **View Controllers**仅仅与**View Models**和**Views**会话，他们处理视图的生命周期并绑定数据到UI组件。
- **Views**仅仅通知事件给视图控制器（就像MVC一样）。

等等，View Model不正是做了MVC中控制器做的事吗？是，也不是。

正如先前所说的，普遍的问题是视图控制器塞入了不是控制视图的代码。MVVM通过把视图控制器与视图组合来尝试解决这个问题，并让它只负责控制视图。

MVVM构架的另一个好处是增加代码的**可测试性**。把视图的生命周期从业务逻辑分离，让测试视图控制器和视图模型变的非常简单。

最后但也是很重要的一点，视图模型完全从**显示层分离**，当需要的时候，能够在不同平台间重用。你可以仅仅替换视图/视图控制器对，然后迁移你的app从iOS到macOS，甚至是tvOS。

#### What goes where? 355

但是，不要以为一切都应该在你的View Model类中。

这与你最终在MVC一样，将是同样愚蠢的。您可以基于你的代码来明确划分和分配责任。因此，留着View Model作为数据和屏幕之间的大脑，但是确保你分离了网络，导航，缓存和相似的职责到其他类。

如果它们不属于任何MVVM类别，这些额外的类如何处理呢？MVVM对于这些没有硬性规定，但是在本章你将工作的项目，它将给你介绍一些可行的解决方案。

本章将介绍一个好方法，它将通过其初始化或在其生命周期中尽可能晚的，注入View Model所需的所有对象。这就是说你能够将长时间活动的对象，像是API类的状态或来自视图模型的固化层对象到另一个视图模型：

![](http://upload-images.jianshu.io/upload_images/2224431-410d73c2b091e0f4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

在本章的项目“Tweetie”中，您将以这种方式传递一些东西，例如关于应用内导航（Navigator）的对象，当前登录的Twitter帐户（TwitterAPI.AccountStatus）等等。

但是MVVM的唯一好处是让代码变的更短吗？如果使用得当，MVVM比MVC有更多优势：

- 视图控制器趋于更简单和名副其实，因为它的唯一责任是控制视图。MVVM更易于使用RxSwift/RxCocoa，因为能够绑定observables到UI组件是MVVM的关键能力。
- 视图模型有清晰的Input -> Output样式，并且在为预期输出提供预定义的输入和测试时非常容易测试。![](http://upload-images.jianshu.io/upload_images/2224431-5b5c48b00a1e5a92.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)
- 通过创建模拟视图模型并对预期的视图控制器状态进行测试，形象化地测试视图控制器变得更加容易。![](http://upload-images.jianshu.io/upload_images/2224431-f4acd21241ae034e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/620)

最后但也是很重要的一点，因为MVVM是一个伟大的分离至MVC，它也可以作为一个启发和灵感来探索更多的软件架构模式。

想试试MVVM？ 在您阅读本章时，您将看到其许多好处。

### Getting started with Tweetie 357

本章，你将工作在叫做Tweetie的多平台项目。它是一个非常简单的Twitter-powered应用，它使用一个预定义的用户列表来向用户显示推文。默认情况下，起始程序项目使用的是具有（featuring）本书所有作者和编辑者的Twitter列表。如果你喜欢，你可以很容易的改变这个列表来转换项目为运动，写作，摄影app。

这个项目面向macOS和iOS，并通过使用MVVM样式来解决许多现实生活（real-life）中的编程任务。有许多代码包含在了起始项目中，你将聚焦在MVVM相关部分。

当你完成本章后，你将见证MVVM有助于区分以下内容：

- 与UI相关的代码是特定于平台的，例如为iOS的视图控制器使用UIKit ，以及分离的macOS独有的视图控制器使用Cocoa。
- 代码按原样重用，因为它不依赖于特定平台的UI框架，例如模型和视图模型中的所有代码。

是时候潜入了！

#### Project structure 357

安装所有CocoaPods，打开项目，预览下项目结构。

在项目导航中，你将发现有很多文件夹：

![](http://upload-images.jianshu.io/upload_images/2224431-f39b89c6debfa447.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/320)

- **Common Classes**：在macOS与iOS间共享代码。包含一个Rx Reachability类扩展，在 UITableView,  NSTableView上的扩展等等
- **Data Entities**：为了固化数据到硬盘，数据对象使用Realm移动数据库。
- **TwitterAPI**：一个轻量的API实现来向Twitter’s JSON API发送请求。 TwitterAccount是允许您访问用户设备上登录的Twitter帐户的类，而TwitterAPI会向Web JSON端点发出请求。
- **View Models**：app的三个视图模型位于这里。一个是功能完整的，你将完成另外两个。
- **iOS Tweetie**： 包含iOS版本的Tweetie，包括一个storyboard和iOS视图控制器。
- **Mac Tweetie**：包含macOS目标与它的storyboard，资源和视图控制器。
- **TweetieTests**：app测试和模拟对象位于此。

```
Note：直到你完成了章节挑战后测试才会通过，并且你能够使用测试来确保正确的完成挑战。如果现在不工作，不用惊讶！
```

你的任务是完成app以便用户能够看到在列表中所有用户的tweets。你首先实现网络层，然后写一个视图模型类，并在最后你将创建两个视图控制器（一个给iOS，另一个给macOS），使用完成的视图模型在屏幕上显示数据。

![](http://upload-images.jianshu.io/upload_images/2224431-88a0ed2a323dffc3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/600)

您将会参加许多不同的课程，并亲身体验MVVM。

#### Finishing up(完成) the network layer 359

这个项目已经包含了许多代码。您在本书中已经学了很多，我们不会来实现简单的任务，例如设置observables和视图控制器。你将开始完成项目的网络层。

在**TimelineFetcher.swift**中的类 TimelineFetcher是负责在app连接时抓取最新的tweets。这个类很简单，并且使用了一个Rx定时器来重复调用抓取来至web的JSON的订阅。

 TimelineFetcher有两个遍历的测试：一个用来抓取给定Twitter列表的推文（tweets），另一个抓取给定用户的推文。

在这个章节，你将增加代码来做网络请求并映射响应到Tweet对象。在本书中你已经完成过相似的任务，因此在Tweet.swift中已经包含了大部分代码。

```
Note：人们常常会问当使用MVVM做项目时在哪里增加网络层，因此我们编写了这章让你有机会自己增加网络层。关于网络层没有什么是难以理解的；它是一个你注入视图模型的常用类。
```
在**TimelineFetcher.swift**， 滚动到 **init(account:jsonProvider:)**的底部，找到这行：

```Swift
timeline = Observable<[Tweet]>.never()
```
用以下内容替换那行：

```swift
timeline = reachableTimerWithAccount
  .withLatestFrom(feedCursor.asObservable(), resultSelector:
    { account, cursor in
      return (account: account, cursor: cursor)
  })
```

您可以使用定时器observable  reachableTimerWithAccount并将其与feedCursor组合。 feedCursor当前没有做任何事，但是您将使用此变量把你当前的位置存储在Twitter时间轴中，来指明您已经获取的哪些推文。

一旦你增加这个代码，Xcode会显示一个错误，现在可以忽略它。这将在增加后续代码后解决。

现在增加下面内容到链：

```swift
.flatMapLatest(jsonProvider)
.map(Tweet.unboxMany)
.shareReplayLatestWhileConnected()
```

您首先将参数jsonProvider进行flatmapping。 jsonProvider是注入到init的闭包。每个便利inits都支持抓取不同的API端点，因此注入 jsonProvider是一个便利的方式来避免在主初始化程序 init(account:jsonProvider:)中使用if声明或分支逻辑。

 jsonProvider返回一个 Observable<[JSONObject]>，因此下一步是map到一个 Observable<[Tweet]>。你使用已提供的 Tweet.unboxMany函数，尝试转换JSON对象到tweets数组中。

用这些新的代码，你准备抓取tweets了。  timeline是一个公共的observable，这就是你的视图模型如何来访问最新tweets的列表。app的视图模型可能存储了推文到硬盘或马上（straight away）使用它们驱动app的UI，但是那完全是它们自己的事。 TimelineFetcher简单的抓取推文并显示结果：

![](http://upload-images.jianshu.io/upload_images/2224431-6b286e49f188c61b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

因为这个订阅被重复的调用，你也需要存储当前位置（或光标）以便你不会重复抓取同样的推文。接着在你输入的下面增加：

```swift
timeline
  .scan(.none, accumulator: TimelineFetcher.currentCursor)
  .bindTo(feedCursor)
  .addDisposableTo(bag)
```

 feedCursor是在TimelineFetcher上的Variable<TimelineCursor>类型的属性。 TimelineCursor是一个自定义结构体，它保存了迄今你已经抓取的最新和最老的推文ID。每次你抓取一组新的推文，你就更新 feedCursor的值。如果你对更新timeline cursot,的逻辑感兴趣，请查看 TimelineFetcher.currentCursor()。

```
Note：本书不覆盖cursor的详细逻辑方面的知识，因为他是专用于Twitter API的。你可以读取更多关于cursoring的内容在：https://dev.twitter.com/overview/api/cursoring
```

下一步你需要创建一个视图模型。你将使用完成的 TimelineFetcher类从API抓取最新推文。

#### Adding a View Model 361

本项目已经包含了一个导航类，数据实体，和Twitter账号访问类。现在你的网络层已经完成，你可以简单的合并所有这些给Twitter的登录用户，然后抓取一些推文。

在本节，你不用关心控制器。找到项目的**View Models**文件夹，打开**ListTimelineViewModel.swift**。作为同样的建议，视图模型将抓取给定用户列表的推文。

它是一个很好的实践（但确定不是一个唯一的方式）来澄清在你的视图模型代码的三个部分的定义：

1. Init：在这里你定义一个或多个inits来注入你所有的依赖。
2. Input：包含任何公共属性，例如简单（plain）变量或RxSwift subjects，它允许视图控制器提供输入。
3. Output：包含任何公共属性（通常是observables），它提供视图模型的输出。通常用对象列表来驱动一个表格或集合视图，或者是一个视图控制器用来驱动app的UI的其他类型的数据。

![](http://upload-images.jianshu.io/upload_images/2224431-c466099001cbd0ec.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/400)

 **ListTimelineViewModel**的初始化里已经有少许代码用来初始化 fetcher属性。 fetcher是 TimelineFetcher的一个实例，它用来抓取推文。

是时候来增加更多的属性到视图模型了。首先，增加下面两个属性，他们既不是输入又不是输出，但它简单的帮助你持有注入的依赖：

```swift
let list: ListIdentifier
let account: Driver<TwitterAccount.AccountStatus>
```

由于他们是常量，你的唯一初始化他们的机会是在 init(account:list:apiType)中。在初始化类顶部插入下面代码：

```swift
self.account = account
self.list = list
```

现在你能够继续增加输入属性。既然你已经注入了所有这个类的依赖，然而什么属性应该做输入呢？注入依赖和你提供给init的参数允许你在初始化时提供给输入。其他公共属性将允许你在它生命周期的任何时候，提供输入给视图模型。

例如，考虑一个让用户搜索数据库的app。你将绑定搜索文本框到视图模型的输入属性。当搜索词改变，视图模型将响应地搜索数据库并改变他的输出，它将依次（in turn）绑定到表格视图来显示结果。

当前的视图模型，你拥有的唯一输入是一个属性，它让你暂停和恢复timeline fetcher类。 TimelineFetcher已经具有（feature）一个 Variable<Bool>来做到这一点，所以在视图模型中你需要一个代理属性。

在 ListTimelineViewModel输入部分，用方便的注释 // MARK: - Input标记的位置，插入下面代码：

```swift
var paused: Bool = false {
  didSet {
    fetcher.paused.value = paused
}
```

这个属性是一个简单的代理，它在fetcher类上设置 paused的值。

现在你能够继续做视图模型的输出了。视图模型将显示推文的抓取列表和登录状态。前者将是从Realm加载的 Variable的推文对象；后者，一个 Driver<Bool>简单的发射false或true来标识是否用户正确的登录到Twitter。

在输出部分（通过注释标记），插入下面两个属性：

```
  private(set) var tweets: Observable<(AnyRealmCollection<Tweet>, RealmChangeset?)>!
  private(set) var loggedIn: Driver<Bool>!
```

 **tweets**包含最新 Tweet对象的列表。在任何推文被加载前，例如在用户登录了他们的Twitter账号前，默认值是nil。  **loggedIn**

是一个Driver，它将在稍后被除数。

现在你能够订阅 TimelineFetcher的结果，并存储推文到Realm。当你使用RxRealm时，这当然是非常容易的。附加到 init(account:list:apiType:)：

```
fetcher.timeline
  .subscribe(Realm.rx.add(update: true))
  .addDisposableTo(bag)
```

你订阅到 fetcher.timeline，它是 Observable<[Tweet]>类型的，然后绑定结果（tweets的数组）到 Realm.rx.add(update:)。 Realm.rx.add固化输入的对象到app默认的Realm数据库中。

最后一段代码关注在你视图模型中的数据流入，所以剩下的就是构建视图模型的输出。 找到名为**bindOutput**的方法，然后插入：

```
guard let realm = try? Realm() else {
  return
}
tweets = Observable.changesetFrom(realm.objects(Tweet.self))
```

当你学习了21章，“RxRealm”，你可以容易的用Realm的Resultes辅助类来创建一个observable序列。在上面的代码中，您可以从所有持久化的推文中创建一个结果集，并订阅该集合的更改。你呈现感兴趣的部分推文observable，它通常是你的试图控制器。

下一步你需要考虑loggedIn输出属性。这个很容易照顾——你仅仅需要订阅账号并映射它的元素到true或false。附加下面内容到bindOutput：

```
loggedIn = account
  .map { status in
    switch status {
    case .unavailable: return false
    case .authorized: return true
    }
  }
  .asDriver(onErrorJustReturn: false)
```

这是所有视图模型需要做的！你小心的注入所有依赖到init内，你增加一些属性来允许其他类提供输入，最后你绑定视图模型的结果到公共属性，这样其他类就能够观察。

正如你看到的，视图模型不知道任何关于视图控制器，视图，或其他类的内容，它们不会通过视图模型的初始化注入。因为视图模型很好的隔离了剩余的代码，你能够继续写他的测试来确保它正常工作——甚至在你在屏幕上看到任何输出之前。

#### Adding a View Model test 364

在Xcode项目导航内，打开TweetieTests文件夹。在这里面你将找到给你提供的一些东西：

- TestData.swift：提供一些测试JSON和测试对象。
- TwitterTestAPI.swift：Twitter API模拟（mock）类，这个方法调用并记录了API响应。
- TestRealm.swift：为了测试，使用一个测试Realm配置确保了Reaml使用一个零时的内存数据库。

打开**ListTimelineViewModelTests.swift**，增加一些新的测试。这个类已经有一个实用的方法来创建一个新的 ListTimelineViewModel实体和两个测试：

1.  test_whenInitialized_storesInitParams()，它测试视图模型是否固化它注入的依赖。
2.  test_whenInitialized_bindsTweets()，通过它的 tweets属性，它检查视图模型是否显示最新固化的推文。

为了完成测试用例，你将增加一个新的测试：一个用来检测是否 loggedIn输出属性属性反应了账号的鉴定状态。增加下面代码：

```
func test_whenAccountAvailable_updatesAccountStatus() {
  let asyncExpect = expectation(description: "fullfill test")
}
```

因为这是一个异步测试，你定义了一个expectation，一旦你侦测到期望的测试结果，你将满足它。

附加下面内容到方法中：

```
let scheduler = TestScheduler(initialClock: 0)
let observer = scheduler.createObserver(Bool.self)
```

你创建一个测试调度程序（scheduler），然后使用它创建一个名为observer的测试观察者。你将用你的视图模型的loggedIn属性测试元素发射，因此你可以告诉观察者来监听Bool元素。

现在增加下列代码：

```
let accountSubject = PublishSubject<TwitterAccount.AccountStatus>()
let viewModel =
createViewModel(accountSubject.asDriver(onErrorJustReturn: .unavailable))
```

下一步，你创建一个 PublishSubject，你将用来测试 AccountStatus值的发射。你传递该主题给 createViewModel()，并最终抓取一个视图模型实例，所有这些都是为测试做准备和建立。

下一步你将订阅在测试下的observable。增加：

```
let bag = DisposeBag()
let loggedIn = viewModel.loggedIn.asObservable()
  .share()
```

在这里，您可以获得可共享的连接，并可以采取一些行动。

首先用以下代码订阅 loggedIn到测试观察者：

```
loggedIn
  .subscribe(observer)
  .addDisposableTo(bag)
```

然后，为了在完成发送测试值之后结束异步测试，请添加：

```
loggedIn
  .subscribe(onCompleted: asyncExpect.fulfill)
  .addDisposableTo(bag)
```

现在所有的订阅在这了，你简单的发射少许测试值。增加：

```
accountSubject.onNext(.authorized(TestData.account))
accountSubject.onNext(.unavailable)
accountSubject.onCompleted()
```

最后，检查是否 loggedIn发射了正确的值，增加下面代码来比较记录事件与先前所定义期望的事件列表：

```
waitForExpectations(timeout: 1.0, handler: { error in
  XCTAssertNil(error, error!.localizedDescription)
  let expectedEvents = [next(0, true), next(0, false), completed(0)]
  XCTAssertEqual(observer.events, expectedEvents)
})
```

该代码等待异步期望的实现，然后检查记录事件是否是 .next(true)， .next(false)，和 .completed.的序列。

```
Note：如果你更愿意，继续并使用RxBlocking重写这个代码。你已经在16章“Testing with RxTest”中学到了如何做
```

接着，测试用例完成了。高隔离度的视图模型类让你容易的注入模拟对象和仿真输入。阅读测试套件类的其余部分，看看还有什么被测试。如果你想出一些新的测试那应该是很有用的，随意增加吧！

```
Note：应为在Tweetie项目的视图模型非常好的隔离了应用基础的剩余部分，你不需要运行整个应用来运行测试。窥探iOS Tweetie / AppDelegate.swift，查看代码如何避免在测试过程中创建应用程序的导航和查看控制器。或者，您可以禁用主应用程序进行测试。
```

现在你有了个全功能的视图模型，也包括在test。是时候使用它了！

#### Adding an iOS View Controller 366

在本节中，您将编写代码，将视图模型的输出连接到ListTimelineViewController中的视图——这个控制器将在预设的列表中显示组合的用户的推文。

首先，你将工作在iOS版本的Tweetie上。在这个项目的导航中，打开iOS Tweetie/View Controllers/List Timeline。在这里面，你将找到试图控制器和iOS专用的table cell view文件。

打开并浏览下ListTimelineViewController.swift。 ListTimelineViewController类具有视图模型属性和一个导航属性。两个类通过静态方法createWith(navigator:storyboard:viewModel)被注入。

你将增加两个部分启动代码到视图控制器。一个是在 viewDidLoad()中的静态配置，另一个是在 bindUI()中绑定视图模型到UI。

在 viewDidLoad()，调用bindUI()之前增加代码：

```
title = "@\(viewModel.list.username)/\(viewModel.list.slug)"
navigationItem.rightBarButtonItem =
UIBarButtonItem(barButtonSystemItem: .bookmarks, target: nil, action:
nil)
```

这将设置列表的名字作为标题并在导航栏右边创建一个新按钮项。

下一步，绑定视图模型。插入下面代码到 bindUI()：

```
navigationItem.rightBarButtonItem!.rx.tap
  .throttle(0.5, scheduler: MainScheduler.instance)
  .subscribe(onNext: { [weak self] _ in
    guard let this = self else { return }
    this.navigator.show(segue: .listPeople(this.viewModel.account,
                                           this.viewModel.list), sender: this)
  })
  .addDisposableTo(bag)
```

你订阅右bar项的tap，然后throttle他们来防止任何双击。然后你调用 navigator属性的show(segue:sender:)方法来显示你呈现到屏幕的segue的意图。segue显示人的列表：已经选择Twitter列表成员。

Navigator要么负责呈现请求的屏幕，要么丢弃你的意图，如果它决定执行此操作，那么它可能基于其他参数来决定忽略你希望呈现视图控制器的意图。

```
Note：通过阅读Navigator类的定义来详细了解类的实现。它包含可导航屏幕所有可能的列表，并且您只能通过提供所有必需的输入参数来调用这些segues。
```

你也需要创建另一个绑定来在表格视图中显示最新推文。滚动到文件顶部，导入下面的库可以方便的绑定RxRealm结果到表格和集合视图：

```
import RxRealmDataSources
```

然后返回到 bindUI()并附加：

```
let dataSource = RxTableViewRealmDataSource<Tweet>(cellIdentifier:
  "TweetCellView", cellType: TweetCellView.self) { cell, _, tweet in
  cell.update(with: tweet)
}
```

 dataSource是一个表格视图数据源，尤其适合驱动来自Realm集合更改的observable序列的表格视图。在单一行你配置数据源完成：

1. 你设置模型类型为Tweet
2. 然后你设置单元格标识符作为 TweetCellView来使用
3. 最后你提供一个闭包在它显示在屏幕上之前来配置每个单元


你现在能绑定数据资源到视图控制器的表格视图。在最后块的下面增加：

```
viewModel.tweets
  .bindTo(tableView.rx.realmChanges(dataSource))
  .addDisposableTo(bag)
```

在这里你绑定 viewModel.tweets到 realmChanges，并提供预处理的数据源。这是您使用动画更改驱动表格视图所需的最低限度。

为这个视图控制器最后的绑定将依据是否用户登录到Twitter来决定在顶部显示或影藏。附加下面代码

```
viewModel.loggedIn
  .drive(messageView.rx.isHidden)
  .addDisposableTo(bag)
```

这个绑定开关 messageView.isHidden是基于当前 loggedIn的值的。

这部分展示了为什么绑定是MVVM范式的关键。对于你的视图控制器它仅作为“胶水”代码来服务，这样你就可以轻松地将问题分开。你的视图模型保持了大部分关于当前它运行的平台无关的内容，英文它不导入任何像UIKit或CocoaUId的框架。

运行app并观察所有你闪亮的新视图模型所驱动的绑定：

![](http://upload-images.jianshu.io/upload_images/2224431-310aa3a6e9a8b6aa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/400)

一旦app完成了JSON请求，消息会在顶部呈现。然后用一个漂亮的动画来抓取推文“蜂拥而来”（pour in）最后，当你点击在右边的bar item时，app将显示用户列表视图控制器：

![](http://upload-images.jianshu.io/upload_images/2224431-ab2ea63ede18bd6b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/300)

那就是！在下一节，你将学到跨平台来重用你的视图模型是多么的容易。

#### Adding a macOS View Controller 369

视图模型不知道任何关于视图或视图控制器的使用。它的意义是，视图模型在需要时是平台独立的。同样的视图模型能容易的提供数据给iOS和macOS的视图控制器。

 ListTimelineViewModel恰恰是一个视图模型。它仅仅依赖RxSwift, RxCocoa, and the Realm database。因为这些库是跨平台的，而且视图模型也是跨平台的。

你的工作是切换Xcode项目的macOS目标，然后构造一个视图控制器，镜像你上面构筑的iOS的那个。

从Xcode的scheme选择**MacTweetie/My Mac**，然后运行项目，看看macOS的起始项目长什么样。

![](http://upload-images.jianshu.io/upload_images/2224431-0bfaa58943490278.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/600)



