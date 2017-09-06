# SMVVM with RxSwift

原文链接：https://medium.com/smoke-swift-every-day/smvvm-with-rxswift-b3c1e00ca9b

A tale of a modern architecture for modern mobile applications.

![img](https://cdn-images-1.medium.com/max/800/1*UvC8a39DwOwiDcFg_ZP1Ew.jpeg)

#### The legend

Once upon a time on planet Program-1NG, our ancestors had to fight off the Asynchronous Dragon, Master of Time, which lived near the Pyramid of Doom in the barren lands of Callback Hell. His castle of **M**assive-**V**iew-**C**ontroller-on-the-Sea was heavily guarded by its most loyal minions: the Lady of Unresponsive-UI, the Prince of Race Conditions and the Clutter Monster. As the battle raged, day and night, for years, slowly driving our forefathers into insanity from exhaustion, a beacon of hope surfaced at the horizon.

![img](https://cdn-images-1.medium.com/max/800/1*B3_hfeJErL2H0Ew1f9uJjw.jpeg)His Holiness St. RX the First (Erik Meijer)

Seemingly out of nowhere, wielding a tremendous power, a wizard had appeared and handed enchanted weapons to our brave and relentless predecessors: the Sword of Observables, the Mønäd Hammer and the Functional Reactive Armor.

Easily defeating the Asynchronous Dragon, our ancestors studied the unlimited source of mightiness that was now at the cusp of their hands and proceeded to spread the Good Word and forge their own weapons, inspired by the Reactive Trinity; for when the Dragon would come back around, they and their children shall be ready.

#### SMVVM WTF

It’s not just another name for the sake of it; frankly, you could call it whatever you want. The point is to present a style of MVVM architecture that helps write clean and testable code with the sacro-saint “separation of concerns” at heart.

True, it might seem at times like overkill/waste of time when you spend 15mins just setting things up for the new screen you will be working on. Rest assured: **you will save 100x that amount in the future when debugging or trying to figure out how to add a new feature**.

![img](https://cdn-images-1.medium.com/max/800/1*e7YjXvN9A3QXyuICwubBHg.jpeg)This is basically SMVVM.

In a nutshell, SMVVM (or, you know, whatever) features:

1. **ViewControllers/Views: that’s the first “V”. **They will be the link between your user and the ViewModel. Basically the steering wheel and pedals of your app: they collect user input (location and speed) to be transmitted to the system and organise displaying the information through a windshield.

   **ViewControllers/Views是第一个"V"**.它们把用户和ViewModel链接起来。就像你app的方向盘和踏板：它们采集了用户的输入（位置和速度）），传递给系统并组装起来通过面板显示信息。

2. **ViewModels: that’s the “VM” at the end. **Arguably the most important part of the architecture pattern. The ViewModel is basically the engine and wheels of your app: it connects and transforms both inputs from the user as well as from other parts of the system inaccessible to him/her in order to produce outputs that will ultimately, one way or another, be displayed on his/her windshield.

   **ViewModels: 它是结尾处的“VM”。**这个结构范式无可争论的最重要的部分。ViewModel相当于你app的引擎和车轮：它连接和转换来自用户的输入，以及系统的其他部分不可访问的输入，以产生最终以某种方式显示在他/她的面板上的输出。

3. **Services: that’s the “S” at the beginning. **They are all the little mechanical parts (screws, straps, and so on) that support ViewModels by providing them the “building blocks” they need to perform their job. They are divided in two groups: **helper `structs`**, which have a specific use case (i.e., intended for use by a particular ViewModel), **and lower-level “base service” singletons** which are used by multiple higher-level services (typically, networking).

   **Services:它是最开始的“S”。**它们是用来支撑ViewModels的所有小零件（螺丝，绳子等等），为它们提供工作所需的“组装块”。它们被分配为两组：**helper structs**，具有特定的用例（例如：由特定的ViewModel使用），和**底层基于服务的单例**，它用于多种高层服务（通常为网络服务）

4. **Models: that’s the first “M”. **Same as any architecture: this is the core of your app, which will come to life through the ViewModel.

   **模型：它是第一个“M”。**像其他结构一样：这是你app的核心，它通过ViewModel存活。

#### What should it look like?

Magnificent.

1. [ViewControllers](https://medium.com/@smokeswifteveryday/rxswift-viewcontroller-done-right-d2e557e5327)
2. [ViewModels](https://medium.com/@smokeswifteveryday/rxswift-viewmodel-done-right-532c1a6ede2f)
3. [Services](https://medium.com/smoke-swift-every-day/rxswift-services-done-right-dd1646c0ecd2)
4. Models: that’s your job ! (`struct`s by default)
5. [Coordinator](https://medium.com/smoke-swift-every-day/rxswift-coordinator-pattern-done-right-c8f123fdf2b2)