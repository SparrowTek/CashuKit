//
//  CashuEnvironment.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/27/25.
//

@CashuActor
class CashuEnvironment {
    static var current: CashuEnvironment = .init()
    var baseURL: String?
    let routerDelegate = CashuRouterDelegate()
    
    private init() {}
    
    func setup(baseURL: String) {
        self.baseURL = baseURL
    }
}

