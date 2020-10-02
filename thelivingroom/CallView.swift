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
    
    var body: some View {
        VStack{
            ZStack{
                
                // local
                VideoSessionView(
                    backColor: Color(.blue),
                    backImage: Image("logo"),
                    hideCanvas: !isLocalInSession,
                    canvas: localCanvas
                ).frame(width: 112, height: 112).position(local_point)
                
                
                // remote
                VideoSessionView(
                    backColor: Color(.blue),
                    backImage: Image("big_logo"),
                    hideCanvas: isRemoteVideoMuted || !isRemoteInSession || !isLocalInSession,
                    canvas: remoteCanvas
                ).frame(width: 112, height: 112).position(remote_point)
                            
                
                //background interaction
                                
                Background {
                       location in
                    
                    // change image location
                    local_point = location
                    
                    //store in database
                    
                    ref.child("users/\(currentUserId)/").setValue(["id":currentUserId,"x":local_point.x,"y":local_point.y])
                    
//                    //change sound #1
//
//                    let distance = CGPointDistanceSquared(from: CGPoint(x: self.x, y: self.y), to: self.point_1)
//
//                    self.volume = 1 - Float(((distance)/300))
//                    if self.volume < 0.1{ self.volume = 0.1}
//                    self.talking?.setVolume(self.volume, fadeDuration: .greatestFiniteMagnitude)
//
//                    print("distance 1 \(distance)")
//                    print("volume 1 \(self.volume)")
                    
//                    //change sound #2
//
//                    let distance_2 = CGPointDistanceSquared(from: CGPoint(x: self.x, y: self.y), to: self.point_2)
//
//                    self.volume_2 = 1 - Float(((distance_2)/300))
//                    if self.volume_2 < 0.1{ self.volume_2 = 0.1}
//                    self.talking_2?.setVolume(self.volume_2, fadeDuration: .greatestFiniteMagnitude)
//
//                    print("distance 2 \(distance)")
//                    print("volume 2 \(self.volume_2)")
                    
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
        
        }.onAppear {
            // This is our usual steps for joining
            // a channel and starting a call.
            self.initializeAgoraEngine()
            self.setupVideo()
            self.setupLocalVideo()
            self.toggleLocalSession()
            
            //observe firebase datachange
            
            ref.child("users").observe(.childChanged) { (snapshot) in
                
                // Get user value
                let value = snapshot.value as? NSDictionary
                
                //id
                let moved_id = value?.value(forKey: "id") as! String
                
                if moved_id != currentUserId {
                    remote_point.x = value?.value(forKey: "x") as! CGFloat
                    remote_point.y = value?.value(forKey: "y") as! CGFloat
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
