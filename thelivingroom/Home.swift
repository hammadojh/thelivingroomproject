//
//  Home.swift
//  thelivingroom
//
//  Created by Omar on 03/10/2020.
//

import SwiftUI

struct Home: View {
    
    //models
    var channels:[Channel] = [Channel(name: "New Living Room",image:"new-circle"),Channel(name: "My Friends",image:"empty-group", online:["Omar","Zoe"])]
    
    @State var isCallPresented = false
    
    var body: some View {
        
        ZStack(alignment:.top){
            Color(hex: "ffffc2").ignoresSafeArea(.all)
            VStack{
                Text("The Living Room").font(.system(size: 40, weight: Font.Weight.regular, design: .serif)).foregroundColor(Color(hex: "004037")).padding(.bottom,16)
                VStack(alignment:.leading){
                    ForEach(channels, id: \.id){ c in
                        Button(action: {
                            isCallPresented.toggle()
                        }, label: {
                            HStack{
                                ZStack{
                                    Image(c.image).resizable().aspectRatio(contentMode: .fit).padding([.top,.bottom,.trailing],10)
                                }
                                VStack(alignment:.leading){
                                    Text(c.name).font(.system(size: 22, weight: Font.Weight.regular, design: .serif)).foregroundColor(.black)
                                    if !c.online.isEmpty{
                                        HStack{
                                            ForEach(c.online, id:\.self){ o in
                                                HStack{
                                                    Circle().frame(width:16,height:16).foregroundColor(Color(hex: "5D942A"))
                                                    Text(o).foregroundColor(.black).aspectRatio(contentMode: .fill)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        })
                        .frame(height: 100)
                        .fullScreenCover(isPresented: $isCallPresented, content: CallView.init)
                        .listRowBackground(Color.red)
                    }
                    //spacer
                    Spacer()
                }.padding(.top,20).frame(width:UIScreen.main.bounds.width-60,height: UIScreen.main.bounds.height-200).background(Color(hex: "fff9b7")).cornerRadius(20)
                
            }.padding(32)
        }
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        Home()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}
