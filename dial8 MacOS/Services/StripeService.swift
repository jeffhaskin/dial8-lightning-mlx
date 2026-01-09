//
//  StripeService.swift
//  dial8
//
//  Created by Liam Alizadeh on 11/26/24.
//

/// StripeService manages all payment and subscription-related functionality for Dial8.
///
/// This singleton service handles the integration with Stripe's payment platform:
///
/// Core Features:
/// - Checkout Session Creation: Initiates payment flows
/// - Subscription Management: Handles subscription status updates
/// - Customer Portal: Provides access to Stripe's customer portal
/// - Development Tools: Includes subscription reset functionality
///
/// API Endpoints:
/// - POST /api/v1/account/create-checkout-session
/// - POST /api/v1/account/subscription/manual-status
/// - GET /api/v1/account/subscription/portal
/// - POST /api/v1/account/subscription/reset
///
/// Security:
/// - Uses secure HTTPS connections
/// - Implements proper authentication headers
/// - Handles API keys securely
///
/// Error Handling:
/// - Custom StripeError enum for specific error cases
/// - Proper HTTP response validation
/// - Comprehensive error propagation
///
/// Usage:
/// ```swift
/// let service = StripeService.shared
/// 
/// // Create checkout session
/// let checkoutURL = try await service.createCheckoutSession()
/// 
/// // Update subscription status
/// try await service.updateSubscriptionStatus(.active)
/// 
/// // Access customer portal
/// let portalURL = try await service.createPortalSession()
/// ```

import Foundation

enum StripeError: Error {
    case invalidURL
    case invalidResponse
    case checkoutCreationFailed
}

enum SubscriptionStatus: String, CaseIterable {
    case active
    case inactive
    case cancelled
    case past_due
    
    var displayName: String {
        self.rawValue.capitalized
    }
}

// NOTE: All Stripe network functionality disabled - app operates in local-only mode
class StripeService {
    static let shared = StripeService()

    func createCheckoutSession() async throws -> String {
        // Network requests are disabled for local-only operation
        print("💳 Stripe checkout disabled - app running in local-only mode")
        throw StripeError.invalidURL
    }

    func updateSubscriptionStatus(_ status: SubscriptionStatus) async throws {
        // Network requests are disabled for local-only operation
        print("💳 Stripe subscription update disabled - app running in local-only mode")
        throw StripeError.invalidURL
    }

    func createPortalSession() async throws -> String {
        // Network requests are disabled for local-only operation
        print("💳 Stripe portal disabled - app running in local-only mode")
        throw StripeError.invalidURL
    }

    func resetSubscription() async throws {
        // Network requests are disabled for local-only operation
        print("💳 Stripe reset disabled - app running in local-only mode")
        throw StripeError.invalidURL
    }
}
