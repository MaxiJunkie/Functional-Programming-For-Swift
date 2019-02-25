//
//  AuthorizationMonad.swift
//  THT-Premier
//
//  Created by Максим Стегниенко on 21/02/2019.
//  Copyright © 2019 Finch. All rights reserved.
//

final class AuthorizationMonad {
  
    // MARK: - Typealias
    
    typealias Monad = (RequestFunctor<AuthorizationEndpoint, Login>) -> (RequestFunctor<AuthorizationEndpoint, AuthResult>) -> ()
    typealias Requests = (first: RequestFunctor<AuthorizationEndpoint, LoginRoute>,
        second: RequestFunctor<AuthorizationEndpoint, Login>,
        third: RequestFunctor<AuthorizationEndpoint, AuthResult>)
    
    
    // MARK: - Private properties
    
    private let requests: Requests
    
    
    // MARK: - Init
    
    init(requests: Requests) {
        self.requests = requests
    }
    
    
    // MARK: - Public methods
    
    func runSequence(with loginRouteRequest: RequestFunctor<AuthorizationEndpoint, LoginRoute>) -> Monad {
        
        loginRouteRequest.runRequest(cachingEnabled: true)
        
        return { loginRequest in
            
            loginRequest.runRequest(cachingEnabled: true)
            
            return { authResult in
                
                authResult.runRequest(cachingEnabled: true)
                
            }
            
        }
        
    }
    
}
