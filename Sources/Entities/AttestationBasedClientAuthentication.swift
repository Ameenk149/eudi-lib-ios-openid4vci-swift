//
//  Untitled.swift
//  OpenID4VCI
//
//  Created by Pankaj Sachdeva on 19.11.24.
//
import Foundation
import JOSESwift

public protocol ClientAttestationPoPBuilder {
    func attestationPoPJWT(clientId: String, authServerId: URL, popJwtSpec: ClientAttestationPoPJWTSpec) throws -> ClientAttestationPoPJWT
}

public final class ClientAttestationPoPBuilderImpl: ClientAttestationPoPBuilder {
    
    public func attestationPoPJWT(clientId: String, authServerId: URL, popJwtSpec: ClientAttestationPoPJWTSpec) throws -> ClientAttestationPoPJWT {
        
        let header = try JWSHeader(parameters: [
            "typ": popJwtSpec.typ,
            "alg": popJwtSpec.signingAlgorithm,
        ])
        
        var dictionary: [String: Any] = [
          JWTClaimNames.issuedAt: Int(Date().timeIntervalSince1970.rounded()),
          JWTClaimNames.expirationTime: Int(Date().addingTimeInterval(popJwtSpec.duration).timeIntervalSince1970.rounded()),
          JWTClaimNames.audience: authServerId.absoluteString,
          JWTClaimNames.issuer: clientId,
          JWTClaimNames.jwtId: String.randomBase64URLString(length: 20)
        ]
        
        let payload = Payload(try dictionary.toThrowingJSONData())
        
        guard let signatureAlgorithm = SignatureAlgorithm(rawValue: popJwtSpec.signingAlgorithm) else {
          throw CredentialIssuanceError.cryptographicAlgorithmNotSupported
        }
        
        guard let privateKey = try? KeyController.generateECDHPrivateKey(),
              let publicKey = try? KeyController.generateECDHPublicKey(from: privateKey) else {
            throw CredentialIssuanceError.cryptographicAlgorithmNotSupported
        }
        
        guard let signer = Signer(
          signatureAlgorithm: signatureAlgorithm,
          key: privateKey
        ) else {
          throw ValidationError.error(reason: "Unable to create JWS signer")
        }

        let jws = try JWS(
          header: header,
          payload: payload,
          signer: signer
        )

//        return .jwt(jws.compactSerializedString)
        
        return ClientAttestationPoPJWT(jwt: jws.compactSerializedString)
    }
    
}
