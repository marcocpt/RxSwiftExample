//: # Chapter 3: Subjects

//: [Previous](@previous) - [Table of Contents](Table_of_Contents)
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

import RxSwift

/*:
 Subject 可以看做是一种代理和桥梁。它既是订阅者又是订阅源，这意味着它既可以订阅其他 Observable 对象，同时又可以对它的订阅者们发送事件。
 
 如果把 Observable 理解成不断输出事件的水管，那 Subject 就是套在上面的水龙头。它既怼着一根不断出水的水管，同时也向外面输送着新鲜水源。如果你直接用水杯接着水管的水，那可能导出来什么王水胶水完全把持不住；如果你在水龙头下面接着水，那你可以随心所欲的调成你想要的水速和水温
 */

//: ## PublishSubject 
//: 会发送订阅者从订阅之后的事件序列
example(of: "PublishSubject") {
    let subject = PublishSubject<String>()
    subject.onNext("Is anyone listening?")
    
    let subscriptionOne = subject
        .subscribe(onNext: { string in
            print(string)
        })
    subject.on(.next("1"))
    subject.onNext("2")
    
    let subscriptionTwo = subject
        .subscribe { event in
            print("2)", event.element ?? event)
    }
    subject.onNext("3")
    subscriptionOne.dispose()
    subject.onNext("4")
    
    // 1
    subject.onCompleted()
    // 2
    subject.onNext("5")
    // 3
    subscriptionTwo.dispose()
    let disposeBag = DisposeBag()
    // 4
    subject
        .subscribe {
            print("3)", $0.element ?? $0)
        }
        .addDisposableTo(disposeBag)
    subject.onNext("?")
}

//: ## BehaviorSubject
//: 在新的订阅对象订阅的时候会发送最近发送的事件，如果没有则发送一个默认值。
// 1
enum MyError: Error {
    case anError
}
// 2
func print<T: CustomStringConvertible>(label: String, event: Event<T>) {
    print(label, event.element ?? event.error ?? event)
}
// 3
example(of: "BehaviorSubject") {
    // 4
    let subject = BehaviorSubject(value: "Initial value")
    let disposeBag = DisposeBag()
    subject
        .subscribe {
            print(label: "1)", event: $0)
        }
        .addDisposableTo(disposeBag)
    subject.onNext("X")
    // 1
    subject.onError(MyError.anError)
    // 2
    subject
        .subscribe {
            print(label: "2)", event: $0)
        }
        .addDisposableTo(disposeBag)
}

//: ## ReplaySubject 
//: 在新的订阅对象订阅的时候会补发所有已经发送过的数据队列， bufferSize 是缓冲区的大小，决定了补发队列的最大值。如果 bufferSize 是1，那么新的订阅者出现的时候就会补发上一个事件，如果是2，则补两个，以此类推。
example(of: "ReplaySubject") {
    // 1
    let subject = ReplaySubject<String>.create(bufferSize: 2)
    let disposeBag = DisposeBag()
    // 2
    subject.onNext("1")
    subject.onNext("2")
    subject.onNext("3")
    // 3
    subject
        .subscribe {
            print(label: "1)", event: $0)
        }
        .addDisposableTo(disposeBag)
    subject
        .subscribe {
            print(label: "2)", event: $0)
        }
        .addDisposableTo(disposeBag)
    subject.onNext("4")
    subject.onError(MyError.anError)
    subject.dispose()
    subject
        .subscribe {
            print(label: "3)", event: $0)
        }
        .addDisposableTo(disposeBag)
}

//: ## Variable 
//: 是基于 BehaviorSubject 的一层封装，它的优势是：不会被显式终结。即：不会收到 .Completed 和 .Error 这类的终结事件，它会主动在析构的时候发送 .Complete 。
example(of: "Variable") {
    // 1
    var variable = Variable("Initial value")
    let disposeBag = DisposeBag()
    // 2
    variable.value = "New initial value"
    // 3
    variable.asObservable()
        .subscribe {
            print(label: "1)", event: $0)
    }
    //        .addDisposableTo(disposeBag)
    // 1
    variable.value = "1"
    // 2
    variable.asObservable()
        .subscribe {
            print(label: "2)", event: $0)
        }
        .addDisposableTo(disposeBag)
    // 3
    variable.value = "2"
}
//: [Next](@next) - [Table of Contents](Table_of_Contents)
