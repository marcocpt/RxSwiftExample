//
//  Response+ObjectMapper.swift
//  RxSwiftMoya
//
//  Created by monkey on 2017/3/29.
//  Copyright © 2017年 Coder. All rights reserved.
//

import Foundation
import Moya
import ObjectMapper
import Moya_ObjectMapper

enum AMError: Swift.Error {
    case ParseResultError(Status)
}

extension AMError: LocalizedError {
    public var message: String? {
        switch self {
        case .ParseResultError(let status):
            return status.message
        }
    }
}

public extension Response {
    public func mapResult<T: BaseMappable>(_ type: T.Type, context: MapContext? = nil) throws -> [T] {
        
        let status = try mapObject(Status.self)
        
         guard let array = status.result as? [[String : Any]] else {
            throw AMError.ParseResultError(status)
        }
        let objects = Mapper<T>(context: context).mapArray(JSONArray: array)
      
        return objects
    }
}
