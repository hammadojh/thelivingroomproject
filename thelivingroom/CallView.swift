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
    
    // Agora
    
    @State var isLocalInSession = false
    @State var isLocalAudioMuted = false
    @State var isRemoteInSession = true
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
    
    @State var local_point:CGPoint = CGPoint()
    @State var remote_point:CGPoint = CGPoint()
    
    var currentUserId = UUID().uuidString
    
    // sound bigger
    
    let timer = Timer.publish(every: 1, on: .current, in: .common).autoconnect()
   
    @ObservedObject private var mic = MicrophoneMonitor(numberOfSamples: 1)
    
    private func normalizeSoundLevel(level: Float) -> CGFloat {
        let level = max(0.2, CGFloat(level) + 50) / 2 // between 0.1 and 25
        
        return CGFloat(level * (300 / 25)) // scaled to max at 300 (our height of our bar)
    }
    
    @State var local_size:CGFloat = 100
    @State var isTalking:Bool = true
    
    @State var remote_size:CGFloat = 100
    
    // body
    
    var body: some View {
        VStack{
            ZStack{
                
                // local
                VideoSessionView(
                    backColor: Color(.blue),
                    backImage: Image("logo"),
                    hideCanvas: !isLocalInSession,
                    canvas: localCanvas
                ).frame(width: local_size, height: local_size).position(local_point)
                
                
                // remote
                VideoSessionView(
                    backColor: Color(.blue),
                    backImage: Image("big_logo"),
                    hideCanvas: isRemoteVideoMuted || !isRemoteInSession || !isLocalInSession,
                    canvas: remoteCanvas
                ).frame(width: remote_size, height: remote_size).position(remote_point)
                            
                
                //background interaction
                                
                Background {
                       location in
                    
                    // change image location
                    withAnimation {
                        local_point = location
                    }
                    
                    //store in database
                    
                    ref.child("users/\(currentUserId)/").setValue(["id":currentUserId,"x":local_point.x,"y":local_point.y])
                    
                }
            }
            

            // controls
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
        .onAppear {
            // This is our usual steps for joining
            // a channel and starting a call.
            self.initializeAgoraEngine()
            self.setupVideo()
            self.setupLocalVideo()
            self.toggleLocalSession()
            
            ///// observe firebase datachange //// 
            
            ref.child("users").observe(.childChanged) { (snapshot) in
                
                // Get user value
                let value = snapshot.value as? NSDictionary
                
                //id
                let moved_id = value?.value(forKey: "id") as! String
                
                // move
                if moved_id != currentUserId {
                    withAnimation {
                        remote_point.x = value?.value(forKey: "x") as! CGFloat
                        remote_point.y = value?.value(forKey: "y") as! CGFloat
                    }
                }
                
                // sound
                let distance = CGPointDistanceSquared(from: local_point, to: remote_point)
                var volume = Int(100 - ((distance-50)/600)*100)
                if volume < 10 { volume = 10 }
                rtcEngine.adjustPlaybackSignalVolume(volume)
                
            }
        }
        .onReceive(timer) { _ in
            
            // getting the sound leve;
            let level = self.normalizeSoundLevel(level: self.mic.soundSamples[0])
            
            // decide if the person is talking
            if level > 10 {
                self.isTalking = true
            }else{
                self.isTalking = false
            }
            
            // if he is talking make his image bigger
            if self.isTalking{
                withAnimation {
                    self.local_size = self.local_size * 1.1
                }
            }else{
                withAnimation{
                    self.local_size = self.local_size * 0.75
                }
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
