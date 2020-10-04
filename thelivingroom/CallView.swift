//
//  CallView.swift
//  thelivingroom
//
//  Created by Omar on 02/10/2020.
//

import SwiftUI
import AgoraRtcKit
import Firebase

struct CallView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    var currentUserId = UUID().uuidString
    
    // Agora
    
    @State var isLocalInSession = false
    @State var isLocalAudioMuted = false
    @State var isRemoteInSession = false
    @State var isRemoteVideoMuted = true
    
    let localCanvas = VideoCanvas()
    let remoteCanvas = VideoCanvas()
    
    private let videoEngine = VideoEngine()
    
    private var rtcEngine: AgoraRtcEngineKit {
        get {
            return videoEngine.agoraEngine
        }
    }
    
    // video location
    @ObservedObject var local_circle = VideoCircle(CGPoint(x: 0, y: 0), 100)
    @ObservedObject var remote_circle = VideoCircle(CGPoint(x: 150, y: 300),100)
    
    // sound bigger
    
    let timer = Timer.publish(every: 0.1, on: .current, in: .common).autoconnect()
   
    @ObservedObject private var mic = MicrophoneMonitor(numberOfSamples: 1)
    
    private func normalizeSoundLevel(level: Float) -> CGFloat {
        let level = max(0.2, CGFloat(level) + 50) / 2 // between 0.1 and 25
        
        return CGFloat(level * (300 / 25)) // scaled to max at 300 (our height of our bar)
    }
    
    @State var isTalking:Bool = true
    
    // body
    
    var body: some View {
        
        ZStack(alignment:.center){
            // background
            Image("living-room").resizable().aspectRatio(contentMode: .fill).ignoresSafeArea(.all)
            
            // content
            VStack{
                ZStack{
                    
                    //choose a place
                    if !isLocalInSession {
                        Text("Choose a point to join the chat")
                    }
                                    
                    // local
                    if isLocalInSession{
                        
                            VideoSessionView(
                            backColor: Color(.blue),
                            backImage: Image("logo"),
                            hideCanvas: !isLocalInSession,
                            canvas: localCanvas
                            ).frame(width: local_circle.size, height: local_circle.size).position(local_circle.point)
                    }
                    
                    // remote
                    if isRemoteInSession{
                        VideoSessionView(
                            backColor: Color(.blue),
                            backImage: Image("big_logo"),
                            hideCanvas: isRemoteVideoMuted || !isRemoteInSession || !isLocalInSession,
                            canvas: remoteCanvas
                        ).frame(width: remote_circle.size, height: remote_circle.size).position(remote_circle.point)
                    }
                    
                    //background interaction
                    Background {
                           location in
                        
                        // join channel first time
                        if (!isLocalInSession){
                            self.toggleLocalSession()
                        }
                        
                        //circle location
                        
                        let tapped_location = location
                        
                        let distance = CGFloat(CGPointDistanceSquared(from: tapped_location, to: remote_circle.point))
                        
                        if (distance < (local_circle.size/2.0) + (remote_circle.size/2.0)) {
                            
                            var slope:CGFloat = 0
                            
                            if remote_circle.point.x != local_circle.point.x {
                                slope = (tapped_location.y - remote_circle.point.y) / (tapped_location.x - remote_circle.point.x)
                            }
                            
                            slope *= -1
                            let degree = atan(slope)
                            let alpha = CGFloat((Double.pi/2)) - degree
                            
                            let offset = remote_circle.size/2 + local_circle.size/2 - distance
                            
                            let x_offset = sin(alpha) * offset
                            let y_offset = cos(alpha) * offset
                            
                            if tapped_location.x >= remote_circle.point.x {
                                withAnimation {
                                    local_circle.point.x = tapped_location.x + x_offset
                                    local_circle.point.y = tapped_location.y - y_offset
                                }
                            }else{
                                withAnimation{
                                    local_circle.point.x = tapped_location.x - x_offset
                                    local_circle.point.y = tapped_location.y + y_offset
                                }
                            }
                            
                            print("new point (\(local_circle.point.x),\(local_circle.point.y)")
                            
                        }
                        
                        else{
                            withAnimation{
                                local_circle.point = tapped_location
                            }
                        }
                        
                        
                        //store in database
                        ref.child("users/\(currentUserId)/").setValue(["id":currentUserId,"x":local_circle.point.x,"y":local_circle.point.y,"size":local_circle.size])
                        
                        
                    }
                }
                

                // controls
                if isLocalInSession{
                    HStack {
                        Button(action: toggleLocalAudio) {
                            Image(isLocalAudioMuted ? "mute" : "mic")
                                .resizable()
                        }.frame(width: 55, height: 55)
                        Button(action: toggleLocalSession) {
                            Image(isLocalInSession ? "end" : "call")
                                .resizable()
                        }.frame(width: 70, height: 70)
                        Button(action: switchCamera) {
                            Image("switch").resizable()
                        }.frame(width: 55, height: 55)
                    }.padding()
                }
            
            }
            .onAppear {
                
                // This is our usual steps for joining
                // a channel and starting a call.
                self.initializeAgoraEngine()
                self.setupVideo()
                self.setupLocalVideo()
                
                ///// observe firebase datachange ////
                
                ref.child("users").observe(.childChanged) { (snapshot) in

                    // Get user value
                    let value = snapshot.value as? NSDictionary

                    //id
                    let moved_id = value?.value(forKey: "id") as! String

                    // move
                    if moved_id != currentUserId {
                        withAnimation {
                            remote_circle.point.x = value?.value(forKey: "x") as! CGFloat
                            remote_circle.point.y = value?.value(forKey: "y") as! CGFloat
                            remote_circle.size = value?.value(forKey: "size") as! CGFloat
                        }
                    }

                    // sound
                    let distance = CGPointDistanceSquared(from: local_circle.point, to: remote_circle.point)
                    var volume = Int(100 - ((distance-50)/600)*100)
                    if volume < 10 { volume = 10 }
                    rtcEngine.adjustPlaybackSignalVolume(volume)

                }
            }
            .onReceive(timer) { _ in
                
                // getting the sound leve;
                let level = self.normalizeSoundLevel(level: self.mic.soundSamples[0])
                
                print("sound level \(level)")
                
                // decide if the person is talking
                if level > 100 {
                    self.isTalking = true
                }else{
                    self.isTalking = false
                }
                
                // if he is talking make his image bigger
                
                let max_size = UIScreen.main.bounds.width
                let min_size:CGFloat = 10.0

                if self.isTalking{
                    withAnimation {
                        if self.local_circle.size <= max_size {
                            self.local_circle.size += 1
                            ref.child("users/\(currentUserId)/").setValue(["id":currentUserId,"x":local_circle.point.x,"y":local_circle.point.y,"size":local_circle.size])
                        }
                    }

                }else{
                    withAnimation{
                        if self.local_circle.size >= min_size {
                            self.local_circle.size -= 1
                            ref.child("users/\(currentUserId)/").setValue(["id":currentUserId,"x":local_circle.point.x,"y":local_circle.point.y,"size":local_circle.size])
                        }
                    }
                }
                
                // if overlapped move the smaller
                
                let distance = CGFloat(CGPointDistanceSquared(from: local_circle.point, to: remote_circle.point))
                
                if (distance < (local_circle.size/2.0) + (remote_circle.size/2.0)) {
                    
                    var slope:CGFloat = 0
                    
                    if remote_circle.point.x != local_circle.point.x {
                        slope = (local_circle.point.y - remote_circle.point.y) / (local_circle.point.x - remote_circle.point.x)
                    }
                    
                    slope *= -1
                    let degree = atan(slope)
                    let alpha = CGFloat((Double.pi/2)) - degree
                    
                    let offset = remote_circle.size/2 + local_circle.size/2 - distance
                    
                    let x_offset = sin(alpha) * offset
                    let y_offset = cos(alpha) * offset
                    
                    // move the smaller
                    var larger_circle = self.local_circle
                    var smaller_circle = self.remote_circle
            
                    if (larger_circle.size < smaller_circle.size){
                        let temp = larger_circle
                        larger_circle = smaller_circle
                        smaller_circle = temp
                    }
                    
                    if smaller_circle.point.x >= larger_circle.point.x {
                        withAnimation {
                            smaller_circle.point.x = smaller_circle.point.x + x_offset
                            smaller_circle.point.y = smaller_circle.point.y - y_offset
                        }
                    }else{
                        withAnimation{
                            smaller_circle.point.x = smaller_circle.point.x - x_offset
                            smaller_circle.point.y = smaller_circle.point.y + y_offset
                        }
                    }
                    
                                    
                }
                
                // increase/decrease sound
                var volume = Int(100 - ((distance-50)/600)*100)
                if volume < 10 { volume = 10 }
                rtcEngine.adjustPlaybackSignalVolume(volume)
                
            }
        }
    }
}


