//
//  VideoCircle.swift
//  thelivingroom
//
//  Created by Omar on 03/10/2020.
//

import SwiftUI

class VideoCircle:ObservableObject {
    @Published var point:CGPoint = CGPoint()
    @Published var size:CGFloat = CGFloat()
    
    init(_ point:CGPoint,_ size:CGFloat) {
        self.point = point
        self.size = size
    }
}
