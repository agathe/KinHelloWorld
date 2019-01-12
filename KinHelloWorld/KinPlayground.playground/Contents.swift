import UIKit
import KinSDK

let providerUrl = URL(string: "http://horizon-testnet.kininfrastructure.com")!
let kinClient = try! KinClient(with: providerUrl, networkId: .testNet)

print("The client has \(kinClient.accounts.count) accounts")

var account: KinAccount!

// Get current account
if let existingAccount = kinClient.accounts.first {
    account = existingAccount
}
// Create an account
else {
    account = try! kinClient.addAccount()
}
print("The account's address is \(account.publicAddress)")

