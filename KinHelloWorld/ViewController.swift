//
//  ViewController.swift
//  KinHelloWorld
//
//  Copyright © 2019 Kin Ecosystem. All rights reserved.
//

import UIKit
import KinSDK

class ViewController: UIViewController {

    var kinClient: KinClient!
    var account: KinAccount!
    let linkBag = LinkBag()
    var balanceWatch: BalanceWatch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the Kin client
        initializeKinOnTestNetwork()
        
        deleteFirstAccount()
        
        // Get any stored existing user account
        if let existingAccount = getAccount() {
            print("Current account with address \(existingAccount.publicAddress)")
            account = existingAccount
        }
        // or else create an account with the client
        else if let newAccount = createLocalAccount() {
            print("Created account with address \(newAccount.publicAddress)")
            account = newAccount
        }
        
        
        let json = try! account.export(passphrase: "bla")
        print(json)
        
        watchCreation(forAccount: account)
        
        printStatus(forAccount: account, completionHandler: nil)
//        printBalance(forAccount: account)
        
        account.status { (status: AccountStatus?, error: Error?) in
            guard let status = status else { return }
            if status == .notCreated {
                self.createTestAccountOnBlockchain(account: self.account) { (result: [String : Any]?) in
                    print("Account was created ")
                    self.printStatus(forAccount: self.account) { (status) in
                        self.fundTestAccount(account: self.account, completionHandler: { (success) in
                            guard success else {
                                print("Cannot send kins")
                                return
                            }
                            print("Account was funded - sending kins")
                            self.printStatus(forAccount: self.account, completionHandler: nil)
                            let toAddress = "GDXTTWKMVNFMEX3HGU7DNVOOXIUP6KM7YANENXILHUCZFHG2IGSK352K"
                            self.sendTransaction(fromAccount: self.account,
                                                 toAddress: toAddress,
                                                 kinAmount: 10,
                                                 memo: "Test") { txId in
                                                    print("DONE!!!!!")
                            }

                        })
                    }
                }
            } else {
                self.printBalance(forAccount: self.account)
//                self.fundTestAccount(account: self.account, completionHandler: { (info) in
//                    self.printBalance(forAccount: self.account)
//                })
                
                print("The account is activated and can send funds")
                let toAddress = "GDXTTWKMVNFMEX3HGU7DNVOOXIUP6KM7YANENXILHUCZFHG2IGSK352K"
                self.sendTransaction(fromAccount: self.account,
                                     toAddress: toAddress,
                                     kinAmount: 9.8,
                                     memo: "Test") { txId in
                                        print("DONE!!!!!")
                }
            }
        }
    }

    func initializeKinOnTestNetwork() {
        guard let providerUrl = URL(string: "http://horizon-testnet.kininfrastructure.com") else { return }
        do {
            let appId = try AppId("test")
            kinClient = KinClient(with: providerUrl, network: .testNet, appId: appId)
        } catch let error {
            print("Error \(error)")
        }
    }
    
    func getAccount() -> KinAccount? {
        return kinClient.accounts.first
    }
    
    func createLocalAccount() -> KinAccount? {
        do {
            let account = try kinClient.addAccount()
            return account
        } catch let error {
            print("Error adding an account \(error)")
        }
        return nil
    }
    
    func deleteFirstAccount() {
        do {
            try kinClient.deleteAccount(at: 0)
            print("Account delete!")
        } catch let error {
            print("Could not delete account \(error)")
        }

    }
    
    func printBalance(forAccount account: KinAccount) {
        account.balance()
            .then { (balance: Kin) in
                print("1) balance is \(balance)")
            }
            .error { (error:Error) in
                print("1) Got an error with getting the balance \(error)")
            }
    }
    
    func printBalance2(forAccount account: KinAccount, completionHandler: ((Kin?) -> ())?) {
        account.balance { (balance: Kin?, error: Error?) in
            if let error = error {
                print("2) Error getting the balance \(error)")
                if let completionHandler = completionHandler {
                    completionHandler(nil)
                }
                return
            }
            guard let balance = balance else {
                print("2) Error, no balance")
                if let completionHandler = completionHandler {
                    completionHandler(nil)
                }
                return
            }
            if let completionHandler = completionHandler {
                completionHandler(balance)
            }
            print("2) Balance for account \(balance)")
        }
    }
    
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
    
    func printStatus(forAccount account: KinAccount,
                     completionHandler: ((AccountStatus?) -> ())?) {
        account.status { (status: AccountStatus?, error: Error?) in
            if let error = error {
                print("Error getting status \(error)")
                if let completionHandler = completionHandler {
                    completionHandler(nil)
                }
                return
            }
            guard let status = status else { return }
            print("Status \(status)")
            if let completionHandler = completionHandler {
                completionHandler(status)
            }
        }
    }
    
    func createTestAccountOnBlockchain(account: KinAccount, completionHandler: @escaping (([String: Any]?) -> ())) {
        let createUrlString = "http://friendbot-testnet.kininfrastructure.com?addr=\(account.publicAddress)"
        
        guard let createUrl = URL(string: createUrlString) else { return }
        let request = URLRequest(url: createUrl)
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                print("Error \(error)")
                completionHandler(nil)
                return
            }
            guard let data = data,
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let result = json as? [String: Any] else {
                    print("Unable to parse json")
                    completionHandler(nil)
                    return
            }
            print("Result of test account creation \(result)")
            completionHandler(result)
        }
        task.resume()
    }
    
    func fundTestAccount(account: KinAccount, completionHandler: @escaping ((Bool) -> ())) {
        let fundUrlString = "http://faucet-playground.kininfrastructure.com/fund?account=\(account.publicAddress)&amount=6000"
        
        guard let fundUrl = URL(string: fundUrlString) else {
            completionHandler(false)
            return
        }
        let request = URLRequest(url: fundUrl)
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                print("Error Funding the account \(error)")
                completionHandler(false)
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let result = json as? [String: Any] else {
                    print("Unable to parse json")
                    completionHandler(false)
                    return
            }
            print("Fund request response \(result)")
            
            self.printBalance2(forAccount: account, completionHandler: { (kin) in
                completionHandler(true)
            })
            
//            guard let success = result["sucess"] as? Int,
//                success == 0 else {
//                    print("Error Funding account \(result["error"])")
//                    completionHandler(false)
//                    return
//            }
//            completionHandler(true)
        }
        task.resume()
    }
    
    func sendTransaction(fromAccount account: KinAccount, toAddress address: String,
                         kinAmount kin: Kin,
                         memo: String?,
                         completionHandler: ((String?) -> ())?) {
        account.generateTransaction(to: address, kin: kin, memo: memo) { (envelope, error) in
            if let error = error {
                print("Could not generate the transaction \(error)")
                completionHandler?(nil)
                return
            }
            guard let envelope = envelope else {
                completionHandler?(nil)
                return
            }
            account.sendTransaction(envelope){ (txId, error) in
                if let error = error {
                    print("Error send transaction \(error)")
                    completionHandler?(nil)
                    return
                }
                guard let txId = txId else {
                    print("Error no transaction id")
                    completionHandler?(nil)
                    return
                }
                print("Sent transaction \(txId) OK!")
                completionHandler?(txId)
            }
        }
        
    }
    
}

