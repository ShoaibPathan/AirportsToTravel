//
//  LaunchViewModel.swift
//  worldAirports
//
//  Created by Mario Acero on 9/9/18.
//  Copyright © 2018 MarioAcero. All rights reserved.
//

import Foundation

class LaunchViewModel: BaseViewModel {
    
    
    private var totalAirpotData: Int = 0
    private var offSet = 0
    var progressByRequest: Float = 0.0
    var totalProgress: Float = 0.0
    
    var updateProgressBar: ((Float)->())?
    var goToSearchAirports: (()->())?
    var isGetingData: Bool = false
    
    override init() {
        super.init()
    }
    
    func getAirportsData() {
        let airportsFromCache: AirportsDictionary = RealmManager.shared.getAll(Class: AirportsRealm.self)
        if !airportsFromCache.isEmpty && !isGetingData{
            goToSearchAirports?()
            return
        }
        
        if EnvironmentConfiguration.accesToken != nil {
            let authData = RealmManager.shared.getAll(Class: AuthRealm.self)
            guard  (authData.first?.accesToken) != nil else {
                return
            }
            
            networkProvider.getAirPorts(offset: offSet, completion: { [weak self ](result) in
                guard let strongSelf = self else { return }
                
                strongSelf.isGetingData = true
                
                switch result {
                case .success(let jsonData):
                    
                    var json: [String:Any]?
                    if let data = jsonData?.data {
                        do {
                            json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any]
                        } catch {
                            print("error json format")
                            return
                        }
                    }
                    
                    guard let root = json!["AirportResource"] as? [String: Any],
                        let airportMain = root["Airports"] as? [String: Any],
                        let airPortsDictionary = airportMain["Airport"] as? [[String: Any]] else {
                            return
                    }
                    
                    guard let metaDic = root["Meta"] as? [String: Any],
                        let totalCount = metaDic["TotalCount"] as? Int else {
                            return
                    }
                    
                    strongSelf.totalAirpotData = totalCount
                    
                    strongSelf.totalProgress += strongSelf.progressByRequest
                    strongSelf.updateProgressBar?(strongSelf.totalProgress)
                    
                    let totalDictContent = airPortsDictionary.count
                    for i in 0..<totalDictContent {
                        guard let airportData = RawAirPort(jsonData: airPortsDictionary[i] ) else {
                            continue
                        }
                        let airportCache = AirportsRealm()
                        airportCache.name = airportData.name
                        airportCache.airportCode = airportData.airportCode
                        airportCache.latitude.value = airportData.latitude
                        airportCache.longitude.value = airportData.longitude
                        RealmManager.shared.addObject(object: airportCache, update: true)
                    }
                    
                    if strongSelf.progressByRequest == 0.0 {
                        strongSelf.progressByRequest = Float(totalCount)/12000.0
                    }
                    
                    
                    if totalCount > strongSelf.offSet {
                        strongSelf.offSet += 100
                        if strongSelf.offSet > totalCount {
                            strongSelf.isGetingData = false
                        }
                        strongSelf.getAirportsData()
                        
                    }
                default:
                    break
                }
            })
        }else {
            getAccesToken {
                self.getAirportsData()
            }
        }
    }
    
    
}
