//
//  AuthenticateSession.swift
//  TNT_Premier
//
//  Created by Максим Стегниенко on 03.04.2018.
//  Copyright © 2018 Finch. All rights reserved.
//

import Foundation
import NetworkClient

final class AuthenticateSession2 {
    
    // MARK: - Properties
    
    private let networkClient: NetworkInterface
    private let sessionStorage: SessionStorage
    private var prettyStorage: PrettyStorage
    
    // MARK: - Local types
    
    private enum Endpoint {
        
        static let loginRoute = "LoginRoute"
        static let login = "Login"
        static let authenticate = "Authenticate"
        static let onLineHeartbeat = "OnLineHeartbeat"
        static let config = "QueryCustomizeConfig"
        
    }
    
    
    // MARK: - Init
    
    init(networkClient: NetworkInterface, sessionStorage: SessionStorage,
         prettyStorage: PrettyStorage) {
        
        self.networkClient = networkClient
        self.sessionStorage = sessionStorage
        self.prettyStorage = prettyStorage
    }
    
}


//MARK: - Authenticate
extension AuthenticateSession2: AuthenticateService {
    
    func obtainConfig(completionHandler: ((Result<ConfigResponse?, NetworkErrorHandler<ServerResponseFailure>>) -> ())?) {
        
        let configUrl = sessionStorage.baseUrl + Endpoint.config
        
        let parameters = ["queryType" : "0,2,4,5,6,7",
                          "language"  : "English",
                          "standard"  : "ISO 639-2"]
        
        networkClient.postJSONRequest(configUrl, parameters: parameters) { result in
            
            switch result {
                
            case .success(let value):
                
                guard let value = value?.dictionary,
                    let data = try? JSONSerialization.data(withJSONObject: value,
                                                           options: .prettyPrinted) else {
                                                            completionHandler?(Result.failure(.noJson))
                                                            return
                }
                
                let response = try? JSONDecoder().decode(ConfigResponse.self, from: data)
                completionHandler?(Result.success(response))
                
            case .failure(let error):
                completionHandler?(Result.failure(.description(error)))
                
            }
            
        }
        
    }
    
    func startHeartBeat() {
        let url = sessionStorage.baseUrl + Endpoint.onLineHeartbeat
        networkClient.postJSONRequest(url, completionHandler: nil)
    }
    
    func startAuthenticate(property: String? = nil, digitVariable: String? = nil,
                           completionHandler: ((LoginResponse?, Result<AuthorizationResult?, NetworkErrorHandler<ServerResponseFailure>>) -> Void)?) {
        
        // MARK: - Local method
        
        func fetch<T: Decodable>(_ type: T.Type, url: String, parameters: [String : Any] = [:]) -> T? {
            
            let semaphore = DispatchSemaphore(value: 0)
            var response: T?
            
            networkClient.postJSONRequest(url, parameters: parameters) { result in
                
                switch result {
                    
                case .success(let value):
                    
                    guard let value = value?.dictionary,
                        let data = try? JSONSerialization.data(withJSONObject: value,
                                                               options: .prettyPrinted) else {
                                                                
                                                                completionHandler?(nil, Result.failure(.noJson))
                                                                semaphore.signal()
                                                                return
                    }
                    print(value)
                    response = try? JSONDecoder().decode(T.self, from: data)
                    semaphore.signal()
                    
                case .failure(let error):
                    completionHandler?(nil, Result.failure(.description(error)))
                    semaphore.signal()
                    
                }
                
            }
            
            semaphore.wait()
            return response
        }
        
        // request #1
        
        var url = sessionStorage.edsBaseUrl + Endpoint.loginRoute
        
        guard let vspHttpsURL = fetch(LoginResponse.self, url: url)?.vspHttpsURL else {
            return
        }
        
        sessionStorage.baseUrl = vspHttpsURL + "/VSP/V3/"
        
        // request #2
        
        url = sessionStorage.baseUrl + Endpoint.login
        var parameters: [String : Any] = ["deviceModel":"AppleTV"]
        
        guard let loginResult = fetch(LoginResponse.self, url: url, parameters: parameters) else {
            completionHandler?(nil, Result.failure(.noLogin))
            return
        }
        
        sessionStorage.vspHttpsURL = loginResult.vspHttpsURL
        
        // request #3
        
        url = sessionStorage.baseUrl + Endpoint.authenticate
        
        var authenticateBasic: [String : Any] = ["timeZone":"Africa/Addis_Ababa",
                                                 "lang" : "ru",
                                                 "isSupportWebplmgFormat" : "0",
                                                 "needPosterTypes": ["1","2","3","4","5","6","7"],
                                                 "userType": "3"]
        
        func add(property: String, digitVariable: String) {
            authenticateBasic["userID"] = digitVariable
            authenticateBasic["clientPasswd"] = property
            authenticateBasic["userType"] = "1"
        }
        
        if let property = property, let digitVariable = digitVariable {
            add(property: property, digitVariable: digitVariable)
            
            prettyStorage.property = property
            prettyStorage.digitVariable = digitVariable
            
        } else if let digitVariable = prettyStorage.digitVariable,
            let property = prettyStorage.property {
            
            add(property: property, digitVariable: digitVariable)
        }
        
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        
        let authenticateDevice: [String : Any] = ["terminalID" : deviceId,
                                                  "deviceModel" : "AppleTV",
                                                  "OSVersion" : "IOS",
                                                  "physicalDeviceID" : deviceId,
                                                  "CADeviceInfos" : [["CADeviceType" : "6",
                                                                      "CADeviceID" : deviceId]]]
        
        let authenticateTolerant = ["areaCode":"2",
                                    "templateName":"default",
                                    "subnetID":"703",
                                    "bossID":"gpmocabt",
                                    "userGroup":"1"]
        
        parameters = ["authenticateBasic":authenticateBasic,
                      "authenticateDevice":authenticateDevice,
                      "authenticateTolerant": authenticateTolerant]
        
        guard let authorizationResult = fetch(AuthorizationResult.self, url: url, parameters: parameters) else {
            return
        }
        
        sessionStorage.jSessionID = authorizationResult.jSessionID
        sessionStorage.subscriberID = authorizationResult.subscriberID
        
        startHeartBeat()
        
        completionHandler?(loginResult, Result.success(authorizationResult))
        
    }
    
}
