//
//  LocalFileManager.swift
//  
//
//  Created by Kristiina Rahkema on 26.10.2020.
//

import Foundation

protocol LocalFileManager {
    func fetchAllFiles(folderPath: String) -> [URL]
    func fetchProjectFiles(folderPath: String) -> [URL]
    
    var ignoreWithPathComponents: [String] {get}
    var allowedEndings: [String] {get}
}