extension CallView {
    func log(content: String) {
        print(content)
    }
}

fileprivate extension CallView {
    
    func initializeAgoraEngine() {
        // init AgoraRtcEngineKit
        videoEngine.contentView = self
    }
    
    func setupVideo() {
        // In simple use cases, we only need to enable video capturing
        // and rendering once at the initialization step.
        // Note: audio recording and playing is enabled by default.
        rtcEngine.enableVideo()
        
        // Set video configuration
        // Please go to this page for detailed explanation
        // https://docs.agora.io/en/Voice/API%20Reference/oc/Classes/AgoraRtcEngineKit.html#//api/name/setVideoEncoderConfiguration:
        
        rtcEngine.setVideoEncoderConfiguration(
            AgoraVideoEncoderConfiguration(
                size: AgoraVideoDimension640x360,
                frameRate: .fps15,
                bitrate: AgoraVideoBitrateStandard,
                orientationMode: .adaptative
        ))
    }
    
    func setupLocalVideo() {
        // This is used to set a local preview.
        // The steps setting local and remote view are very similar.
        // But note that if the local user do not have a uid or do
        // not care what the uid is, he can set his uid as ZERO.
        // Our server will assign one and return the uid via the block
        // callback (joinSuccessBlock) after
        // joining the channel successfully.
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.view = localCanvas.rendererView
        videoCanvas.renderMode = .hidden
        rtcEngine.setupLocalVideo(videoCanvas)
    }
    
    func joinChannel() {
        // Set audio route to speaker
        rtcEngine.setDefaultAudioRouteToSpeakerphone(true)
        
        // 1. Users can only see each other after they join the
        // same channel successfully using the same app id.
        // 2. One token is only valid for the channel name that
        // you use to generate this token.
        rtcEngine.joinChannel(byToken: Token, channelId: "default", info: nil, uid: 0, joinSuccess: nil)
    }

    func leaveChannel() {
        // leave channel and end chat
        rtcEngine.leaveChannel(nil)
    }
}

