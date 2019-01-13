//
//  ViewController.swift
//  KinHelloWorld
//
//  Copyright © 2019 Kin Ecosystem. All rights reserved.
//

import UIKit
import KinSDK

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the Kin client on the test blockchain
        let kinClient: KinClient! = initializeKinClientOnTestNetwork()

        // The Kin Account we're going to create and use
        var account: KinAccount! = nil

        // This deletes any stored account so that we recreate one
        deleteFirstAccount(kinClient: kinClient)
        
        // Get any stored existing user account
        if let existingAccount = getFirstAccount(kinClient: kinClient) {
            print("Current account with address \(existingAccount.publicAddress)")
            account = existingAccount
        }
        // or else create an account with the client
        else if let newAccount = createLocalAccount(kinClient: kinClient) {
            print("Created account with address \(newAccount.publicAddress)")
            account = newAccount
        }

        // Watch for the creation of the account
        watchCreation(forAccount: account)

        // Watch for changes in the balance of the account
        watchBalance(forAccount: account)

        // Print the current status of the account
        printStatus(forAccount: account, completionHandler: nil)

        // We use here the asynchronous version of the methods to get the status, and depending on the status (whether
        // the account has been created on the blockchain or not) we create it on the blockchain, fund it, and
        // send a transaction, or just print the balance and send a transaction.

        // Get the status of the account
        account.status { (status: AccountStatus?, error: Error?) in
            guard let status = status else { return }
            switch status {
            case .notCreated:
                // The account has just been created locally. It needs to be added to the blockchain

                // We create that account on the test blockchain
                self.createTestAccountOnBlockchain(account: account) { (result: [String : Any]?) in
                    guard result != nil else {
                        print("The account has not been created")
                        return
                    }
                    print("Account was created successfully")

                    // Fund the account, which we can do this way only on the test blockchain.
                    // If you're using the main blockchain, the account will have fund once another account sends
                    // kins to it.
                    self.fundTestAccount(account: account) { (success) in
                        guard success else {
                            print("Account was not funded")
                            return
                        }
                        print("Account was funded - now sending kins to another account")

                        // Print the account's status again
                        self.printStatus(forAccount: account, completionHandler: nil)

                        // Sends some kinds to another account
                        let toAddress = "GDXTTWKMVNFMEX3HGU7DNVOOXIUP6KM7YANENXILHUCZFHG2IGSK352K"
                        self.sendTransaction(fromAccount: account,
                                toAddress: toAddress,
                                kinAmount: 10,
                                memo: "Test") { txId in
                            print("Kins were sent successfully!!!!!")
                        }
                    }
                }

            case .created:
                // The account exists on the blockchain - We can send transactions (provided there are enough kins)

                // Get the balance
                self.getBalance(forAccount: account) { kin in
                    guard let kin = kin,
                          kin > 0.0 else {
                        print("No kins in this account")
                        return
                    }
                    print("The account is created and can send kins with a balance of \(kin) Kins")
                    let toAddress = "GDXTTWKMVNFMEX3HGU7DNVOOXIUP6KM7YANENXILHUCZFHG2IGSK352K"
                    self.sendTransaction(fromAccount: account,
                            toAddress: toAddress,
                            kinAmount: 9.8,
                            memo: "Test") { txId in
                        print("Kins were sent successfully!!!!!")
                    }
                }
            }
        }

        // Exports the account to a JSON string with the given passphrase. You can later import the account with the
        // same passphrase and the JSON string.
        let json = try! account.export(passphrase: "a-secret-passphrase-here")
        print("Exported JSON \n\(json)\n")

    }

    /**
    Initializes the Kin Client with the test environment.
    */
    func initializeKinClientOnTestNetwork() -> KinClient? {
        let url = "http://horizon-testnet.kininfrastructure.com"
        guard let providerUrl = URL(string: url) else { return nil }
        do {
            let appId = try AppId("test")
            return KinClient(with: providerUrl, network: .testNet, appId: appId)
        } catch let error {
            print("Error \(error)")
        }
        return nil
    }

    /**
    Returns the first account stored on the client. The account status will tell whether the account also exists
    on the blockchain or not.
    */
    func getFirstAccount(kinClient: KinClient) -> KinAccount? {
        return kinClient.accounts.first
    }

    /**
    Create a local stored account (does not created it on the blockchain)
    */
    func createLocalAccount(kinClient: KinClient) -> KinAccount? {
        do {
            let account = try kinClient.addAccount()
            return account
        } catch let error {
            print("Error creating an account \(error)")
        }
        return nil
    }

    /**
    Delete the first stored account of the client.
    */
    func deleteFirstAccount(kinClient: KinClient) {
        do {
            try kinClient.deleteAccount(at: 0)
            print("First stored account deleted!")
        } catch let error {
            print("Could not delete account \(error)")
        }
    }

    /**
    Get the balance using promises.
    */
    func printBalance(forAccount account: KinAccount) {
        account.balance()
            .then { (balance: Kin) in
                print("1) balance is \(balance)")
            }
            .error { (error:Error) in
                print("1) Got an error with getting the balance \(error)")
            }
    }

    /**
    Get the balance using the method with callback.
    */
    func getBalance(forAccount account: KinAccount, completionHandler: ((Kin?) -> ())?) {
        account.balance { (balance: Kin?, error: Error?) in
            if error != nil || balance == nil {
                print("Error getting the balance")
                if let error = error { print("with error: \(error)") }
                completionHandler?(nil)
                return
            }
            completionHandler?(balance!)
        }
    }

    /**
    Watch for the creation of the account. This simply prints a message.
    */
    func watchCreation(forAccount account: KinAccount) {
        do {
            let watch = try account.watchCreation()
            watch.then { (_) in
                print("!!!!!!!!!!!!!!Account was created (watch)")
            }
        } catch let error {
            print("Error watching account creation \(error)")
        }
    }

    /**
    Watch the balance. This simply prints a message when the balance has changed.
    */
    func watchBalance(forAccount account: KinAccount) {
        let watch = try! account.watchBalance(nil)
        watch.emitter.on { (balance: Kin) in
            print("The account's balance has changed: \(balance)")
        }
    }

    /**
    Get the status of the account using the callback method.
    */
    func printStatus(forAccount account: KinAccount,
                     completionHandler: ((AccountStatus?) -> ())?) {
        account.status { (status: AccountStatus?, error: Error?) in
            if error != nil || status == nil {
                print("Error getting status")
                if let error = error { print ("with error: \(error)") }
                completionHandler?(nil)
                return
            }
            print("Account's status: \(status!)")
            completionHandler?(status!)
        }
    }

    /**
    Create the given stored account on the test blockchain.
    */
    func createTestAccountOnBlockchain(account: KinAccount, completionHandler: @escaping (([String: Any]?) -> ())) {
        // Test blockchain URL for account creation
        let createUrlString = "http://friendbot-testnet.kininfrastructure.com?addr=\(account.publicAddress)"
        
        guard let createUrl = URL(string: createUrlString) else { return }
        let request = URLRequest(url: createUrl)
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                print("Account creation on test blockchain failed with error: \(error)")
                completionHandler(nil)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []),
                  let result = json as? [String: Any] else {
                print("Account creation on test blockchain failed with no parsable JSON")
                completionHandler(nil)
                return
            }
            print("Account creation on test blockchain was successful with response data: \(result)")
            completionHandler(result)
        }

        task.resume()
    }

    /**
    Fund the account on the test blockchain.
    */
    func fundTestAccount(account: KinAccount, completionHandler: @escaping ((Bool) -> ())) {
        // The funding URL - it will fund the account with 10000 kins (
        let fundUrlString = "http://faucet-playground.kininfrastructure.com/fund?account=\(account.publicAddress)&amount=6000"
        
        guard let fundUrl = URL(string: fundUrlString) else {
            completionHandler(false)
            return
        }
        let request = URLRequest(url: fundUrl)
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                print("Test account funding failed with error \(error)")
                completionHandler(false)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []),
                  let result = json as? [String: Any] else {
                print("Test account funding failed with no parsable JSON")
                completionHandler(false)
                return
            }
            print("Test account funding returned response data: \(result)")

            // Temporary fix: getting the balance to verify that we have kins on the account
            self.getBalance(forAccount: account, completionHandler: { (kin) in
                guard let kin = kin else {
                    completionHandler(false)
                    return
                }
                completionHandler(kin > 0.0)
            })

            // At the moment, we cannot successfully verify the response data to determine whether the funding was
            // successful or not.
//            guard let success = result["success"] as? Int,
//                success == 0 else {
//                    print("Error Funding account \(result["error"])")
//                    completionHandler(false)
//                    return
//            }
//            completionHandler(true)
        }

        task.resume()
    }
    

    /**
    Sends a transaction to the given account.
    */
    func sendTransaction(fromAccount account: KinAccount,
                         toAddress address: String,
                         kinAmount kin: Kin,
                         memo: String?,
                         completionHandler: ((String?) -> ())?) {
        // Get a transaction envelope object
        account.generateTransaction(to: address, kin: kin, memo: memo) { (envelope, error) in
            if error != nil || envelope == nil {
                print("Could not generate the transaction")
                if let error = error { print("with error: \(error)")}
                completionHandler?(nil)
                return
            }
            // Sends the transaction
            account.sendTransaction(envelope!){ (txId, error) in
                if error != nil || txId == nil {
                    print("Error send transaction")
                    if let error = error { print("with error: \(error)") }
                    completionHandler?(nil)
                    return
                }
                print("Transaction was sent successfully for \(kin) Kins - id: \(txId!)")
                completionHandler?(txId!)
            }
        }
    }

}

