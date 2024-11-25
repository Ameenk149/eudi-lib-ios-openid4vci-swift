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

public enum AuthorizeIssuanceConfig {
  case favorScopes
  case authorizationDetails
}

public typealias ClientId = String
public typealias ClientSecret = String

public protocol Client: Codable {
    /// The client_id of the Wallet, issued when interacting with a credential issuer.
    var id: String { get }
}

public struct OpenId4VCIConfig {
  public let client: Client
  public let authFlowRedirectionURI: URL
  public let authorizeIssuanceConfig: AuthorizeIssuanceConfig
  public let usePAR: Bool
  public let attestationJWT: AttestedClient?

  public init(
    client: Client,
    authFlowRedirectionURI: URL,
    authorizeIssuanceConfig: AuthorizeIssuanceConfig = .favorScopes,
    usePAR: Bool = true
  ) {
    self.client = client
    self.authFlowRedirectionURI = authFlowRedirectionURI
    self.authorizeIssuanceConfig = authorizeIssuanceConfig
    self.usePAR = usePAR
    self.attestationJWT = nil
  }
    
    public init(
        client: Client,
        attestationJWT: AttestedClient,
        authFlowRedirectionURI: URL,
        authorizeIssuanceConfig: AuthorizeIssuanceConfig = .favorScopes,
        usePAR: Bool = true
    ) {
        self.client = client
        self.attestationJWT = attestationJWT
        self.authFlowRedirectionURI = authFlowRedirectionURI
        self.authorizeIssuanceConfig = authorizeIssuanceConfig
        self.usePAR = usePAR
    }
}

public class AttestedClient {
    let attestationJWT: ClientAttestationJWT
    let popJwtSpec: ClientAttestationPoPJWTSpec
    let id: String
    
    init(
        attestationJWT: ClientAttestationJWT,
        popJwtSpec: ClientAttestationPoPJWTSpec
    ) {
        let clientId = attestationJWT.clientId
        guard !clientId.trimmingCharacters(in: .whitespaces).isEmpty else {
            fatalError("Client ID must not be blank or empty")
        }

        self.attestationJWT = attestationJWT
        self.popJwtSpec = popJwtSpec
        self.id = clientId
    }
}