fileprivate extension CallView {
    func toggleLocalSession() {
        isLocalInSession.toggle()
        if isLocalInSession {
            joinChannel()
        } else {
            leaveChannel()
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    func switchCamera() {
        rtcEngine.switchCamera()
    }
    
    func toggleLocalAudio() {
        isLocalAudioMuted.toggle()
        // mute/unmute local audio
        rtcEngine.muteLocalAudioStream(isLocalAudioMuted)
    }
}

// background interaction

func CGPointDistanceSquared(from: CGPoint, to: CGPoint) -> CGFloat {
    return sqrt((from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y))
}

struct Background:UIViewRepresentable {
    
    var tappedCallback: ((CGPoint) -> Void)

    func makeUIView(context: UIViewRepresentableContext<Background>) -> UIView {
        let v = UIView(frame: .zero)
        let gesture = UITapGestureRecognizer(target: context.coordinator,action: #selector(Coordinator.tapped))
        v.addGestureRecognizer(gesture)
        return v
    }

    class Coordinator: NSObject {
        var tappedCallback: ((CGPoint) -> Void)
        init(tappedCallback: @escaping ((CGPoint) -> Void)) {
            self.tappedCallback = tappedCallback
        }
        @objc func tapped(gesture:UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            self.tappedCallback(point)
        }
    }

    func makeCoordinator() -> Background.Coordinator {
        return Coordinator(tappedCallback:self.tappedCallback)
    }

    func updateUIView(_ uiView: UIView,
                       context: UIViewRepresentableContext<Background>) {
    }

}

struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        CallView()
    }
}
