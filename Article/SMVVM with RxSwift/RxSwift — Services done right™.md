# RxSwift — Services done right™

原文链接：https://medium.com/smoke-swift-every-day/rxswift-services-done-right-dd1646c0ecd2

The blueprint you’ve been looking for.

![img](https://cdn-images-1.medium.com/max/800/1*E4NZ70jRNBAdK7S42LKurA.jpeg)

------

*NB: goes hand-in-hand with *[*ViewModel done right*](https://medium.com/@smokeswifteveryday/rxswift-viewmodel-done-right-532c1a6ede2f)*; the two are part of the same whole.*

------

#### In a nutshell

In order to get its job done, the ViewModel will transform some inputs into outputs.

**As such, it should be focused on the “What”; not the “How”.** This means that a ViewModel is much like an assembly line combining various building blocks into a product. **A ViewModel is a process.**

Services represent a lower level layer that provides just that: atomic building blocks for the ViewModel to consume and manipulate.

They are divided into 2 categories:

- **#1 “Helper **`**struct**`**s services”**: specific to a certain `Scene` ViewModel type, pretty much a container for its “neurons” — useless on their own, powerful if interconnected in the brain *[NB: if you don’t know what a *`*Scene*`* is, check out *[*Coordinator pattern done right*](https://medium.com/smoke-swift-every-day/rxswift-coordinator-pattern-done-right-c8f123fdf2b2)*]*
- **#2 “Base singletons services”**: common to several services of the former type and the only place in your app to interface with the platform-specific implementations (typically, a database provider)

#### What should never be in a Service

It’s simple.

1. [**There is only one way to create a singleton in Swift**](https://medium.com/smoke-swift-every-day/singletons-in-swift-502f262a1afc): never create a service of type #2 in a different form
2. **Services of type #2 are never, EVER consumed by anybody else than a service of type #1: **they are the boundary between your possibly changing provider (below them) and the way you interface with it regardless of what it is (above them, i.e. services of type #1)
3. **Services of type #1 are always structs that never mutate themselves**: all state should be handled by the ViewModel in a appropriate way through stateful operators/subjects
4. **An absence of an interface protocol:** as in many other cases, properties that reference services will be of the type of the protocol they conform to

#### Recipe for robust Services layers

The only place your services of type #1 are consumed in your app is in a ViewModel.

As such, **the only way to initialize a service of type #1 and make it available for use by a ViewModel is through dependency injection** *[like in *[*ViewModel done right*](https://medium.com/@smokeswifteveryday/rxswift-viewmodel-done-right-532c1a6ede2f)*] ***when the **`**Scene**`** it corresponds to it being created through the **`**Coordinator**`** ***[*[*see Coordinator pattern done right, “How and Where to use it”*](https://medium.com/smoke-swift-every-day/rxswift-coordinator-pattern-done-right-c8f123fdf2b2)*].*

------

**Service of type #1**

```swift
import RxSwift

protocol MyViewModelServiceType {
    func observeCurrentNumberOfFriendRequests() -> Observable<Int>
}

struct MyViewModelService: MyViewModelServiceType {
    
    private let usersBaseService = UsersBaseService.shared
    
    init() {
        // implement mock case for testing
    }
    
    func observeCurrentNumberOfFriendRequests() -> Observable<Int> {
        return usersBaseService.observeCurrentFriendRequests()
            .map { friendRequestsResult in
                switch friendRequestsResult {
                case .success(let userIds):
                    return userIds.count
                case .failure:
                    return 0
                }
        }
    }
}
```



This service is simple: when the ViewModel calls the `observeCurrentNumberOfFriendRequests()` method on its `MyViewModelService` instance, it will in turn make a call to a method on the `UserBaseService` of type #2 and map its result to expose an `Observable<Int>` that the ViewModel will consume to produce some output.

------

**Service of type #2**

```swift
import RxSwift

protocol UsersBaseServiceType {
    func observeCurrentFriendRequests() -> Observable<YourDatabaseResultType>
}

final class UsersBaseService {
    
    static let shared = UsersBaseService()
    
    fileprivate let usersProvider = YourDatabaseProvider()
    
    private init() { }
}

extension UsersBaseService: UsersBaseServiceType {
    
    func observeCurrentFriendRequests() -> Observable<YourDatabaseResultType> {
        // Your implementation with your specific usersProvider
    }
}
```



Here `YourDatabaseResultType` is of the form `Result<T, Error>` in order to gracefully handle the various errors your might get without terminating the sequence (especially important when you use websockets/database observers) *[NB: you can find a good generic library for *`*Result*`* types *[*here*](https://github.com/antitypical/Result)* ]*