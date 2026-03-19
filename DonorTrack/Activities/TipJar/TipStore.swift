//
//  TipStore.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 2/7/23.
//

import Foundation
import StoreKit

// MARK: - Globals
enum TipJarError: LocalizedError {
	case failedVerification
	case system(Error)

	var errorDescription: String? {
		switch self {
		case .failedVerification:
			return "User transaction verification failed"
		case .system(let error):
			return error.localizedDescription
		}
	}
}

enum TipsAction: Equatable {
	case successful
	case failed(TipJarError)

	static func == (lhs: TipsAction, rhs: TipsAction) -> Bool {
		switch (lhs, rhs) {
		case (.successful, .successful):
			return true
		case (let .failed(lhsError), let .failed(rhsError)):
			return lhsError.localizedDescription == rhsError.localizedDescription
		default:
			return false
		}
	}
}

typealias PurchaseResult = Product.PurchaseResult
typealias TransactionListener = Task<Void, Error>

// MARK: - Class
@MainActor
final class TipStore: ObservableObject {
	@Published private(set) var items = [Product]()

	@Published private(set) var action: TipsAction? {
		didSet {
			switch action {
			case .failed:
				hasError = true
			default:
				hasError = false
			}
		}
	}

	@Published var hasError = false

	var error: TipJarError? {
		switch action {
		case .failed(let error):
			return error
		default:
			return nil
		}
	}

	private var transactionListener: TransactionListener?

	init() {
		transactionListener = configureTransactionListener()

		Task { [weak self] in
			await self?.retrieveProducts()
		}
	}

	deinit {
		transactionListener?.cancel()
	}

	func purchase(_ item: Product) async {
		do {
			let result = try await item.purchase()
			try await handlePurchase(from: result)

		} catch {
			action = .failed(.system(error))
		}
	}

	func reset() {
		action = nil
	}
}

// MARK: - Private Functions
private extension TipStore {
	func configureTransactionListener() -> TransactionListener {
		Task.detached(priority: .background) { @MainActor [weak self] in
			do {
				for await result in Transaction.updates {
					let transaction = try self?.checkVerified(result)
					self?.action = .successful
					await transaction?.finish()
				}
			} catch {
				self?.action = .failed(.system(error))
			}
		}
	}

	func retrieveProducts() async {
		do {
			let products = try await Product.products(for: tipProductIdentifiers).sorted { $0.price < $1.price }
			items = products
		} catch {
			action = .failed(.system(error))
		}
	}

	/// Handle the result when purchasing a product
	func handlePurchase(from result: PurchaseResult) async throws {
		switch result {
		case .success(let verification):
			print("Purchase was a success, now it's time to verify their purchase")
			let transaction = try checkVerified(verification)

			// Verification passed
			action = .successful

			await transaction.finish()
		case .pending:
			print("The user needs to complete some action on their account before they can complete purchase")
		case .userCancelled:
			print("The user hit cancel before their transaction started")
		default:
			print("Unknown error")

		}
	}

	func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
		switch result {
		case .unverified:
			print("User verification failed")
			throw TipJarError.failedVerification
		case .verified(let safe):
			return safe
		}
	}
}
