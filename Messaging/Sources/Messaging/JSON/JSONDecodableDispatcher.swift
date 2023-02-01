//
//  JSONDecodableDispatcher.swift
//  
//
//  Created by Alexey Rogatkin on 16.12.2022.
//

import Foundation

public final class JSONDecodableDispatcher: DecodableDispatcher, DecodableDispatcherConnector {

    private let decoder: JSONDecoder
    private var handlers: [AnyHandler] = []

    public init(decoder: JSONDecoder) {
        self.decoder = decoder
    }

    public func register<X>(handler: X) where X: Handler, X.Message : Decodable {
        handlers.append(AnyHandler(handler, decoder: decoder))
    }

    public func handle(incomingMessage: Data) -> DecodableDispatcherStatus {

        var decodedMessage: Decodable?
        var decodedMessageErrors: [(any Handler, Error)] = []

        for wrappedHandler in handlers {
            let result = wrappedHandler.handle(incomingMessage)

            switch result {
            case .success(let handlerSuccess):
                return .handled(message: handlerSuccess.message, by: handlerSuccess.handler)
            case .failure(let handlerFailure):
                decodedMessageErrors.append((handlerFailure.handler, handlerFailure.error))
                decodedMessage = handlerFailure.message
            case .couldNotDecode:
                break
            }
        }

        if let decodedMessage {
            return .handlerNotFound(message: decodedMessage, errors: decodedMessageErrors)
        } else {
            return .messageNotSupported
        }
    }
}

final class AnyHandler {
    let handle: (Data) -> HandlerResult
    private let decoder: JSONDecoder

    init<T: Handler>(_ handler: T, decoder: JSONDecoder) where T.Message: Decodable {
        self.decoder = decoder

        self.handle = { data in
            if let message = try? decoder.decode(T.Message.self, from: data) {
                do {
                    try handler.handle(message: message)
                    return .success(HandlerSuccess(message: message, handler: handler))
                } catch {
                    return .failure(HandlerFailure(message: message, handler: handler, error: error))
                }
            }
            return .couldNotDecode
        }
    }
}

enum HandlerResult {
    case success(HandlerSuccess)
    case failure(HandlerFailure)
    case couldNotDecode
}

struct HandlerSuccess {
    let message: Decodable
    let handler: any Handler
}

struct HandlerFailure: Error {
    let message: Decodable
    let handler: any Handler
    let error: Error
}
