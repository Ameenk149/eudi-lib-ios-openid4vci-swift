/*
 * Copyright (c) 2023 European Commission
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import Foundation

@testable import OpenID4VCI

struct Wallet {
  let actingUser: ActingUser
  let bindingKey: BindingKey
}

extension Wallet {
  func issueByScope(_ scope: String) async throws -> String {
    let credentialIssuerIdentifier = try CredentialIssuerId(CredentialIssuer_URL)
    let issuerMetadata = await CredentialIssuerMetadataResolver().resolve(
      source: .credentialIssuer(
        credentialIssuerIdentifier
      )
    )
    
    switch issuerMetadata {
    case .success(let metaData):
      if let authorizationServer = metaData?.authorizationServers.first,
         let metaData {
        let authServerMetadata = await AuthorizationServerMetadataResolver().resolve(url: authorizationServer)
        
        let offer = try CredentialOffer(
          credentialIssuerIdentifier: credentialIssuerIdentifier,
          credentialIssuerMetadata: metaData,
          credentials: [
            .scope(.init(scope)),
            .scope(.init(Constants.OPENID_SCOPE))
          ],
          authorizationServerMetadata: try authServerMetadata.get()
        )
        return try await issueOfferedCredentialNoProof(offer: offer)
        
      } else {
        throw ValidationError.error(reason: "Invalid authorization server")
      }
    case .failure:
      throw ValidationError.error(reason: "Invalid issuer metadata")
    }
  }
  
  private func issueOfferedCredentialNoProof(offer: CredentialOffer) async throws -> String {
    
    let issuer = try Issuer(
      authorizationServerMetadata: offer.authorizationServerMetadata,
      issuerMetadata: offer.credentialIssuerMetadata,
      config: config
    )
    
    // Authorize with auth code flow
    let authorized = try await authorizeRequestWithAuthCodeUseCase(
      issuer: issuer,
      offer: offer
    )
    
    switch authorized {
    case .noProofRequired:
      return try await noProofRequiredSubmissionUseCase(
        issuer: issuer,
        noProofRequiredState: authorized,
        offer: offer
      )
    case .proofRequired:
      return try await proofRequiredSubmissionUseCase(
        issuer: issuer,
        authorized: authorized,
        offer: offer
      )
    }
  }
}

extension Wallet {
  
  func issueByCredentialOfferUrl(url: String) async throws -> String {
    let result = await CredentialOfferRequestResolver()
      .resolve(
        source: try .init(
          urlString: url
        )
      )
    
    switch result {
    case .success(let offer):
      return try await issueOfferedCredentialWithProof(offer: offer)
    case .failure(let error):
      throw ValidationError.error(reason: "Unable to resolve credential offer: \(error.localizedDescription)")
    }
  }
  
  private func issueOfferedCredentialWithProof(offer: CredentialOffer) async throws -> String {
    
    let issuer = try Issuer(
      authorizationServerMetadata: offer.authorizationServerMetadata,
      issuerMetadata: offer.credentialIssuerMetadata,
      config: config
    )

    let authorized = try await authorizeRequestWithAuthCodeUseCase(
      issuer: issuer,
      offer: offer
    )
    
    switch authorized {
    case .noProofRequired:
      return try await noProofRequiredSubmissionUseCase(
        issuer: issuer,
        noProofRequiredState: authorized,
        offer: offer
      )
    case .proofRequired:
      return try await proofRequiredSubmissionUseCase(
        issuer: issuer,
        authorized: authorized,
        offer: offer
      )
    }
  }
  
  private func authorizeRequestWithAuthCodeUseCase(
    issuer: Issuer,
    offer: CredentialOffer
  ) async throws -> AuthorizedRequest {
    
    var pushedAuthorizationRequestEndpoint = ""
    if case let .oidc(metaData) = offer.authorizationServerMetadata {
      pushedAuthorizationRequestEndpoint = metaData.pushedAuthorizationRequestEndpoint
      
    } else if case let .oauth(metaData) = offer.authorizationServerMetadata {
      pushedAuthorizationRequestEndpoint = metaData.pushedAuthorizationRequestEndpoint
    }
    
    print("--> Placing PAR to AS server's endpoint \(pushedAuthorizationRequestEndpoint)")
    
    let parPlaced = await issuer.pushAuthorizationCodeRequest(
      credentials: offer.credentials
    )
    
    if case let .success(request) = parPlaced,
       case let .par(parRequested) = request {
      print("--> Placed PAR. Get authorization code URL is: \(parRequested.getAuthorizationCodeURL)")
      
      let authorizationCode = try await loginUserAndGetAuthCode(
        getAuthorizationCodeUrl: parRequested.getAuthorizationCodeURL.url,
        actingUser: actingUser
      ) ?? { throw  ValidationError.error(reason: "Could not retrieve authorization code") } ()
      
      print("--> Authorization code retrieved: \(authorizationCode)")
      
      let unAuthorized = await issuer.handleAuthorizationCode(
        parRequested: request,
        authorizationCode: .authorizationCode(authorizationCode: authorizationCode)
      )
      
      switch unAuthorized {
      case .success(let request):
        let authorizedRequest = await issuer.requestAccessToken(authorizationCode: request)
        
        if case let .success(authorized) = authorizedRequest,
           case let .noProofRequired(token) = authorized {
          print("--> Authorization code exchanged with access token : \(token.accessToken)")
          
          return authorized
        }
        
      case .failure(let error):
        throw  ValidationError.error(reason: error.localizedDescription)
      }
    }
    
    throw  ValidationError.error(reason: "Failed to get push authorization code request")
  }
  
  private func noProofRequiredSubmissionUseCase(
    issuer: Issuer,
    noProofRequiredState: AuthorizedRequest,
    offer: CredentialOffer
  ) async throws -> String {
    switch noProofRequiredState {
    case .noProofRequired:
      let requestOutcome = try await issuer.requestSingle(
        noProofRequest: noProofRequiredState,
        credentialMetadata: offer.credentials.first, 
        responseEncryptionSpecProvider: { Issuer.createResponseEncryptionSpec($0) }
      )
      switch requestOutcome {
      case .success(let request):
        switch request {
        case .success(let response):
          if let result = response.credentialResponses.first {
            switch result {
            case .deferred(let transactionId):
              return try await deferredCredentialUseCase(
                issuer: issuer,
                authorized: noProofRequiredState,
                transactionId: transactionId
              )
            case .issued(_, let credential):
              return credential
            }
          } else {
            throw ValidationError.error(reason: "No credential response results available")
          }
        case .invalidProof(let cNonce, _):
          return try await proofRequiredSubmissionUseCase(
            issuer: issuer,
            authorized: noProofRequiredState.handleInvalidProof(cNonce: cNonce),
            offer: offer
          )
        case .failed(error: let error):
          throw ValidationError.error(reason: error.localizedDescription)
        }
        
      case .failure(let error):
        throw ValidationError.error(reason: error.localizedDescription)
      }
    default: throw ValidationError.error(reason: "Illegal noProofRequiredState case")
    }
  }
  
  private func proofRequiredSubmissionUseCase(
    issuer: Issuer,
    authorized: AuthorizedRequest,
    offer: CredentialOffer
  ) async throws -> String {
    let requestOutcome = try await issuer.requestSingle(
      proofRequest: authorized,
      credentialMetadata: offer.credentials.first,
      bindingKey: bindingKey, 
      responseEncryptionSpecProvider:  { Issuer.createResponseEncryptionSpec($0) }
    )
    
    switch requestOutcome {
    case .success(let request):
      switch request {
      case .success(let response):
        if let result = response.credentialResponses.first {
          switch result {
          case .deferred(let transactionId):
            return try await deferredCredentialUseCase(
              issuer: issuer,
              authorized: authorized,
              transactionId: transactionId
            )
          case .issued(_, let credential):
            return credential
          }
        } else {
          throw ValidationError.error(reason: "No credential response results available")
        }
      case .invalidProof:
        throw ValidationError.error(reason: "Although providing a proof with c_nonce the proof is still invalid")
      case .failed(let error):
        throw ValidationError.error(reason: error.localizedDescription)
      }
    case .failure(let error): throw ValidationError.error(reason: error.localizedDescription)
    }
  }
  
  private func deferredCredentialUseCase(
    issuer: Issuer,
    authorized: AuthorizedRequest,
    transactionId: TransactionId
  ) async throws -> String {
    print("--> Got a deferred issuance response from server with transaction_id \(transactionId.value). Retrying issuance...")
    
    let deferredRequestResponse = try await issuer.requestDeferredIssuance(
      proofRequest: authorized,
      transactionId: transactionId
    )
    
    switch deferredRequestResponse {
    case .success(let response):
      switch response {
      case .issued(_, let credential):
        return credential
      case .issuancePending(let transactionId):
        throw ValidationError.error(reason: "Credential not ready yet. Try after \(transactionId.interval ?? 0)")
      case .errored(_, let errorDescription):
        throw ValidationError.error(reason: "\(errorDescription ?? "Something went wrong with your deferred request response")")
      }
    case .failure(let error):
      throw ValidationError.error(reason: error.localizedDescription)
    }
  }
}

extension Wallet {
  private func loginUserAndGetAuthCode(
    getAuthorizationCodeUrl: URL,
    actingUser: ActingUser
  ) async throws -> String? {
    let helper = WebpageHelper()
    return try await helper.submit(
      formUrl: getAuthorizationCodeUrl,
      username: actingUser.username,
      password: actingUser.password
    )
  }
}
