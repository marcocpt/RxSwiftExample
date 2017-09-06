import RxSwift
import Action

enum SceneStateOutput {
    case idle
    case sendingNoRecipient
    case sendingSomeRecipients(sendingList: [String: String])
    case sending
}

protocol SceneViewModelInputsType {
    var updateUploadList: PublishSubject<(id: String, parameter: String)> { get }
    var fromAnotherScene: PublishSubject<AnotherSceneViewModelType> { get }
}

protocol SceneViewModelOutputsType {
    var state: Observable<SceneStateOutput> { get }
    var dataSource: Observable<[Item]> { get }
}

protocol SceneViewModelActionsType {
    var pushAnotherScene: CocoaAction { get }
    var uploadStuff: Action<Void, DatabaseWriteResult> { get }
}

protocol SceneViewModelType {
    var inputs: SceneViewModelInputsType { get }
    var outputs: SceneViewModelOutputsType { get }
    var actions: SceneViewModelActionsType { get }
}

final class SceneViewModel: SceneViewModelType {
    
    var inputs: SceneViewModelInputsType { return self }
    var outputs: SceneViewModelOutputsType { return self }
    var actions: SceneViewModelActionsType { return self }
    
    // Setup
    private let sceneService: SceneServiceType
    private let coordinator: SceneCoordinatorType
    private let disposeBag: DisposeBag
    
    // Inputs
    var updateUploadList: PublishSubject<(id: String, parameter: String)>
    var fromAnotherScene: PublishSubject<AnotherSceneViewModelType>
    
    // Outputs
    var state: Observable<SceneStateOutput>
    var dataSource: Observable<[Item]>
    
    // ViewModel Life Cycle
    private let itemsForDataSource: Variable<[Item]>
    private let stuffToSend: Variable<Stuff?>
    private let sendingList: Variable<[String: String]>
    private let isSendingStuff: Variable<Bool>
    
    init(service: SceneServiceType, coordinator: SceneCoordinatorType) {
        // Setup
        self.sceneService = service
        self.coordinator = coordinator
        self.disposeBag = DisposeBag()
        self.itemsForDataSource = Variable([])
        self.stuffToSend = Variable(nil)
        self.sendingList = Variable([:])
        self.isSendingStuff = Variable(false)
        
        // Inputs
        updateUploadList = PublishSubject()
        fromAnotherScene = PublishSubject()
        
        // Outputs
        state = Observable
            .combineLatest(
                stuffToSend.asObservable(),
                sendingList.asObservable(),
                isSendingStuff.asObservable(),
                resultSelector: {( (stuffToSend: $0.0,
                                    sendingList: $0.1,
                                    isSendingStuff: $0.2)
                                )}
            )
            .map { stuffToSend, sendingList, isSendingStuff -> SceneStateOutput in
                guard stuffToSend != nil else { return .idle }
                guard !sendingList.isEmpty else { return .sendingNoRecipient }
                guard isSendingStuff else { return .sendingSomeRecipients }
                return .sending
            }
            .shareReplay(1)
        
        dataSource = itemsForDataSource.asObservable()
        
        // ViewModel Life Cycle
        let fetchItems = sceneService
            .fetchItems()
            .startWith([])
        
        Observable.combineLatest(fetchItems, state)
            .map { items, state in
                let updatedItems = items.flatMap { item -> Item in
                    switch state {
                    case .sendingModeNoRecipient:
                        item.bool = true
                        item.parameter = nil
                    case .sendingModeSomeRecipients(let sendingList):
                        item.bool2 = true
                        item.parameter = sendingList[item.id]
                    case .sending:
                        item.bool2 = false
                    default:
                        item.bool = true
                        item.bool2 = false
                        item.parameter = nil
                    }
                    return item
                }
                return updatedItems
            }
            .bind(to: itemsForDataSource)
            .disposed(by: disposeBag)
        
        fromAnotherScene
            .flatMapLatest { $0.actions.getStuff..execute() }
            .bind(to: stuffToSend)
            .disposed(by: disposeBag)
        
        updateUploadList
            .subscribe(onNext: { [unowned self] with in
                self.sendingList.value[with.id] = with.parameter
            })
            .disposed(by: disposeBag)
        
        uploadStuff.executing
            .bind(to: isSendingStuff)
            .disposed(by: disposeBag)
        
        uploadStuff.elements
            .filter { $0 == .success }
            .subscribe(onNext: { [unowned self] _ in
                self.stuffToSend.value = nil
                self.sendingList.value = [:]
            })
            .disposed(by: disposeBag)
    }
    
    // Actions
    lazy var pushAnotherScene: CocoaAction = {
        return Action { [weak self] in
            guard let strongSelf = self else { return .empty() }
            let anotherSceneViewModel = AnotherSceneViewModel(
                service: AnotherSceneService(),
                coordinator: strongSelf.coordinator)
            let anotherScene = Scene.anotherScene(anotherSceneViewModel)
            return strongSelf.coordinator.transition(to: anotherScene, type: .push(animated: true))
        }
    }()
    
    lazy var uploadStuff: Action<Void, DatabaseWriteResult> = {
        return Action { [weak self] in
            guard let strongSelf = self else { return .empty() }
            let stuffStream = strongSelf.stuffToSend.asObservable().unwrap().take(1)
            let sendingListStream = strongSelf.sendingList.asObservable().filter { !$0.isEmpty }.take(1)
            
            return Observable.zip(stuffStream, sendingListStream)
                .flatMap { [weak self] stuff, sendingList -> Observable<DatabaseWriteResult> in
                    guard let strongSelf = self else { return .empty() }
                    return strongSelf.sceneService.sendStuff(stuff, to: sendingList)
                }
                .take(1)
        }
    }()
}

extension SceneViewModel: SceneViewModelInputsType, SceneViewModelOutputsType, SceneViewModelActionsType { }