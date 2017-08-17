//
//  UserAPI.swift
//  RxSwiftMoya
//
//  Created by monkey on 2017/3/29.
//  Copyright © 2017年 Coder. All rights reserved.
//

import Foundation
import Moya
//stubClosure: MoyaProvider.immediatelyStub表示使用本地mock数据
//然后使用生成的RxMoyaProvider对象发起请求
let UserProvider = RxMoyaProvider<UserAPI>(stubClosure: MoyaProvider.immediatelyStub)

enum UserAPI{
    case list(Int,Int)
}

extension UserAPI : TargetType{
     /// The target's base `URL`.
    var baseURL : URL{
        return URL(string: "http://www.alonemonkey.com")!
    }
    /// The path to be appended to `baseURL` to form the full `URL`.
    var path: String{
        switch self {
        case .list:
            return "userlist"
        }
    }
    /// The HTTP method used in the request.
    var method: Moya.Method{
        switch self {
        case .list:
            return .get
        }
    }
    /// The parameters to be encoded in the request.
    var parameters: [String: Any]?{
        switch self{
        case .list(let start, let size):
            return ["start": start, "size": size]
        }
    }
    /// The method used for parameter encoding.
    var parameterEncoding: ParameterEncoding{
        return URLEncoding.default
    }
    /// The type of HTTP task to be performed.
    var task: Task{
        return .request
    }
    /// Provides stub data for use in testing.
    var sampleData: Data{
        switch self {
        case .list(_, _):
            if let path = Bundle.main.path(forResource: "UserList", ofType: "json") {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                    return data
                } catch let error {
                    print(error.localizedDescription)
                }
            }
            return Data()
        }
    }
}
