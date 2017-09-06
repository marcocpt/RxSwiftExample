//: # Chapter_2_Observables

//: [Previous](@previous) - [Table of Contents](Table_of_Contents)
import RxSwift

example(of: "just, of, from") {
    
    // 1
    let one = 1
    let two = 2
    let three = 3
    
    // 2
    let observable: Observable<Int> = Observable<Int>.just(one)
    let observable2 = Observable.of(one, two, three)
    let observable3 = Observable.of([one, two, three])
    let observable4 = Observable.from([one, two, three])
}

let observer = NotificationCenter.default.addObserver(
    forName: .UIKeyboardDidChangeFrame,
    object: nil,
    queue: nil
) { notification in
    // Handle receiving notification
}


example(of: "subscribe") {
    let one = 1
    let two = 2
    let three = 3
    let observable = Observable.of(one, two, three)
    observable.subscribe(onNext: { (element) in
        print(element)
    })
}

example(of: "empth") {
    let observable = Observable<Void>.empty()
    observable.subscribe(onNext: { (element) in
        print(element)
    }, onCompleted: {
        print("Completed")
    })
}

example(of: "never") {
    let observable = Observable<Any>.never()
    let disposeBag = DisposeBag()
    observable
        .do(onSubscribe: {
            print("Subscribed")
        })
        .subscribe(onNext: { (element) in
            print(element)
        }, onCompleted: {
            print("Completed")
        }, onDisposed: {
            print("Disposed")
        })
        .addDisposableTo(disposeBag)
}

example(of: "range") {
    // 1
    let observable = Observable<Int>.range(start: 1, count: 10)
    observable
        .subscribe(onNext: { i in
            // 2
            let n = Double(i)
            let fibonacci = Int(((pow(1.61803, n) - pow(0.61803, n)) /
                2.23606).rounded())
            print(fibonacci)
        })
}

example(of: "dispose") {
    // 1
    let observable = Observable.of("A", "B", "C")
    // 2
    let subscription = observable.subscribe { event in
        // 3
        print(event)
    }
    subscription.dispose()
}

example(of: "DisposeBag") {
    // 1
    let disposeBag = DisposeBag()
    // 2
    Observable.of("A", "B", "C")
        .subscribe { // 3
            print($0)
        }
        .addDisposableTo(disposeBag) // 4
}


example(of: "create") {
    
    enum MyError: Error {
        case anError
    }
    
    let disposeBag = DisposeBag()
    Observable<String>.create { observer in
        // 1
        observer.onNext("1")
        //        observer.onError(MyError.anError)
        // 2
        observer.onCompleted()
        // 3
        observer.onNext("?")
        // 4
        return Disposables.create()
        }.subscribe(
            onNext: { print($0) },
            onError: { print($0) },
            onCompleted: { print("Completed") },
            onDisposed: { print("Disposed") }
        )
        .addDisposableTo(disposeBag)
}

example(of: "deferred") {
    let disposeBag = DisposeBag()
    // 1
    var flip = false
    // 2
    let factory: Observable<Int> = Observable.deferred {
        // 3
        flip = !flip
        // 4
        if flip {
            return Observable.of(1, 2, 3)
        } else {
            return Observable.of(4, 5, 6)
        }
    }
    for _ in 0...3 {
        factory.subscribe(onNext: {
            print($0, terminator: "")
        })
            .addDisposableTo(disposeBag)
        print()
    }
}

//: [Next](@next) - [Table of Contents](Table_of_Contents)
