//
//  Splash.swift
//  thelivingroom
//
//  Created by Omar on 03/10/2020.
//

import SwiftUI

struct Splash: View {
    var body: some View {
        Image("splash").resizable().aspectRatio(contentMode: .fill).ignoresSafeArea(.all)
    }
}

struct Splash_Previews: PreviewProvider {
    static var previews: some View {
        Splash()
    }
}
