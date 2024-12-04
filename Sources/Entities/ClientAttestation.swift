//
//  ClientAttestation.swift
//  OpenID4VCI
//
//  Created by Pankaj Sachdeva on 19.11.24.
//

import Foundation
import JOSESwift

public struct ClientAttestation {
    public let clientAttestationPoPJWTType: ClientAttestationPoPJWTSpec?
    public let clientAttestationJWT: String?
}

public struct ClientAttestationJWT {
    public let jwt: String
    public let clientId: ClientId
//    let pubKey: JWK
    public init(jwt: String, clientId: ClientId) {
        self.jwt = jwt
        self.clientId = clientId
    }
}

public struct ClientAttestationPoPJWT {
    public let jwt: String
}

public struct ClientAttestationPoPJWTSpec {
    let signingAlgorithm: String
    let duration: TimeInterval
    let typ: String
    let issuer: String
    let audience: String
    let nonce: String?
    let jwsSigner: Signer
}

//// Extension for SignedJWT validation
//extension SignedJwt {
//    func ensureSignedNotMAC() throws {
//        guard state == .signed || state == .verified else {
//            throw JWTError.notSigned
//        }
//        guard let algorithm = header.algorithm, !isMACSigningAlgorithm(algorithm) else {
//            throw JWTError.invalidSigningAlgorithm
//        }
//    }
//}

// Helper function to check if the algorithm is a MAC signing algorithm
func isMACSigningAlgorithm(_ alg: String) -> Bool {
    // Implement logic to check for MAC signing algorithms
    return ["HS256", "HS384", "HS512"].contains(alg)
}

// Error enumeration for JWT validation
enum JWTError: Error {
    case missingSubject
    case missingCnf
    case missingCnfJwk
    case missingExpiration
    case missingIssuer
    case missingJTI
    case missingAudience
    case notSigned
    case invalidSigningAlgorithm
    case invalidDuration
}
