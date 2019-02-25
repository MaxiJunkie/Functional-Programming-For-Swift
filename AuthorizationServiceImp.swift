//
//  AuthorizationServiceImp.swift
//  THT-Premier
//
//  Created by Максим Стегниенко on 28/09/2018.
//  Copyright © 2018 Finch. All rights reserved.
//

import Foundation

final class AuthorizationServiceImp {
    
    // MARK: - Private properties
    
    private let networkService: NetworkService<AuthorizationEndpoint>
    private let userService: UserGetterService
    private var monad: AuthorizationMonad?
    
    
    // MARK: - init
    
    init(networkService: NetworkService<AuthorizationEndpoint>, userService: UserGetterService) {
        self.networkService = networkService
        self.userService = userService
    }
    
}


// MARK: - AuthorizationService
extension AuthorizationServiceImp: AuthorizationService {
    
    func replaceDevice(id: String, completion: @escaping ((Result<CommonResult>) -> Void)) {
      
        func checkSession(response: CommonResult, completion: @escaping ((Result<CommonResult>) -> Void)) {
          
            startSession(completion: { result in
                
                switch result {
                    
                case .success:
                    completion(.success(response))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            })
        }
        
        let endpoint = AuthorizationEndpoint.replaceDevice(id: id)
        networkService.request(endpoint: endpoint) { (result: Result<CommonResult>) in
            
            switch result {
                
            case .success(let response):
                checkSession(response: response, completion: completion)
                
            case .failure(let error):
                completion(.failure(error))
                
            }
            
        }
        
    }
    
    func startSession(completion: ((Result<AuthResult>) -> Void)?) {
        
        guard let endpoints = Config.main.endpoints else {
            completion?(.failure(.noBaseUrl))
            return
        }
        
        let loginRouteEndpoint = AuthorizationEndpoint.loginRoute(edsUrl: endpoints.edsUrl)
        let loginRouteAction: (LoginRoute) -> Void = { response in
            guard let domain = URL(string: response.url) else { return }
            Config.main.domain = domain
        }
        
        let actionAfterFailure: (APIError) -> Void = { error in
            completion?(.failure(error))
        }
 
        let loginRouteRequest = RequestFunctor(endpoint: loginRouteEndpoint,
                                               actionAfterSuccess: loginRouteAction,
                                               actionAfterFailure: actionAfterFailure,
                                               networkService: networkService)
        
        let loginEndpoint = AuthorizationEndpoint.login(deviceModel: DeviceModel(model: endpoints.deviceModel),
                                                        baseUrl: Config.main.domain)
        
        let loginAction: (Login) -> Void = { response in
            Config.main.parameters = response.terminalParm.values
        }
        
        let loginRequest = RequestFunctor(endpoint: loginEndpoint,
                                          actionAfterSuccess: loginAction,
                                          actionAfterFailure: actionAfterFailure,
                                          networkService: networkService)
        
        let basic = AuthenticateBasic(user: userService)
        let device = AuthenticateDevice(deviceModel: endpoints.deviceModel)
        let tolerant = AuthenticateTolerant()
        
        let authEndpoint = AuthorizationEndpoint.authenticate(basic: basic,
                                                              device: device,
                                                              tolerant: tolerant,
                                                              baseUrl: Config.main.domain)
        
        let authAction: (AuthResult) -> Void = { response in
            
            Config.main.cSessionId = response.cSessionId
            Config.main.deviceList = response.devices ?? []
            Config.main.sessionId = response.sessionId
            Config.main.subscriberId = response.subscriberId
            SessionStorage.authToken = response.userToken
            AuthManager.shared.username = response.username
            
            completion?(.success(response))
        }
        
        let authRequest = RequestFunctor(endpoint: authEndpoint,
                                         actionAfterSuccess: authAction,
                                         actionAfterFailure: actionAfterFailure,
                                         networkService: networkService)
       
        let requests = (first: loginRouteRequest, second: loginRequest, third: authRequest)
        monad = AuthorizationMonad(requests: requests)
        monad?.runSequence(with: loginRouteRequest)(loginRequest)(authRequest)
   
    }
    
    func logout(completion: ((Result<AuthResult>) -> Void)?) {
        
        let endpoint = AuthorizationEndpoint.logout(baseUrl: Config.main.domain)
        
        networkService.request(endpoint: endpoint) { (result: Result<AuthResult>) in
            
            switch result {
                
            case .success(let response):
                
                guard result.value?.isValid == true else {
                    completion?(.failure(APIError.notAuthorized))
                    return
                }
                completion?(.success(response))
                
            case .failure(let error):
                completion?(.failure(error))
                
            }
            
        }
        
    }
    
}
