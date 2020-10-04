//
//  ContentView.swift
//  thelivingroom
//
//  Created by Omar on 02/10/2020.
//

import SwiftUI

struct ContentView: View {
    
    @State var isSplashActive = true
    
    var body: some View {
        if(isSplashActive){
            Splash().onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        self.isSplashActive = false
                    }
                }
            }
        }else{
            Home()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
