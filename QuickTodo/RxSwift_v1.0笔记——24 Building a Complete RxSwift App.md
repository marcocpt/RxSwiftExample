## RxSwift_v1.0笔记——24 Building a Complete RxSwift App

通过本书，你学习到了RxSwift的许多方面。响应式编程是一个很深的主题；采用它常常导致构建非常不同于你以前所使用的。**你在RxSwift中对事件和数据流进行建模的方式对于正确的行为以及防止未来产品发展至关重要。(The way you model events and data flow in RxSwift is crucial to proper behavior as well as protecting against future evolutions of the product.)**

你将构建一个小的RxSwift应用来结束本书。这个目标不是“不惜任何代价”使用Rx，而是使设计决策引导一个具有稳定，可预测和模块化行为的干净的架构。这个应用设计比较简单，清晰的呈现了你能够用来构建你自己的应用的思想。

本章是关于RxSwift的，也是适合你需要的一个好的构架。RxSwift是一个伟大的攻击，它帮助你的应用运行起来像一个精心调校（well-tuned）的引擎，但它对于思考和设计应用程序架构不是多余的。

### Introducing QuickTodo 376

作为“hello world”程序的现代版，“To-Do”应用程序是展现Rx应用程序内部结构的理想选择。

在上一章中，你了解到有关MVVM以及与反应编程相匹配的情况。 你将使用MVVM构建QuickTodo应用程序，并了解如何隔离代码的数据处理部分并使其完全独立。

