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
import SiopOpenID4VP


/// A protocol for an authorization service.
public protocol AuthorisationServiceType {
  /// Posts a response and returns a generic result.
  func formPost<T: Codable, U: Codable>(
    poster: PostingType,
    url: URL,
    request: T
  ) async throws -> U
  
  func formPost<U: Codable>(
    poster: PostingType,
    url: URL,
    headers: [String: String],
    parameters: [String: String]
  ) async throws -> U
  
  func formPost<U: Codable>(
    poster: PostingType,
    url: URL,
    headers: [String: String],
    body: [String: Any]
  ) async throws -> U
    
}
//
//extension AuthorisationService {
////    public func formPost<U: Codable>(
////      poster: PostingType,
////      url: URL,
////      headers: [String: String],
////      body: [String: Any]
////    ) async throws -> (U, URLResponse) {
////      let headers = [
////        ContentType.form.rawValue: ContentType.json.rawValue
////      ].merging(headers, uniquingKeysWith: { _, new in
////        new
////      })
////      
////      let post = FormPostWithQueryItems(
////        additionalHeaders: headers,
////        url: url,
////        formData: body
////      )
////      
////      let result: Result<(U, URLResponse), PostError> = await poster.postWithSession(request: post.urlRequest)
////      return try result.get()
////    }
//    
//    /// Posts a response and returns a generic result.
//    public func formPost<T: Codable>(
//      poster: PostingType = Poster(),
//      response: AuthorizationResponse
//    ) async throws -> T {
//      switch response {
//      case .directPost(let url, let data):
//        let post = VerifierFormPost(
//          additionalHeaders: ["Content-Type": ContentType.form.rawValue],
//          url: url,
//          formData: try data.toDictionary()
//        )
//
//        let result: Result<T, PostError> = await poster.post(
//          request: post.urlRequest
//        )
//        return try result.get()
//      default: throw AuthorizationError.invalidResponseMode
//      }
//    }
//    
//}

/// An implementation of the `AuthorisationServiceType` protocol.
public actor AuthorisationService: AuthorisationServiceType {
  
  public init() { }
  
  /// Posts a response and returns a generic result.
  public func formPost<T: Codable, U: Codable>(
    poster: PostingType = Poster(),
    url: URL,
    request: T
  ) async throws -> U {
    let post = try FormPost(
      url: url,
      contentType: .form,
      formData: try request.toDictionary()
    )
    
    let result: Result<U, PostError> = await poster.post(request: post.urlRequest)
    return try result.get()
  }
  
  public func formPost<U: Codable>(
    poster: PostingType,
    url: URL,
    headers: [String: String] = [:],
    parameters: [String: String]
  ) async throws -> U {
    let post = try FormPost(
      url: url,
      contentType: .form,
      additionalHeaders: headers,
      formData: parameters
    )
    
    let result: Result<U, PostError> = await poster.post(request: post.urlRequest)
    return try result.get()
  }
  
  public func formPost<U: Codable>(
    poster: PostingType,
    url: URL,
    headers: [String: String],
    body: [String: Any]
  ) async throws -> U {
    let post = try FormPost(
      url: url,
      contentType: .json,
      additionalHeaders: headers,
      formData: body
    )
    
    let result: Result<U, PostError> = await poster.post(request: post.urlRequest)
    return try result.get()
  }
}
