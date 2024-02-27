//
//  Array+Extensions.swift
//  metal-brush
//
//  Created by azun on 27/02/2024.
//

import Foundation

extension Array {
    
    /// Returns the memory size/footprint (in bytes) of a given array.
    ///
    /// - Returns: Integer value representing the memory size the array.
    func size() -> Int {
        guard !isEmpty else { return 0 }
        return count * MemoryLayout.size(ofValue: self[0])
    }
}
