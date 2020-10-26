//
//  Helper.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation

class Helper {
    static func shell(launchPath path: String, arguments args: [String]) -> String {
        print("Helper.shell")
        let task = Process()
        task.launchPath = path
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        task.waitUntilExit()

        return(output!)
    }
}
