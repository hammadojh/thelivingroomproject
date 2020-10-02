//
//  ContentView.swift
//  thelivingroom
//
//  Created by Omar on 02/10/2020.
//

import SwiftUI

struct ContentView: View {
    
    //models
    var channels:[Channel] = [Channel(name: "My Family")]
    
    var body: some View {
        NavigationView {
            // Family Group
            List(channels, id: \.id){ c in
                NavigationLink(destination:CallView()){
                    Text(c.name)
                }
            }
            .navigationBarTitle("The Living Room")
        }
        .background(Color(.white).opacity(0))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
