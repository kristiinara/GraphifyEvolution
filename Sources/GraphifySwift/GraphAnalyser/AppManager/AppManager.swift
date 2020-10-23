//
//  AppManager.swift
//  
//
//  Created by Kristiina Rahkema on 16.09.2020.
//

import Foundation

protocol AppManager {
    func nextAppVersion() -> AppVersion?
    func newAppManager(path: String) -> AppManager
}
