//
//  RequestFunctor.swift
//  THT-Premier
//
//  Created by Максим Стегниенко on 21/02/2019.
//  Copyright © 2019 Finch. All rights reserved.
//

class RequestFunctor<Endpoint: EndpointProtocol, Response: Codable> {
    
    let endpoint: Endpoint
    let actionAfterSuccess: (Response) -> Void
    let actionAfterFailure: (APIError) -> Void
    let networkService: NetworkService<Endpoint>
    
    init(endpoint: Endpoint,
         actionAfterSuccess: @escaping (Response) -> Void,
         actionAfterFailure: @escaping (APIError) -> Void,
         networkService: NetworkService<Endpoint>) {
        
        self.endpoint = endpoint
        self.actionAfterSuccess = actionAfterSuccess
        self.actionAfterFailure = actionAfterFailure
        self.networkService = networkService
        
    }
    
    func runRequest(cachingEnabled: Bool) {
        
        let semaphore = DispatchSemaphore(value: 1)
        
        networkService.request(endpoint: endpoint,
                               cachingEnabled: cachingEnabled) { [weak self] (result: Result<Response>) in
                                
            switch result {
                                    
            case .success(let response):
                self?.actionAfterSuccess(response)
                semaphore.signal()
                                    
            case .failure(let error):
                self?.actionAfterFailure(error)
                semaphore.signal()
            }
                                
        }
        
        semaphore.wait()
        
    }
    
}
