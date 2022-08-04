// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Foundation

public enum BindingPhoneNumberResult: Codable {
    case success
}

public enum BindingPhoneNumberEvent {
    case enterPhoneNumber(phoneNumber: String)
    case enterOTP(opt: String)
    case back
}

public enum BindingPhoneNumberState: Codable, State, Equatable {
    public typealias Event = BindingPhoneNumberEvent
    public typealias Provider = None

    case enterPhoneNumber(initialPhoneNumber: String?)
    case enterOTP(phoneNumber: String)
    case finish(_ result: BindingPhoneNumberResult)

    public static var initialState: BindingPhoneNumberState = .enterPhoneNumber(initialPhoneNumber: nil)

    public func accept(
        currentState: BindingPhoneNumberState,
        event: BindingPhoneNumberEvent,
        provider _: None
    ) async throws -> BindingPhoneNumberState {
        switch currentState {
        case .enterPhoneNumber:
            switch event {
            case let .enterPhoneNumber(phoneNumber):
                return .enterOTP(phoneNumber: phoneNumber)
            default:
                throw StateMachineError.invalidEvent
            }
        case .enterOTP(let phoneNumber):
            switch event {
            case .enterOTP:
                return .finish(.success)
            case .back:
                return .enterPhoneNumber(initialPhoneNumber: phoneNumber)
            default:
                throw StateMachineError.invalidEvent
            }
        default:
            throw StateMachineError.invalidEvent
        }
    }
}

extension BindingPhoneNumberState: Step {
    public var step: Float {
        switch self {
        case .enterPhoneNumber(initialPhoneNumber: let initialPhoneNumber):
            return 1
        case .enterOTP(phoneNumber: let phoneNumber):
            return 2
        case .finish(_):
            return 3
        }
    }
}