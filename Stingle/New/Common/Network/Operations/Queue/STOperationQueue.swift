//
//  STOperationQueue.swift
//  Stingle
//
//  Created by Khoren Asatryan on 3/21/21.
//

import Foundation

protocol INetworkOperationQueue: class {
    func operation(didStarted operation: INetworkOperation)
    func operation(didFinish operation: INetworkOperation, result: Any)
    func operation(didFinish operation: INetworkOperation, error: IError)
    
    var underlyingQueue: DispatchQueue? { get }
}

class STOperationQueue: INetworkOperationQueue {
    
    let maxConcurrentOperationCount: Int
    let qualityOfService: QualityOfService
    
    weak var underlyingQueue: DispatchQueue?
    
    private lazy var operationsQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = self.maxConcurrentOperationCount
        operationQueue.qualityOfService = self.qualityOfService
        operationQueue.underlyingQueue = self.underlyingQueue
        return operationQueue
    }()
    
    init(maxConcurrentOperationCount: Int = 5, qualityOfService: QualityOfService = .userInitiated, underlyingQueue: DispatchQueue? = nil) {
        self.maxConcurrentOperationCount = maxConcurrentOperationCount
        self.qualityOfService = qualityOfService
        self.underlyingQueue = underlyingQueue
    }
    
    //MARK: - Public methods
    
    func operationCount() -> Int {
        return self.operationsQueue.operationCount
    }
    
    func cancelAllOperations() {
        self.operationsQueue.cancelAllOperations()
    }
    
    func allOperations() -> [Operation] {
        return self.operationsQueue.operations
    }

    //MARK: - IOperationQueue
    
    func operation(didStarted operation: INetworkOperation) {
        self.operationsQueue.addOperation(operation)
    }
    
    func operation(didFinish operation: INetworkOperation, result: Any) {
        operation.responseSucces(result: result)
    }
    
    func operation(didFinish operation: INetworkOperation, error: IError) {
        operation.responseFailed(error: error)
    }
    
}