![](http://upload-images.jianshu.io/upload_images/2224431-8c1f3f4d9dd98b35.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/400)

### Architecting the application 376

一个你应用的尤其重要的目标，是完成用户界面与应用的业务逻辑的分离，以及应用程序包含的服务来帮助业务逻辑运行。为此（To that end），你真的需要一个清晰的模型，其中每个组件都被明确定义。

首先，让我们介绍一些你将实现的构建的一些术语：

- **Scene**：指由视图控制器管理的屏幕。它可以是常规屏幕，或模态对话框。它由一个视图控制器和一个视图模型组成。
- **View model**：定义业务逻辑和数据给视图控制器使用，来呈现一个特定的场景。
- **Service**：一个功能性的逻辑组提供给在应用中的任何场景。例如，数据库存储能够被抽象为一个服务。同样的，网络API请求能够被分组到网络服务。
- **Model**：存储在应用中大部分的基础数据。视图模型和服务都操作和交换模型。

在上一章“MVVM with RxSwift”中你学习了视图模型。Services是一个新的概念并且也适合与响应式编程。他们的目的是竟可能的使用Observable和Observer暴露数据和功能，以便创建一个全局模型，其中的组件竟可能以响应方式的连接在一起。

对于你的QuickTodo应用，需求相当适用。正确构建，将为你未来的发展奠定坚实的基础。它也是一个你可以重用与其他app的构架。

你需要了解的基础项：

- 一个TaskItem **model**，它表示一个个人任务。
- 一个TaskService **service**，它提供了任务创建、更新、删除、存储和搜索。
- 一个**storage medium**；你将使用一个Realm数据库和RxRealm。
- 一个系列的创建和搜索任务的**scenes**列表。每个scene分离到一个**视图模型**和一个**视图控制器**。
- 一个scene coordinator对象来管理场景的导航和显示。

![](http://upload-images.jianshu.io/upload_images/2224431-b108e5b11e04fb57.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/640)

正如你上章所学的，视图模型暴露了业务逻辑和数据模型给视图控制器。接下来你将为每个视图模型创建简单的规则：

- 暴露数据作为observable序列。这保证了一旦连接到用户界面就自动更新。
- 使用动作样式将暴露的所有视图模型的动作连接到UI。
- 任何可公开访问的模型或数据，不会作为observable序列暴露，且都是不可变的。
- 从一个场景转换到另个场景是业务逻辑的一部分。每个视图模型初始化这个转换并准备下一个场景的视图模型，而不需要指定关于视图模型的任何事。

完全从实际的视图控制器隔离视图模型的一个解决方案，包含触发到其他场景的转换，本章稍后将会介绍。

```
Note：数据的不变性保证了对由UI触发的更新的完全控制。严格遵循以上规则也保证了每个代码块最好可测试性。
前章展示了如何在didSet的帮助下，使用可变属性来更新底层模型。本章将通过完全删除可变性并仅暴露Actions，来更深入的采取此观念。
```

### Bindable view controllers 378

你将从视图控制器开始。在某些时候，你需要连接，或绑定视图控制器到与它相关的视图模型。做这个的一种方式是你的控制器采用一个特定的协议：BindableType。

```
Note：本章的起始项目包含了相当多的代码。当你第一次用Xcode打开项目时，将不能编译成功。在你构筑并运行前，你需要增加一些关键的点。
```

打开BindableType.swift 然后增加基本的协议：

```swift
protocol BindableType {
  associatedtype ViewModelType
  var viewModel: ViewModelType! { get set }
  func bindViewModel()
}
```

每个视图控制器遵循BindableType协议，它声明了一个viewModel变量并且，一旦viewModel变量被分配就调用提供的一个bindViewModel()函数。这个函数将连接UI元素到在视图模型中的observables和actions。

#### Binding at the right moment 379

绑定有一个特殊的地方需要注意。你希望尽快将viewModel变量分配到你的视图控制器，但是bindViewModel()必须在视图加载之后调用。

这是因为你的bindViewModel()函数通常会连接需要曾现的UI元素。为此，你将使用一个小的帮助函数，在实例化每个视图控制器之后来调用它。增加这个到BindableType.swift：

```swift
extension BindableType where Self: UIViewController {
   mutating func bindViewModel(to model: Self.ViewModelType) {
    viewModel = model
    loadViewIfNeeded()
    bindViewModel()
  }
}
```

这样，在你的视图控制器调用 viewDidLoad()时，确保了 viewModel已经被分配。 由于viewDidLoad（）是设置视图控制器标题以便平滑推送导航标题动画的最佳时间，你可能需要访问视图模型以准备标题，加载视图控制器，如果需要，这样是最有效的方案。

### Task model 379

你的任务模型是简单的且来源于Realm的基本对象。任务定义为有一个标题（任务内容），一个创建日期和一个检查日期。日期被用来在任务列表中对任务排序。如果你部署需Realm，请查看他们的文档：https://realm.io/docs/swift/latest/。

填充TaskItem.swift如下：

```swift
class TaskItem: Object {
  dynamic var uid: Int = 0
  dynamic var title: String = ""
  dynamic var added: Date = Date()
  dynamic var checked: Date? = nil
  override class func primaryKey() -> String? {
    return "uid"
  }
}
```

对于来至Realm数据库的特定对象，有两个你需要详细知道的细节是：

- Object不能跨线程。如果你需要一个在不同的线程的对象，要么重新查询，要么使用Realm的 ThreadSafeReference。
- Objects是自动更新的。如果你改变了数据库，它会立即反映到来至数据库的任何被查询的活动对象的属性中。稍后你将看到它是如何使用的。
- 因此，删除对象会使所有现有副本无效。如果你访问了一个被删除的查询对象的属性，将会抛出异常。

上面的第二点有副作用，你将在本章后面更详细地研究绑定任务单元格。

### Tasks service 380

Tasks service的责任是创建、更新和抓取来至商店任务项。作为一个有责任的开发者，你将使用协议来定义你的服务公共接口，然后写一个运行时的实现并为测试模拟实现。

首先，创建协议。这是你将暴露给用户的服务。

打开TaskServiceType.swift，增加协议的定义：

```swift
protocol TaskServiceType {
  @discardableResult
  func createTask(title: String) -> Observable<TaskItem>
  @discardableResult
  func delete(task: TaskItem) -> Observable<Void>
  @discardableResult
  func update(task: TaskItem, title: String) -> Observable<TaskItem>
  @discardableResult
  func toggle(task: TaskItem) -> Observable<TaskItem>
  func tasks() -> Observable<Results<TaskItem>>
}
```

这是一个基本的接口，提供了基础服务来创建，删除更新和查询任务。没什么有趣的。大部分重要的细节是服务暴露了作为observable序列的数据。即使是创建，删除，更新和开关任务的函数也返回一个你可以订阅的observable。

它的核心概念是，通过observables的成功完成，来传输任何操作的失败或成功。另外，在Actions中你能够使用返回的observable作为返回值。你将在本章稍后看到一些例子。

例如，打开TaskService.swift，你将看到 update(task:title:)是这样的：

```swift
@discardableResult
func update(task: TaskItem, title: String) -> Observable<TaskItem> {
  let result = withRealm("updating title") { realm -> Observable<TaskItem> in
    try realm.write {
      task.title = title
    }
    return .just(task)
  }
  return result ?? .error(TaskServiceError.updateFailed(task))
}
```

withRealm（_：action :)是一个内部封装，可以获取当前的Realm数据库并对其进行操作。如果抛出错误，withRealm(_:action:)将始终返回nil。 这是一个很好的机会返回一个错误，可以将错误信号发送给调用者。

你不需要从头到尾完成tasks service的实现，但是你应该花点时间浏览下TaskService.swift中的代码。

你做的最后一件事是添加TaskServiceType，现在打开TaskService.swift并使其符合该协议：

```swift
struct TaskService: TaskServiceType {
```

你已经完成了tasks service！你的视图模型将接收TaskServiceType对象，不论是真实的还是在测试期间模拟的，都应该能够工作。

### Scenes 381

你通过以上了解到，在本章的架构中，场景是由视图控制器和视图模型管理的“屏幕”构成的逻辑展示单元。场景的规则有：

- 视图模型处理逻辑业务。**This extends to kicking off the transition to another “scene”.**
- 查看模型对于实际的视图控制器和用于表示场景的视图一无所知。
- 视图控制器不应该一开始就转换到另一个场景；这是在视图模型中逻辑业务运行的域。

考虑到这一点，你可以放置一个应用场景列在场景枚举中的模型，每种情况都将场景视图模型作为其相关数据。

```
Note：这与你在上一章中导航类中所做的很相似，但是使用场景，导航更加灵活。
​```swift

打开Scene.swift。你将在我们的app中定义两个我们需要的场景，tasks和editTask。增加：

​```swift
enum Scene {
  case tasks(TasksViewModel)
  case editTask(EditTaskViewModel)
}
```

在这个阶段，视图模型可以实例化另一个视图模型并将其分配给其场景，准备转换。 你也可以完成视图模型的基本**contract**，尽可能不要依赖于UIKit。

现在即将添加的“场景”枚举的扩展，会暴露一个函数，该函数是实例化场景视图控制器的唯一位置。 该函数将知道如何从每个场景的资源中拉取视图控制器。

打开Scene+ViewController.swift，增加这个函数：

```swift
extension Scene {
  func viewController() -> UIViewController {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    switch self {
    case .tasks(let viewModel):
      let nc = storyboard.instantiateViewController(withIdentifier:
        "Tasks") as! UINavigationController
      var vc = nc.viewControllers.first as! TasksViewController
      vc.bindViewModel(to: viewModel)
      return nc
    case .editTask(let viewModel):
      let nc = storyboard.instantiateViewController(withIdentifier:
        "EditTask") as! UINavigationController
      var vc = nc.viewControllers.first as! EditTaskViewController
      vc.bindViewModel(to: viewModel)
      return nc
    }
  }
}
```

这个代码实例化了合适的视图控制器并立即绑定它到它的视图模型，它是来至数据相关联的每个枚举情况。

```
Note：当在你的app中有很多场景时，这个函数将变得很长。不要犹豫，分离它到多个部分以便清晰和可维护。在具有多个域的大型应用程序中，您甚至可以拥有域的“主”枚举，以及每个域的场景的子枚举。
```

最后，scene coordinator在场景之间处理转换。每个视图模型知道协调器并能够请求它来推送一个场景。

### Coordinating scenes 383

当开发一个围绕MVVM的构架时，最让人迷惑的问题是：“如何做场景转换？”。这个问题有很多答案，因为每个架构都有不同的做法。一些使用视图控制器，因为需要实例化其他的视图控制器；一些使用router，它是一个用来连接视图模型的特殊对象。

#### Transitioning to another scene 383

本章的作者推荐一个简单的解决方案，它是被证明是有效的，并已经使用它开发了许多应用程序：

1. 一个视图模型为下一个场景创建视图模型。
2. 第一个视图模型通过调用场景协调器来启动向下一个场景的转换。
3. 场景协调器使用场景枚举的扩展函数实例化视图控制器。
4. 下一步，它绑定控制器到下一个视图模型。
5. 最后，它呈现了下一个场景的视图控制器。

![](http://upload-images.jianshu.io/upload_images/2224431-d0e93d22c8b589e0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/500)

通过这种结构，您可以将视图模型与使用它们的视图控制器完全隔离，并将它们与从可以找到下一个视图控制器的细节地方进行隔离。 在本章的后面，您将看到如何使用Action模式来封装上述步骤1和2，并启动转换。

```
Note：你总是调用场景协调器的transition(to:type:)和pop()函数来在场景间转换是很总要的，因为协调器需要持续跟踪哪一个视图控制器在最前面，尤其是以模态方式呈现场景时。不要使用自动的segues。
```

#### The scene coordinator 384

场景协调器通过 SceneCoordinatorType协议来定义。一个具体的SceneCoordinator实现被提供来运行程序。你也能够开发一个测试实现伪装转换。

 SceneCoordinatorType协议（已经在起始项目中提供了），是简单而高效的：

```swift
protocol SceneCoordinatorType {
  init(window: UIWindow)

  /// transition to another scene
  @discardableResult
  func transition(to scene: Scene, type: SceneTransitionType) -> Observable<Void>

  /// pop scene from navigation stack or dismiss current modal
  @discardableResult
  func pop(animated: Bool) -> Observable<Void>
}
```

 transition(to:type:) 和pop(animated:)这两个函数让你实现了所有你需要的转换：push，pop， modal和dismiss。

SceneCoordinator.swift中的具体实现显示了使用RxSwift拦截委托消息的一些有趣的情况。 两个转换调用被设计为返回一个不发出任何东西的Observable <Void>，并在转换完成后完成。 您可以订阅它进行进一步的操作，因为它的工作原理就像完成回调。

为了实现这一点，项目中包含的代码创建了一个UINavigationController DelegateProxy，一个RxSwift委托，可以在将消息转发给实际代理时拦截消息：

```swift
_ = navigationController.rx.delegate
  .sentMessage(#selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:)))
  .map { _ in }
  .bindTo(subject)
```

在 transition(to:type:)方法的底部找到的技巧，是将此订阅绑定到返回给调用者的Subject：

```swift
return subject.asObservable()
  .take(1)
  .ignoreElements()
```

返回的observable将最多占用一个发送的元素来处理导情况，但不会转发，并完成。

```
Note：由于导航委托代理的无限订阅，您可能会质疑此构造的内存安全性。 这是完全安全的：返回的observable最多需要一个元素，然后完成。当完成后，它会销毁其订阅。 如果没有订阅返回的observable，则该subject从内存中销毁，其订阅也将终止。
```

#### Passing data back 385

将数据从场景传递到前一个数据，例如当场景以modally显示时，使用RxSwift会很容易。 呈现的视图模型实例化了呈现场景的视图模型，因此可以访问它并且可以建立通信。 为获得最佳效果，您可以使用以下三种技术之一：

1. 在第一（呈现）视图模型可以订阅第二（呈现）视图模型中暴露的Observable。当第二个视图模型解除显示时，它可以在observable上发出一个或多个元素的结果。
2. 将Observer对象（例如Variable或Subject）传递给所呈现的视图模型，该模型将使用此对象来发出一个或多个元素。
3. 将一个或多个 Actions传递给所呈现的视图模型，以适当的结果执行。

这些技术给予出色的可测试性，并帮助您避免在模型之间使用弱引用玩游戏。 添加编辑任务视图控制器时，您将看到本章后面的示例。

#### Kicking off the first scene 386

关于使用协调场景模型的最终细节在启动阶段; 您需要通过引入第一个场景来启动场景的显示。 这是您在应用程序委托中执行的一个方法。

打开AppDelegate.swift并增加下面代码到 application(_:didFinishLaunchingWithOptions:):

```swift
let service = TaskService()
let sceneCoordinator = SceneCoordinator(window: window!)
```

第一步是准备与协调器一起所需的所有服务。 然后实例化第一个视图模型，并指示协调器将其设置为root。

```swift
let tasksViewModel = TasksViewModel(taskService: service, coordinator:
  sceneCoordinator)
let firstScene = Scene.tasks(tasksViewModel)
sceneCoordinator.transition(to: firstScene, type: .root)
```

那很简单！ 这种技术是很酷的事情，如果需要，您可以使用不同的启动场景; 例如，第一次用户打开您的应用程序时运行的教程。

现在您已经完成了初始场景的设置，您可以查看各个视图控制器。

### Binding the tasks list with RxDataSources 386

在第18章“RxCocoa数据源”中，您了解到在RxCocoa中内置的UITableView和UICollectionView响应式扩展。 在本章中，您将学习如何使用RxDataSources，这是RxSwiftCommunity提供的框架，最初由RxSwift的创始人Krunoslav Zaher开发。

这个框架不属于RxCocoa的原因主要是它比RxCocoa提供的简单扩展更复杂和更深入。

但是为什么要在RxCocoa的内置绑定中使用RxDataSources？

RxDataSource提供了以下特性：

- 支持分段表和集合视图。
- 优化的重载，只需重新加载更改的内容，例如删除，插入和更新，这得益于有效的差异化算法。
- 可配置的动画，用于删除，插入和更新。
- 支持部分和项目动画。

在您的情况下，采用RxDataSources将提供自动动画，而无需任何工作。 目标是将任务列表末尾的检查项目移动到“已检查”部分。

RxDataSources的不足之处在于它比基本的RxCocoa绑定更难理解。 您可以传递一个部分模型数组，而不是将一组项目传递给表或集合视图。 部分模型定义了部分标题（如果有的话）以及每个项目的数据模型。

![](http://upload-images.jianshu.io/upload_images/2224431-799d1f42c1d801fd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/440)

开始使用RxDataSources的最简单方法是使用SectionModel或AnimatableSectionModel的通用类型作为您的section的类型。 因为你想要动画的项目，你可以使用 AnimatableSectionModel.。 您可以通过简单地指定section信息和项目数组的类型来使用通用类。

打开TasksViewModel.swift并将其添加到顶部：

```swift
typealias TaskSection = AnimatableSectionModel<String, TaskItem>
```

这将您的section类型定义为具有String类型的section模型（您只需要一个标题），并将section内容定义为TaskItem元素的数组。

RxDataSources的唯一约束是，section中使用的每个类型都必须符合IdentifiableType和Equatable协议。 IdentifiableType声明一个唯一的标识符（在同一具体类型的对象中是唯一的），以便RxDataSources唯一标识对象。 Equatable允许它比较对象来检测相同唯一对象的两个副本之间的变化。

Realm对象已经符合Equatable协议（参见下面的注意事项）。 现在，您只需要将TaskItem声明为符合IdentifiableType。 打开TaskItem.swift并添加以下扩展名：

```swift
extension TaskItem: IdentifiableType {
  var identity: Int {
    return self.isInvalidated ? 0 : uid
  }
}
```

该代码通过Realm数据库检查对象的有效性。 删除任务时会发生这种情况; 任何以前从数据库中查询的活动副本都将无效。

```
Note：在您的情况下，更改检测有点挑战性，因为Realm对象是类类型，而不是值类型。 对数据库的任何更新立即反映在对象属性中，这使得RxDataSources的比较变得困难。 事实上，Realm的Equatable协议的实现很快，因为它只检查两个对象是否引用相同的存储对象。 有关此特定问题的解决方案，请参阅下面的“任务单元”部分。
```

现在，您需要将您的任务列表公开为observable。 您将使用TaskService的任务observable，感谢RxRealm，在任务列表中发生更改时会自动发出。 您的目标是分离任务列表，如下所示：

- Due（未选中）任务，先按最后添加排序
- Done（已检查）任务，按检查数据排序（最后检查）

将其添加到TasksViewModel类中：

```Swift
var sectionedItems: Observable<[TaskSection]> {
  return self.taskService.tasks()
    .map { results in
      let dueTasks = results
        .filter("checked == nil")
        .sorted(byKeyPath: "added", ascending: false)
      let doneTasks = results
        .filter("checked != nil")
        .sorted(byKeyPath: "checked", ascending: false)
      return [
        TaskSection(model: "Due Tasks", items: dueTasks.toArray()),
        TaskSection(model: "Done Tasks", items: doneTasks.toArray())
      ]
  }
}
```

通过返回一个包含两个TaskSection元素的数组，您用两个sections自动创建一个列表。

现在到TasksViewController。 这里会发生一些有趣的操作，将sectionedable observable绑定到表格视图。 第一步是创建适合与RxDataSources一起使用的数据源。 对于表格视图，它可以是以下之一：

-  RxTableViewSectionedReloadDataSource<SectionType>
-  RxTableViewSectionedAnimatedDataSource<SectionType>

 Reload类型不是很先进。 当section observable订阅发出一个新的sections列表,，它只是重新加载表。

动画类型是您想要的。 它不仅执行局部重载，还可以动画化每个变化。 将以下dataSource属性添加到TasksViewController类中：

```swift
let dataSource = RxTableViewSectionedAnimatedDataSource<TaskSection>()
```

与RxCocoa支持的内置表格视图的主要区别是您设置数据源对象来显示每个单元格类型，而不是在订阅中执行。

在TasksViewController中，添加一个函数到数据源的“skin”：

```swift
fileprivate func configureDataSource() {
  dataSource.titleForHeaderInSection = { dataSource, index in
    dataSource.sectionModels[index].model
  }
  dataSource.configureCell = {
    [weak self] dataSource, tableView, indexPath, item in
    let cell = tableView.dequeueReusableCell(withIdentifier:
      "TaskItemCell", for: indexPath) as! TaskItemTableViewCell
    if let strongSelf = self {
      cell.configure(with: item, action:
        strongSelf.viewModel.onToggle(task: item))
    }
    return cell
  }
}
```

正如您在第18章“RxCocoa Data Sources”中学到的，当将observable绑定到表格或集合视图时，您可以根据需要提供闭包来生成和配置每个单元格。 RxDataSources的工作方式相同，但配置全部在“数据源”对象中执行。

有关此配置代码的一个详细信息是该MVVM架构的关键。 注意您如何将Action传递给配置函数？

传回视图模型，这是您设计处理来至单元格触发动作的方式。

它非常像闭包，除了由视图模型提供的动作，视图控制器限制将单元格与动作连接起来的作用。

最后，它的工作原理如下：

![](http://upload-images.jianshu.io/upload_images/2224431-da57b625cfadc305.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/440)

有趣的部分是，除了将动作分配给其按钮（见下文）之外，单元本身不必了解视图模型本身的任何内容。

```
NOTE：titleForHeaderInSection闭包返回字符串作为section headers的标题。 这是创建section headers的最简单的例子。 如果您想要更详细定制的内容，可以通过设置dataSource.supplementaryViewFactory来为UICollectionElementKindSectionHeader类返回一个适当的UICollectionReusableView来进行配置。
```

由于在viewDidLoad()里设置表格视图为自动高度模式，因此这是完成表格配置的好地方。 RxDataSources的唯一需求是数据源配置必须在绑定observable之前完成。

在 viewDidLoad()中增加：

```swift
configureDataSource()
```

最后，在bindViewModel()函数中，通过它的数据源，将视图模型的sectionedItems observable绑定到表格视图中：

```swift
viewModel.sectionedItems
  .bindTo(tableView.rx.items(dataSource: dataSource))
  .addDisposableTo(self.rx_disposeBag)
```

你完成了第一个控制器！ 您可以对dataSource对象中的每个更改类型使用不同的动画。 现在将它们保留为默认值。

用于在“任务”列表中显示项目的单元格是一个需要关注的情况。 除了使用Action模式将“checkmark toggled”信息转发到视图模型（见上图）之外，还必须处理在显示期间可能会发生更改底层对象（一个Realm对象实例）。

幸运的是，RxSwift可以解决这个问题。 由于存储在Realm数据库中的对象使用动态属性，因此可以使用KVO进行观察。 使用RxSwift，您可以使用 object.rx.observe(class, propertyName)从属性更改创建可观察序列！

### Binding the Task cell 391

您将把这个技术应用到**TaskTableViewCell**。 打开类文件并添加一些内容到 configure(with:action:)方法：

```swift
button.rx.action = action
```

您首先将“toggle checkmark”操作绑定到复选标记按钮。 有关Action模式的更多详细信息，请参阅第19章“操作”。

现在绑定标题字符串和“已检查”状态图像：

```swift
item.rx.observe(String.self, "title")
  .subscribe(onNext: { [weak self] title in
    self?.title.text = title
  })
  .addDisposableTo(disposeBag)
item.rx.observe(Date.self, "checked")
  .subscribe(onNext: { [weak self] date in
    let image = UIImage(named: (date == nil) ? "ItemNotChecked" :
      "ItemChecked")
    self?.button.setImage(image, for: .normal)
  })
  .addDisposableTo(disposeBag)
```

在这里，您可以相应地单独观察这两个属性并更新单元格内容。由于您在订阅时立即收到初始值，您可以确信单元格始终是最新的。

最后，当单元格被表格视图重用时，别忘了处理您的订阅， 不然它会让你大吃一惊！ 添加以下内容：

```swift
override func prepareForReuse() {
  button.rx.action = nil
  disposeBag = DisposeBag()
  super.prepareForReuse()
}
```

这是清理和准备单元格重用的正确方法。 一直非常小心不要留着悬空的订阅！ 在单元格的这个情况下，由于单元格本身被重用，所以您必须小心这一点。

构建并运行应用程序。 您应该可以看到默认的任务列表。 勾选一个，您将看到由RxDataSources的差异引擎自动生成的漂亮动画！

### Editing tasks 392

解决的另一个问题是创建和修改任务。 您要在创建或编辑任务时呈现模态视图控制器，并且操作（如更新或删除）应传回任务列表视图模型。 虽然在这种情况下不是绝对必要的，因为本地可以处理更改，任务列表将自动更新，感谢Realm，重要的是您学习了将信息传递回一系列场景的模式。

实现此目的的主要方法是使用可信的Action模式。 这是计划：

- 准备编辑场景时，在初始化传递一个或多个动作。
- 编辑场景执行其工作，并在退出时执行相应的操作（更新或取消）。
- 呼叫者可以通过不同的动作取决于它的上下文，编辑场景将不会知道差异。 在创建时通过“删除”操作以取消删除操作（或无操作）。

当您将其应用于您自己的应用程序时，您会发现这种模式非常灵活。 在呈现模态场景时，特别有用，也可以传达要通过合成结果集的多个场景的结果。

![](http://upload-images.jianshu.io/upload_images/2224431-39b4f815c6670d65.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/640)

是时候把它付诸实践了。 将以下函数添加到TasksViewModel中：

```swift
func onCreateTask() -> CocoaAction {
  return CocoaAction { _ in
    return self.taskService
      .createTask(title: "")
      .flatMap { task -> Observable<Void> in
        let editViewModel = EditTaskViewModel(task: task,
                                              coordinator: self.sceneCoordinator,
                                              updateAction: self.onUpdateTitle(task: task),
                                              cancelAction: self.onDelete(task: task))
        return self.sceneCoordinator.transition(to:
          Scene.editTask(editViewModel), type: .modal)
    }
  }
}
```

```
Note：由于self是一个结构体，所以action得到了自己的“copy”结构体（由Swift优化为一个引用），没有循环引用 ——没有内存泄漏的风险！ 这就是为什么你在这里看不到[weak self]或[unowned self]，它不适用于值类型。
```

这是您将绑定到任务列表场景右上角的“+”按钮的操作。 这是它的作用：

- 创建一个新的新任务项目。
- 如果创建成功，请实例化一个新的EditTaskViewModel，并与updateAction一起传递，updateAction更新新任务项目的标题以及一个删除任务项目的cancelAction。 由于刚刚创建，所以取消应在逻辑上删除任务。

```
Note：由于Action返回可观察的序列，因此您可以将整个创建编辑过程整合到单个序列中，一旦编辑任务场景关闭，该过程就会完成。 由于一个Action保持锁定状态，直到执行observable完成，所以不可能增加编辑器两被的时间（it is not possible to inadvertently raise the editor twice at the same time.）。 酷！
```

现在将操作绑定到TasksViewController的bindViewModel()函数上的“+”按钮：

```swift
newTaskButton.rx.action = viewModel.onCreateTask()
```

接下来，移动到EditTaskViewModel.swift并填充初始化程序。 将此代码添加到 init(task:coordinator:updateAction:cancelAction:)：

```swift
onUpdate.executionObservables
  .take(1)
  .subscribe(onNext: { _ in
    coordinator.pop()
  })
  .addDisposableTo(disposeBag)
```

```
Note：为了允许大部分代码进行编译，onUpdate和onCancel属性被定义为强制解包的可选值。 您现在可以删除感叹号。
```

上面做了什么？ 除了将onUpdate操作设置为传递给初始化程序的操作之外，它还会在动作执行时预订动作的执行Observables序列，该序列发出新的可观察值。 由于该操作将被绑定到OK按钮，您只能看到它执行一次。 当这种情况发生时，您pop()当前场景，并且场景协调器将关闭它。

对于“取消”按钮，您需要进行不同的操作。 删除现有的onCancel = cancelAction分配; 你会做一些更聪明的事情。

由于初始化程序接收到的操作是可选的，因为调用者在取消时可能没有任何操作，您需要生成一个新的Action。 因此，这将是pop()场景的时机：

```swift
onCancel = CocoaAction {
  if let cancelAction = cancelAction {
    cancelAction.execute()
  }
  return coordinator.pop()
}
```

最后，移动到EditTaskViewController（在EditTaskViewController.swift）类中以完成UI绑定。 将其添加到bindViewModel（）中：

```swift
cancelButton.rx.action = viewModel.onCancel
okButton.rx.tap
  .withLatestFrom(titleView.rx.text.orEmpty)
  .subscribe(viewModel.onUpdate.inputs)
  .addDisposableTo(rx_disposeBag)
```

当用户点击OK按钮时，您需要处理关于UI的所有操作是将文本视图内容传递给onUpdate操作。 您正在利用Action的输入观察者，它可以直接管理值以执行该操作。

构建并运行应用程序。 创建新项目并更新其标题以查看所有操作。

最后一件事就是增加现有的项目。 为此，您需要一个不是临时的新动作；请记住，**除了通过订阅之外，actions必须被引用**，否则将被释放。 如第19章所述，这是一个经常混淆的来源。

在TasksViewModel中创建一个新的惰性变量：

```swift
lazy var editAction: Action<TaskItem, Void> = { this in
  return Action { task in
    let editViewModel = EditTaskViewModel(
      task: task,
      coordinator: this.sceneCoordinator,
      updateAction: this.onUpdateTitle(task: task)
    )
    return this.sceneCoordinator.transition(to:
      Scene.editTask(editViewModel), type: .modal)
  }
}(self)
```

```
注意：由于self是一个结构体，因此不能创建weak或unowned引用。 相反，将self传递给初始化懒惰变量的闭包或函数。
```

现在，在TaskViewController.swift中，您可以在TaskViewController的bindViewModel()中绑定此操作。 加：

```swift
tableView.rx.itemSelected
  .map { [unowned self] indexPath in
    try! self.dataSource.model(at: indexPath) as! TaskItem
  }
  .subscribe(viewModel.editAction.inputs)
  .addDisposableTo(rx_disposeBag)
```

您正在使用dataSource对获取的模型对象与接收到的IndexPath匹配，然后将其导入操作的输入。 简单！

构建并运行应用程序：您现在可以创建和编辑任务！万岁！