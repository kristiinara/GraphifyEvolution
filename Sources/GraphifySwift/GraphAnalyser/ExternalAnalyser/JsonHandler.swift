//
//  JsonHandler.swift
//  GraphifySwift
//
//  Created by Kristiina Rahkema on 12.02.2021.
//

import Foundation

class JsonHandler {
    static func jsonFromData(data: Data) -> [String: Any]? {
        do {
            //create json object from data
            if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                return json
            } else {
                return nil
            }
        } catch let error {
            print(error.localizedDescription)
            return nil
        }
    }

    static func jsonFromPath(path: String) -> [String: Any]? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return self.jsonFromData(data: data)
        } catch let error {
            print(error.localizedDescription)
            return nil
        }
    }
}
