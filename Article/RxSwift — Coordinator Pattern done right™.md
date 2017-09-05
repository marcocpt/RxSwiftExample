# RxSwift — Coordinator Pattern done right™

原文链接：https://medium.com/smoke-swift-every-day/rxswift-coordinator-pattern-done-right-c8f123fdf2b2

The blueprint you’ve been looking for.

![img](https://cdn-images-1.medium.com/max/800/1*Srn8TQxUwYbQkicVp7SLxQ.jpeg)

------

*NB: goes hand-in-hand with *[*ViewModel done right*](https://medium.com/@smokeswifteveryday/rxswift-viewmodel-done-right-532c1a6ede2f)* and *[*ViewController done right*](https://medium.com/@smokeswifteveryday/rxswift-viewcontroller-done-right-d2e557e5327)*; they are part of the same whole.*

------

#### In a nutshell

The whole point is to achieve the maximum sacro-saint “separation of concerns”; how can this be if ViewControllers know about the ViewModel they bind to, or if their ViewModel knows about other ViewControllers to navigate to, or both, or more?

This is where the `Coordinator` comes into play: it manages everything that has to do with navigating the app, ranging from the type of transition to binding VCs and VMs together.

The `Coordinator` works with **scenes**; quoting [Florent Pillet](https://medium.com/@fpillet)’s [article](https://slack-files.com/T051G5Y6D-F0HABHKDK-8e9141e191) on the matter:

> Each application screen is a **scene** composed of a (ViewController, ViewModel) pair and gets presented upon request of the ViewModel controlling the current scene (the only exception being, obviously, the first scene displayed by the app).

The `Coordinator` basically is the “God Object”, but not [in the traditional and pejorative sense](https://en.wikipedia.org/wiki/God_object): **it gives life to your application** by combining its different parts that do nothing on their own and are unaware of each other.

As such, the `Coordinator`‘s job is to:

1. play out `**Scene**`**s**…
2. … that are constituted by a **(VM, VC) pair**…
3. … which will be associated together through **a binding protocol**.
4. The `Coordinator` transitions between the scenes’ main VCs via **the routing protocol** it conforms to…
5. … which allows for **several transition types**…
6. … the implementation of which the `Coordinator` will use to **do the routing and expose a completion observable**

#### What must never be in the Coordinator pattern

The `Coordinator` **is injected in every VM** with a pass-by-reference:

1. there is and should be only one coordinator, all VMs point to it: the coordinator is a `class` by necessity, **never a **`**struct**`
2. the `Coordinator` is **never, ever, accessed by anything other than an **`**Action**`** in a **`**ViewModel**`** **apart from the one time in your `AppDelegate`’s `didFinishLaunchingWithOptions` so that it can be initialized

#### Recipe for a robust Coordinator

------

*Disclaimer: the coordinator implementation presented here is heavily inspired/mimics the one presented in the last chapter of the *[*RW RxSwift Book*](https://store.raywenderlich.com/products/rxswift?_ga=2.61807343.2118241427.1503094951-1071237132.1482485533)*.*

As described above, **the **`**Coordinator**`** spans across 6 files.**

------

**File #1: Scenes**

```swift
import Foundation

enum Scene {
  // Sub-group of scenes related to each other
  // E.g.: all scenes part of a login process
  case firstScene(FirstSceneViewModel)
  case secondScene(SecondSceneViewModel)
  
  // Another sub-group of scenes related to each other
  
  // An so on...
}
```

shers

`Scene`s are basically enum cases, each featuring their VM type as an associated value. As such, they are “vehicles” for the brains of what will be displayed to the user (the ViewModel).

Each time you want to create a new one, simply add a case for it.

------

**File #2: Scenes as a (VM, VC) pair**

```swift
import UIKit

extension Scene {
    
    func viewController() -> UIViewController {
        
        switch self {
            
        case .firstScene(let viewModel):
            let nc = UINavigationController(rootViewController: FirstSceneViewController())
            var vc = nc.viewControllers.first as! FirstSceneViewController
            vc.bindViewModel(to: viewModel)
            return nc
            
        case .secondScene(let viewModel):
            var vc = SecondSceneViewController()
            vc.bindViewModel(to: viewModel)
            return vc
        }
    }
}
```



Brains need to be fed by the body, and the body is animated by brains. If the VM is the brains, then the VC is the body. This is how the coordinator “God Object” will spark life into the pair by associating them when calling the `viewController()` method of `Scene` for a particular scene.

- **Because the **`**Coordinator**`**’s transition method will be called with a **`**Scene**`** argument** (which is an enum case with an associated VM, remember?), it has to know which VC it has to bind the transported VM to; **hence the **`**switch**`** statement on the **`**Scene**`** type**
- The binding can occur in different ways: **the **`**firstScene**`** case way of binding happens when you initiate a navigation stack** and need to transition to its root VC. **The **`**secondScene**`** case way of binding is the more common.** It could be a new modal, a new VC pushed on the navigation stack, a child VC, etc. This will have to do with the transition type (see file #5 and #6)
- The VC is returned so that it can be presented in the way you specified by the `Coordinator` (see file #6)

What is this `bindViewModel(to:)` method? I**t is implemented by all of your VCs as they must all conform to the **`**Bindable**`** type protocol **(see file #3)**.**

------

**File #3: the binding protocol**

```swift
import UIKit
import RxSwift

protocol BindableType {
    associatedtype ViewModelType
    
    var viewModel: ViewModelType! { get set }
    
    func bindViewModel()
}

extension BindableType where Self: UIViewController {
    mutating func bindViewModel(to model: Self.ViewModelType) {
        viewModel = model
        loadViewIfNeeded()
        bindViewModel()
    }
}
```



**All VCs must conform to **`**BindableType**`**, which means:**

- each VC must feature a `var viewModel`, the type of which will be the protocol conformed to by the VM from the (VM, VC) pair *[NB: *`*associatedtype*`* is just a placeholder type needed to create a generic protocol, you could call it whatever you want — it doesn’t matter. It will be replaced at runtime by the type of the *`*var viewModel*`* for the particular controller your want to present]*
- each VC must implement a `bindViewModel()` func that will set up the VC’s bindings to the VM’s inputs, outputs and actions.

**The **`**BindableType**`** protocol features a default implementation which is used in the File #2 to hook up the VM and the VC:** it injects the `Scene`’s transported VM into the VC’s `var viewModel` , loads the view (if not already loaded) so that the initial UI is ready to be updated by an initial output from the VM if any, and finally makes the VC bind to the transported VM.

*NB2: the default method is marked *`*mutating*`* because*`*BindableType*`* isn’t restricted to classes, just to make it as generic as possible; oddly enough, the compiler will complain if you remove it despite the type restriction in the *`*where*`* clause which is clearly a reference type*

------

**File #4: **`**SceneCoordinatorType**`** routing protocol**

```swift
import UIKit
import RxSwift

protocol SceneCoordinatorType {
    init(window: UIWindow)
    
    var currentViewController: UIViewController { get }
    
    @discardableResult
    func transition(to scene: Scene, type: SceneTransitionType) -> Observable<Void>
    
    // pop scene from navigation stack or dismiss current modal
    @discardableResult
    func pop(animated: Bool) -> Observable<Void>
    
    @discardableResult
    func popToRoot(animated: Bool) -> Observable<Void>
    
    @discardableResult
    func popToVC(_ viewController: UIViewController, animated: Bool) -> Observable<Void>
}
```



This is the routing protocol the `Coordinator` will conform to.

From top to bottom:

- **the **`**Coordinator**`** is attached to a window**; in almost all cases, this will be the main one because your app will only have one
- **the **`**Coordinator**`** always keeps track of the current VC**; the first one will be a dummy VC (its only purpose will be to init your `Coordinator`) set up as the `window.rootViewController! `in`AppDelegate` right before your perform your first transition of type `.root` — see Files #5 & 6
- the funcs are what your coordinator will implement to transition between `Scene`s

------

**File #5: transition types**

```swift
import UIKit

enum SceneTransitionType {
    case root                       
    case push(animated: Bool)       
    case modal(animated: Bool)
  
    // Add custom transtion types...
    case pushToVC(stackPath: [UIViewController], animated: Bool)
}
```



Again, `SceneTransitionType`s basically are enum cases, each featuring their transition parameters types as an associated value.

Each time you want to create a new one, simply add a case for it.

------

**File #6: **`**SceneCoordinator**`**: the (good) God Object**

You now have everything you need to [meet and study the God Object](https://gist.github.com/Herakleis/9ca4676b1f1496553bd5d0fd93145889) (it’s a bit big for embedding here).

#### How and Where to use it

Two cases: initialization (a one-off in the `AppDelegate)` and transitioning between `Scene`s.

**Case #1: initialization**

```swift
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Manually creates the window and makes it visible.
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = UIViewController() // Dummy VC for Coordinator's init
        
        let sceneCoordinator = SceneCoordinator(window: window!)
        let firstSceneViewModel = FirstSceneViewModel(coordinator: sceneCoordinator)
        let firstScene = Scene.firstScene(firstSceneViewModel)
        
        sceneCoordinator.transition(to: firstScene, type: .root)
        return true
    }
}
```



The `Coordinator` needs to be initialized with a window that has a root VC, which is why we are creating the dummy one here before immediately transitioning to our first scene with a transition type of `.root`, making it the new window root VC.

**Case #2: every other case**

```swift
lazy var pushScene: CocoaAction = {
    
    return Action { [weak self] in
        guard let strongSelf = self else { return .empty() }
        // The ViewModel is created and its dependencies are injected
        let newSceneViewModel = NewSceneViewModel(service: NewSceneService(), coordinator: strongSelf.coordinator)
        // A reference to the corresponding scene is created to be passed to the coordinator
        let newScene = Scene.newScene(newSceneViewModel)
        
        // The coordinator calls the specified transition function and returns an Observable<Void>
        // that will complete once the transition is made (one `Void` element will be pushed onto the
        // Observable)
        return strongSelf.coordinator.transition(to: newScene, type: .push(animated: true))
    }
}()
```



Somewhere in your VM you will have something like (here, as a push on a navigation stack):

For a contextualized example please refer to the [ViewModel done right](https://medium.com/@smokeswifteveryday/rxswift-viewmodel-done-right-532c1a6ede2f) gist at the bottom. To see how the action connects in the ViewController, please refer to [ViewController done right](https://medium.com/@smokeswifteveryday/rxswift-viewcontroller-done-right-d2e557e5327).

------

#### **Room for improvement:**

- Incorporate the `pop` funcs in the scene transition type as enum cases to get a unified API
- Anything else?