
//  AuthenticateSession.swift
//  TNT_Premier
//
//  Created by Максим Стегниенко on 03.04.2018.
//  Copyright © 2018 Finch. All rights reserved.
//

import Foundation
import NetworkClient
import ObjectMapper

final class AuthenticateSession1 {
    
    // MARK: - Properties
    
    private let networkClient: NetworkInterface
    private let sessionStorage: SessionStorage
    private var prettyStorage: PrettyStorage
    private var password = ""
    private var userId = ""
    
    
    // MARK: - Init
    
    init(networkClient: NetworkInterface,
         sessionStorage: SessionStorage,
         prettyStorage: PrettyStorage) {
        
        self.networkClient = networkClient
        self.sessionStorage = sessionStorage
        self.prettyStorage = prettyStorage
       
    }
    
}


//MARK: - Authenticate
extension AuthenticateSession1: AuthenticateService {
    
    func obtainConfig(completionHandler: ((Result<ConfigResponse?, NetworkErrorHandler<ServerResponseFailure>>) -> ())?) {
        
    }
    
    
    func startHeartBeat() {
        let url = sessionStorage.baseUrl + "OnLineHeartbeat"
        networkClient.postJSONRequest(url, completionHandler: nil)
    }
    
    func saveData() {
        prettyStorage.property = password
        prettyStorage.digitVariable = userId
    }
    
      func startAuthenticate(property: String?, digitVariable: String?, completionHandler: ((LoginResponse?, Result<AuthorizationResult?, NetworkErrorHandler<ServerResponseFailure>>) -> Void)?) {
        
        let loginRoute = sessionStorage.edsBaseUrl + "LoginRoute"
        
        self.networkClient.postJSONRequest(loginRoute) { result in
            switch result {
                
            case .success(let value):
                
                guard let value = value?.dictionary,
                    let baseUrl = value["vspHttpsURL"] as? String else {
                        return
                }
                
                self.sessionStorage.baseUrl = baseUrl + "/VSP/V3/"
                
                let loginUrl = self.sessionStorage.baseUrl + "Login"
                let authenticateUrl = self.sessionStorage.baseUrl + "Authenticate"
                
                self.networkClient.postJSONRequest(loginUrl, parameters: ["deviceModel":"AppleTV"], completionHandler: { result in
                    
                    var authenticateBasic: [String : Any] = ["timeZone":"Africa/Addis_Ababa",
                                                             "lang" : "ru",
                                                             "isSupportWebplmgFormat" : "0",
                                                             "needPosterTypes": ["1","2","3","4","5","6","7"],
                                                             "userType": "3"]
                    
                    if let userId = property, let password = digitVariable {
                        authenticateBasic["userID"] = userId
                        authenticateBasic["clientPasswd"] = password
                        authenticateBasic["userType"] = "1"
                        self.password = password
                        self.userId = userId
                    } else if let userId = self.prettyStorage.digitVariable, let password = self.prettyStorage.property {
                        authenticateBasic["userID"] = userId
                        authenticateBasic["clientPasswd"] = password
                        authenticateBasic["userType"] = "1"
                    }
                    
                    let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
                    
                    let authenticateDevice: [String : Any] = ["terminalID" : deviceId,
                                                              "deviceModel" : "AppleTV",
                                                              "OSVersion" : "IOS",
                                                              "physicalDeviceID" : deviceId,
                                                              "CADeviceInfos" : [["CADeviceType" : "6","CADeviceID" : deviceId]]]
                    
                    let authenticateTolerant = ["areaCode":"2",
                                                "templateName":"default",
                                                "subnetID":"703",
                                                "bossID":"gpmocabt",
                                                "userGroup":"1"]
                    
                    let param: [String:Any] = ["authenticateBasic":authenticateBasic,
                                               "authenticateDevice":authenticateDevice,
                                               "authenticateTolerant": authenticateTolerant]
                    
                    switch result {
                        
                    case .success(let value):
                        
                        guard let value = value?.dictionary,
                              let data = try? JSONSerialization.data(withJSONObject: value,
                                                                   options: .prettyPrinted) else {
                            return
                        }
                        
                        let response = try? JSONDecoder().decode(LoginResponse.self, from: data)
                       
                        self.networkClient.postJSONRequest(authenticateUrl, parameters: param, completionHandler: { result in
                            
                            switch result {
                            case .success(let value):
                                
                                guard let value = value?.dictionary,
                                    let data = try? JSONSerialization.data(withJSONObject: value,
                                                                           options: .prettyPrinted) else {
                                    return
                                }
                                
                                var authorizationResult = try? JSONDecoder().decode(AuthorizationResult.self, from: data)
                                
                                self.startHeartBeat()
                                
                                completionHandler?(response, Result.success(authorizationResult))
                                
                            case .failure(let error):
                                completionHandler?(nil, Result.failure(.description(error)))
                            }
                            
                        })
                        
                    case .failure(let error):
                        completionHandler?(nil, Result.failure(.description(error)))
                        
                    }
                    
                })
                
            case .failure(let error):
                completionHandler?(nil, Result.failure(.description(error)))
            }
        }
        
        
    }
    
}
