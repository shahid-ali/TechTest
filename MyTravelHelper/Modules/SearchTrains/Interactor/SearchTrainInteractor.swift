//
//  SearchTrainInteractor.swift
//  MyTravelHelper
//
//  Created by Satish on 11/03/19.
//  Copyright © 2019 Sample. All rights reserved.
//

import Foundation
import XMLParsing
import Alamofire

class SearchTrainInteractor: PresenterToInteractorProtocol {
	
	private let apiClient=APIClient()  // APIclient instance will be shared among VMs and not be created for each VM
	
    var _sourceStationCode = String()
    var _destinationStationCode = String()
    var presenter: InteractorToPresenterProtocol?

    func fetchallStations() {
        if Reach().isNetworkReachable() == true {
			let _=apiClient.sendRequest(for:Stations.self,url: .getAllStations,method: .get) {[weak self] (result) in
				
				switch result {
					case let .success(stations):
						self?.presenter?.stationListFetched(list:stations.stationsList)
						
						case let .failure(error):
						print("fail \(error)")
						}
			}
		} else {
            self.presenter?.showNoInterNetAvailabilityMessage()
        }
    }

    func fetchTrainsFromSource(sourceCode: String, destinationCode: String) {
        _sourceStationCode = sourceCode
        _destinationStationCode = destinationCode
		
		if Reach().isNetworkReachable() {
			let stationCodeQueryItem = URLQueryItem(name: "StationCode", value:"\(sourceCode)")
			let queryItems=[stationCodeQueryItem]
			let _=apiClient.sendRequest(for:StationData.self,url: .getStationDataByCode,method: .get, queryItems:queryItems) {[weak self] (result) in
				
				switch result {
					case let .success(stationsData):
						if let stationList = stationsData.trainsList,
						   stationList.count > 0
						{
						self?.proceesTrainListforDestinationCheck(trainsList: stationList)
						}
						else
						{
							self?.presenter?.showNoTrainAvailbilityFromSource()
						}
						case let .failure(error):
						print("fail \(error)")
						}
			}
			
        } else {
            self.presenter?.showNoInterNetAvailabilityMessage()
        }
    }
    
    private func proceesTrainListforDestinationCheck(trainsList: [StationTrain]) {
        var _trainsList = trainsList
        let today = Date()
        let group = DispatchGroup()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let dateString = formatter.string(from: today)
        
        for index  in 0...trainsList.count-1 {
            group.enter()

            if Reach().isNetworkReachable() {
				
				let trainIdQueryItem = URLQueryItem(name: "TrainId", value:"\(trainsList[index].trainCode)")
				let trainDateQueryItem = URLQueryItem(name: "TrainDate", value:"\(dateString)")
				
				let queryItems=[trainIdQueryItem,trainDateQueryItem]
				let _=apiClient.sendRequest(for:TrainMovementsData.self,url: .getTrainMovements,method: .get, queryItems:queryItems) {[weak self] (result) in
					
					guard let strongSelf=self else {return}
					
					switch result {
						case let .success(trainMovements):
							let _movements=trainMovements.trainMovements
							let sourceIndex = _movements?.firstIndex(where: {$0.locationCode.caseInsensitiveCompare(strongSelf._sourceStationCode) == .orderedSame})
							let destinationIndex = _movements?.firstIndex(where: {$0.locationCode.caseInsensitiveCompare(strongSelf._destinationStationCode) == .orderedSame})
							let desiredStationMoment = _movements?.filter{$0.locationCode.caseInsensitiveCompare(strongSelf._destinationStationCode) == .orderedSame}
							let isDestinationAvailable = desiredStationMoment?.count == 1

								if isDestinationAvailable  && sourceIndex! < destinationIndex! {
									_trainsList[index].destinationDetails = desiredStationMoment?.first
								}
							
							
							case let .failure(error):
							print("fail \(error)")
							}
					
					group.leave()
				}
			} else {
                self.presenter?.showNoInterNetAvailabilityMessage()
            }
        }

        group.notify(queue: DispatchQueue.main) {[weak self] in
            let sourceToDestinationTrains = _trainsList.filter{$0.destinationDetails != nil}
            self?.presenter?.fetchedTrainsList(trainsList: sourceToDestinationTrains)
        }
    }
}
