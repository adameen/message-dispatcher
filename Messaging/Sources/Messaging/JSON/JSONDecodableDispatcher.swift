//
//  JSONDecodableDispatcher.swift
//  
//
//  Created by Alexey Rogatkin on 16.12.2022.
//

import Foundation

public final class JSONDecodableDispatcher: DecodableDispatcher, DecodableDispatcherConnector {

    private let decoder: JSONDecoder

    private var messageMetaTypes: [Decodable.Type] = []
    private var handlerDict: [Int: [any Handler]] = [:]
    
    public init(decoder: JSONDecoder) {
        self.decoder = decoder
    }
    
    public func register<X>(handler: X) where X: Handler, X.Message : Decodable {
        let messageMetaTypeIndex: Int
        let index = messageMetaTypes.firstIndex { $0 is X.Message.Type }

        if let index = index {
            messageMetaTypeIndex = index
        } else {
            messageMetaTypeIndex = messageMetaTypes.count
            messageMetaTypes.append(X.Message.self)
        }

        if let handlerArray = handlerDict[messageMetaTypeIndex] {
            var array = handlerArray
            array.append(handler)
            handlerDict.updateValue(array, forKey: messageMetaTypeIndex)
        } else {
            handlerDict.updateValue([handler], forKey: messageMetaTypeIndex)
        }
    }
    
    public func handle(incomingMessage: Data) -> DecodableDispatcherStatus {

        for (index, messageType) in messageMetaTypes.enumerated() {
            if let decodedMessage = try? decoder.decode(messageType, from: incomingMessage) {
                if let handlers = handlerDict[index] {

                    var errors: [(any Handler, Error)] = []

                    for handler in handlers {
                        do {
                            try myHandle(handler, message: decodedMessage)
                            return .handled(message: decodedMessage, by: handler)
                        } catch {
                            errors.append((handler, error))
                        }
                    }

                    return .handlerNotFound(message: decodedMessage, errors: errors)
                }
            }
        }

        return .messageNotSupported
    }

    private func myHandle<T: Handler>(_ handler: T, message: Decodable) throws {
        // force unwrapping is not nice :)
        try handler.handle(message: message as! T.Message)
    }
    
}
