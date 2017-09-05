# RxSwift — ViewController done right™

原文链接：https://medium.com/smoke-swift-every-day/rxswift-viewcontroller-done-right-d2e557e5327

The blueprint you’ve been looking for.

![img](https://cdn-images-1.medium.com/max/800/1*EqmnxFs3cZkvoYMKWzFCFA.jpeg)Exquisite.

------

*NB: goes hand-in-hand with *[*ViewModel done right*](https://medium.com/@smokeswifteveryday/rxswift-viewmodel-done-right-532c1a6ede2f)*; the two are part of the same whole.*

------

#### In a nutshell

The ViewController part is somewhat more opinionated than the ViewModel because this is where the UI bindings/definitions/helpers reside. As usual, **there is no “best” way but some “better” ways **and the sole attempt of this post will be to present what has seemed to work well thus far, with readability, separation of concerns, testability and bugs pinpointing in mind.

#### What should never be in a ViewController

Under any circumstances.

1. **Network calls:** these should live in a service `struct` used by the ViewModel, with the ViewController only getting either a result or an error to handle *[upcoming post on architecting services]*
2. **Data processing:** it should be done in the ViewModel unless it directly relates to a subclass of `UIView` (example: the ViewModel exposes an array of positions and the conversion to frames happens in the ViewController)
3. **UI / helpers implementations:** they should all reside in some dedicated `extension`

#### Recipe for a robust ViewController

A ViewController binds the exposed `Observable` s from the ViewModel to the UI, and features all sorts of side-effects related to them than perform changes to the UI. It is the boundary between what a user can and can’t see.

Let’s take a look at the basic structure and break it down from top to bottom:

```swift
import RxSwift
import RxCocoa
import Action

final class ViewController: UIViewController, BindableType {
    
    // UI Elements
    fileprivate var aButton = ViewController._aButton()
    fileprivate var anotherButton = ViewController._aButton()
    fileprivate let logo = ViewController._logo()
    
    // Data Bindings
    private let disposeBag = DisposeBag()
    var viewModel: ControllerViewModelType!
    
    func bindViewModel() {
        
        aButton.rx.tap
            .bind(to: viewModel.actions.pushFirstScreen.inputs)
            .disposed(by: disposeBag)
        
        anotherButton.rx.action = viewModel.actions.pushSecondScreen
    }
    
    // Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIApplication.shared.isStatusBarHidden = true
        navigationController?.navigationBar?.isHidden = true
    }
}

// MARK: Helpers

// MARK: UI Elements
extension ViewController {
    
    fileprivate func setupViews() {
        
        view.backgroundColor = .blue
        
        // MARK: Logo setup
        view.addSubview(logo)
        logo.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        logo.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -view.bounds.size.height / 15).isActive = true
        logo.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1/1.7).isActive = true
        logo.heightAnchor.constraint(equalTo: logo.widthAnchor).isActive = true
        
        // MARK: aButton setup
        aButton.setTitle("Hello", for: .normal)
        view.addSubview(aButton)
        aButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: view.bounds.size.height / 20).isActive = true
        aButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -view.bounds.size.height / 16).isActive = true
        aButton.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1/5).isActive = true
        aButton.widthAnchor.constraint(equalTo: aButton.heightAnchor, multiplier: 1/2).isActive = true
        
        // MARK: anotherButton setup
        anotherButton.setTitle("Hi", for: .normal)
        view.addSubview(anotherButton)
        anotherButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -view.bounds.size.height / 20).isActive = true
        anotherButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -view.bounds.size.height / 16).isActive = true
        anotherButton.heightAnchor.constraint(equalTo: aButton.heightAnchor).isActive = true
        anotherButton.widthAnchor.constraint(equalTo: anotherButton.heightAnchor, multiplier: 1/2).isActive = true
    }
    
    class func _logo() -> UIImageView {
        
        let iv = UIImageView()
        
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "logo.png")
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }
    
    class func _aButton() -> UIButton {
        
        let button = UIButton(type: .custom)
        
        button.imageView?.contentMode = .scaleAspectFit
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}
```



1. A ViewController **always conforms to **`**BindableType**`**; if you don’t know why, please refer to **[**Coordinator pattern done right**](https://medium.com/@smokeswifteveryday/rxswift-coordinator-pattern-done-right-c8f123fdf2b2)**. **The two bindings here are basically equivalent: a tap on a button pushes a new scene from the coordinator (the reference to which resides in the ViewModel) and showcase the conciseness allowed by using `Action`
2. **UI elements and initial setup are thrown into their own extension to de-clutter the ViewController’s core.** Because an extension cannot have store properties, UI parts are implemented as `class func` s. The underscores before their names exists simply because the compiler complains otherwise (this might not be the case as of your reading of this post)