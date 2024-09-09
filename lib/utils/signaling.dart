import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'peripheral.dart';
import 'central.dart';
// import '../utils/screen_select_dialog.dart';
// import 'random_string.dart';

import 'device_info.dart'
    if (dart.library.js) 'device_info_web.dart';
// import '../utils/websocket.dart'
//     if (dart.library.js) '../utils/websocket_web.dart';
// import '../utils/turn.dart' if (dart.library.js) '../utils/turn_web.dart';

enum SignalingState {
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

enum CallState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
}

enum VideoSource {
  Camera,
  Screen,
}

class Session {
  Session({required this.sid, required this.pid});
  String pid;
  String sid;
  RTCPeerConnection? pc;
  RTCDataChannel? dc;
  List<RTCIceCandidate> remoteCandidates = [];
}

class Device {
  Device(this.name, this.address);

  String name;
  String address;
}

class IntervalSender {
  IntervalSender( this.writeMessage);

  List<String> sendContents = [];
  int nowIndex = -1;
  int preIndex = -1;
  bool stopSend = false;
  bool isSending = false;
  Function(String content) writeMessage;

  //一回呼び出せば送信し続ける
  Future<void> intervalSend() async{
    isSending = true;
    while(true){
      await Future.delayed(Duration(milliseconds: 300));
      if(preIndex < nowIndex){
        preIndex += 1;
        writeMessage(sendContents[preIndex]);
      }
      if(stopSend) break;
    }
  }

  void addContent(String content){
    sendContents.add(content);
    nowIndex += 1;
  }

  // void addContent(String content){
  //   int length = content.length;
  //   int stringNow = 0;
  //   while(length > stringNow + mtu){
  //     sendContents.add(content.substring(stringNow,stringNow + mtu));
  //     stringNow += mtu;
  //     nowIndex += 1;
  //   }
  //   sendContents.add(content + '*');
  //   nowIndex += 1;
  // }

  void stop(){
    stopSend = true;
  }

}

class Signaling {
  Signaling();

  JsonEncoder _encoder = JsonEncoder();
  JsonDecoder _decoder = JsonDecoder();
  late String _selfId;
  late String _peerId;
  late String _remotePeerName;

  String fulltext = "";
  var _turnCredential;
  Map<String, Session> _sessions = {};
  MediaStream? _localStream;
  List<MediaStream> _remoteStreams = <MediaStream>[];
  List<RTCRtpSender> _senders = <RTCRtpSender>[];
  VideoSource _videoSource = VideoSource.Camera;
  bool isCentral = false;

  late Peripheral peripheral;
  late Central central;
  late int bleMtuSize;
  late IntervalSender intervalSender;



  Function(SignalingState state)? onSignalingStateChange;
  Function(Session session, CallState state)? onCallStateChange;
  Function(MediaStream stream)? onLocalStream;
  Function(Session session, MediaStream stream)? onAddRemoteStream;
  Function(Session session, MediaStream stream)? onRemoveRemoteStream;
  Function(dynamic event)? onPeersUpdate;
  Function(Session session, RTCDataChannel dc, RTCDataChannelMessage data)?
      onDataChannelMessage;
  Function(Session session, RTCDataChannel dc)? onDataChannel;

  String get sdpSemantics => 'unified-plan';

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
      */
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  void randomNumeric(int n){
    String randomName = '';
    var random = math.Random();
    for(int i=0;i<n;i++){
      randomName = randomName + random.nextInt(10).toString();
    }
    _selfId = randomName;
  }

  Future<void> init()async {
    randomNumeric(6);
    peripheral = Peripheral(
        getMtu: getMtu,
        receivedMessage: onMessage,
    );
    await peripheral.init();
  }

  Future<void> setCentral(BluetoothDevice device)async {
    isCentral = true;
    central = Central(
        device: device,
        onreadMessage: onMessage,//callback関数でうまいことcentral.dart内のreadした値を受け取る
        getMtu: getMtu,
        createIdOffer: createIdOffer,//central.discoverServices()が終わった後に実行したいからcallbackする
    );
    await central.init();//connect,mtu,サービスと特性の検出,subscribeまで行う
  }

  // void receivedMessage(String text){ //centralのread
  //   print(text);
  //   print("callback success!!");
  // }

  void getMtu(int mtu){
    bleMtuSize = mtu-17;
    print("mtuSize:{$bleMtuSize}");
    intervalSender = IntervalSender(writeMessage);
  }

  Future<void> writeMessage(String content) async {
    content = '$content*';
    int length = content.length;
    log('$length');
    int listNow = 0;
    for (int i = bleMtuSize; i < length; listNow = listNow + bleMtuSize, i = i + bleMtuSize) {
      if(isCentral){
        await central.onWrite(content.substring(listNow, i));
      }else{
        await peripheral.updateCharacteristic(content.substring(listNow, i));}
      log('send: ${content.substring(listNow,i)}');
    }
    if(isCentral){
      await central.onWrite(content.substring(listNow, length));
    }else{
      await peripheral.updateCharacteristic(content.substring(listNow, length));}
    log('send: ${content.substring(listNow,length)}');
  }

  // void setIntervalSender(){
  //   _intervalsender = IntervalSender(platform);
  // }

  String getSelfId(){
    return _selfId;
  }

  close() async {
    await _cleanSessions();
    //_socket?.close();
  }

  void invite(String peerId, String media, bool useScreen) async {
    var sessionId = _selfId + '-' + peerId;
    Session session = await _createSession(null,
        peerId: peerId,
        sessionId: sessionId,
        media: media,
        screenSharing: useScreen);
    _sessions[sessionId] = session;
    log('session created');
    if (media == 'data') {
      _createDataChannel(session);
    }
    _createOffer(session, media);
    onCallStateChange?.call(session, CallState.CallStateNew);
    onCallStateChange?.call(session, CallState.CallStateInvite);
  }

  void bye(String sessionId) {
    _send('bye', {
      'session_id': sessionId,
      'from': _selfId,
    });
    var sess = _sessions[sessionId];
    if (sess != null) {
      _closeSession(sess);
    }
  }

  // void accept(String sessionId) {
  //   var session = _sessions[sessionId];
  //   if (session == null) {
  //     return;
  //   }
  //   _createAnswer(session, 'video');
  // }

  void reject(String sessionId) {
    var session = _sessions[sessionId];
    if (session == null) {
      return;
    }
    bye(session.sid);
  }

  void onMessage(messageJson) async {
    fulltext = fulltext + messageJson;
    print('fulltext: $fulltext');
    if(messageJson[messageJson.length-1]!='*'){
      return;
    }
    String text = fulltext.substring(0,fulltext.length-1);
    fulltext = '';
    print(text);
    Map<String, dynamic> mapData = _decoder.convert(text);
    var data = mapData['data'];

    switch (mapData['type']) {
      // case 'peers':
      //   {
      //     List<dynamic> peers = data;
      //     if (onPeersUpdate != null) {
      //       Map<String, dynamic> event = Map<String, dynamic>();
      //       event['self'] = _selfId;
      //       event['peers'] = peers;
      //       onPeersUpdate?.call(event);
      //     }
      //   }
      //   break;
      case 'IdOffer':
        _remotePeerName = mapData['data']['myName'];
        _peerId = mapData['data']['Id'];
        createIdAnswer();
      case 'IdAnswer':
        _remotePeerName = mapData['data']['myName'];
        _peerId = mapData['data']['Id'];
        invite(_peerId, "data", false);
      case 'offer':
        {
          var peerId = data['from'];
          var description = data['description'];
          var media = data['media'];
          var sessionId = data['session_id'];
          var session = _sessions[sessionId];
          var newSession = await _createSession(session,
              peerId: peerId,
              sessionId: sessionId,
              media: media,
              screenSharing: false);
          _sessions[sessionId] = newSession;
          log('session created');
          await newSession.pc?.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
          await _createAnswer(newSession, media);

          if (newSession.remoteCandidates.length > 0) {
            newSession.remoteCandidates.forEach((candidate) async {
              await newSession.pc?.addCandidate(candidate);
              log('candidates added');
            });
            log('candidatesssssssssssssssssssssss!!!!!!');
            newSession.remoteCandidates.clear();
          }
          onCallStateChange?.call(newSession, CallState.CallStateNew);
          log('newwwwwwwwwwwwwwwwww');
          onCallStateChange?.call(newSession, CallState.CallStateRinging);

        }
        intervalSender.intervalSend();
        break;
      case 'answer':
        {
          var description = data['description'];
          var sessionId = data['session_id'];
          var session = _sessions[sessionId];
          session?.pc?.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
          onCallStateChange?.call(session!, CallState.CallStateConnected);
        }
        intervalSender.intervalSend();
        break;
      case 'candidate':
        {
          var peerId = data['from'];
          var candidateMap = data['candidate'];
          var sessionId = data['session_id'];
          var session = _sessions[sessionId];
          RTCIceCandidate candidate = RTCIceCandidate(candidateMap['candidate'],
              candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);

          if (session != null) {
            if (session.pc != null) {
              await session.pc?.addCandidate(candidate);
            } else {
              session.remoteCandidates.add(candidate);
            }
          } else {
            _sessions[sessionId] = Session(pid: peerId, sid: sessionId)
              ..remoteCandidates.add(candidate);
          }
        }
        break;
      case 'leave':
        {
          var peerId = data as String;
          _closeSessionByPeerId(peerId);
        }
        break;
      case 'bye':
        {
          var sessionId = data['session_id'];
          print('bye: ' + sessionId);
          var session = _sessions.remove(sessionId);
          if (session != null) {
            onCallStateChange?.call(session, CallState.CallStateBye);
            _closeSession(session);
          }
        }
        break;
      case 'keepalive':
        {
          print('keepalive response!');
        }
        break;
      // case 'IdOffer':
      //   {
      //     _selfId = data['Id'];
      //   }
      //   break;
      // case 'IdAnswer':
      //   {
      //     _selfId = data['Id'];
      //   }
      //   break;
      default:
        break;
    }
  }

  // Future<void> connect() async {
    // var url = 'https://$_host:$_port/ws';
    //
    // _socket = SimpleWebSocket(url);
    //
    // print('connect to $url');
    //
    // if (_turnCredential == null) {
    //   try {
    //     _turnCredential = await getTurnCredential(_host, _port);
    //     /*{
    //         "username": "1584195784:mbzrxpgjys",
    //         "password": "isyl6FF6nqMTB9/ig5MrMRUXqZg",
    //         "ttl": 86400,
    //         "uris": ["turn:127.0.0.1:19302?transport=udp"]
    //       }
    //     */
    //     _iceServers = {
    //       'iceServers': [
    //         {
    //           'urls': _turnCredential['uris'][0],
    //           'username': _turnCredential['username'],
    //           'credential': _turnCredential['password']
    //         },
    //       ]
    //     };
    //   } catch (e) {}
    // }

    // _socket?.onOpen = () {
    //   print('onOpen');
    //   onSignalingStateChange?.call(SignalingState.ConnectionOpen);
    //   _send('new', {
    //     'name': DeviceInfo.label,
    //     'id': _selfId,
    //     'user_agent': DeviceInfo.userAgent
    //   });
    // };

    // _socket?.onMessage = (message) {
    //   print('Received data: ' + message);
    //   onMessage(_decoder.convert(message));
    // };

    // _socket?.onClose = (int? code, String? reason) {
    //   print('Closed by server [$code => $reason]!');
    //   onSignalingStateChange?.call(SignalingState.ConnectionClosed);
    // };

    // await _socket?.connect();
  // }

  // Future<MediaStream> createStream(String media, bool userScreen,
  //     {BuildContext? context}) async {
  //   final Map<String, dynamic> mediaConstraints = {
  //     'audio': userScreen ? false : true,
  //     'video': userScreen
  //         ? true
  //         : {
  //             'mandatory': {
  //               'minWidth':
  //                   '640', // Provide your own width, height and frame rate here
  //               'minHeight': '480',
  //               'minFrameRate': '30',
  //             },
  //             'facingMode': 'user',
  //             'optional': [],
  //           }
  //   };
  //   late MediaStream stream;
  //   if (userScreen) {
  //     if (WebRTC.platformIsDesktop) {
  //       final source = await showDialog<DesktopCapturerSource>(
  //         context: context!,
  //         builder: (context) => ScreenSelectDialog(),
  //       );
  //       stream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
  //         'video': source == null
  //             ? true
  //             : {
  //                 'deviceId': {'exact': source.id},
  //                 'mandatory': {'frameRate': 30.0}
  //               }
  //       });
  //     } else {
  //       stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
  //     }
  //   } else {
  //     stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  //   }
  //
  //   onLocalStream?.call(stream);
  //   return stream;
  // }

  Future<Session> _createSession(
    Session? session, {
    required String peerId,
    required String sessionId,
    required String media,
    required bool screenSharing,
  }) async {
    var newSession = session ?? Session(sid: sessionId, pid: peerId);
    // if (media != 'data')
    //   _localStream =
    //       await createStream(media, screenSharing, context: _context);
    //print(_iceServers);
    RTCPeerConnection pc = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);


    pc.onIceCandidate = (candidate) async {
      if (candidate == null) {
        print('onIceCandidate: complete!');
        return;
      }
      // This delay is needed to allow enough time to try an ICE candidate
      // before skipping to the next one. 1 second is just an heuristic value
      // and should be thoroughly tested in your own environment.
      await Future.delayed(
          const Duration(milliseconds: 1000),
          () => _sendToInterval('candidate', {
                'to': peerId,
                'from': _selfId,
                'candidate': {
                  'sdpMLineIndex': candidate.sdpMLineIndex,
                  'sdpMid': candidate.sdpMid,
                  'candidate': candidate.candidate,
                },
                'session_id': sessionId,
              }));
    };

    pc.onIceConnectionState = (state) {};

    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    newSession.pc = pc;
    return newSession;
  }

  void _addDataChannel(Session session, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      onDataChannelMessage?.call(session, channel, data);
    };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }

  Future<void> _createDataChannel(Session session,
      {label = 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    RTCDataChannel channel =
        await session.pc!.createDataChannel(label, dataChannelDict);
    _addDataChannel(session, channel);
  }

  Future<void> _createOffer(Session session, String media) async {
    try {
      RTCSessionDescription s =
          await session.pc!.createOffer(media == 'data' ? _dcConstraints : {});
      await session.pc!.setLocalDescription(_fixSdp(s));
      _send('offer', {
        'to': session.pid,
        'from': _selfId,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': session.sid,
        'media': media,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  RTCSessionDescription _fixSdp(RTCSessionDescription s) {
    var sdp = s.sdp;
    s.sdp =
        sdp!.replaceAll('profile-level-id=640c1f', 'profile-level-id=42e032');
    return s;
  }

  Future<void> _createAnswer(Session session, String media) async {
    try {
      RTCSessionDescription s =
          await session.pc!.createAnswer(media == 'data' ? _dcConstraints : {});
      await session.pc!.setLocalDescription(_fixSdp(s));
      _send('answer', {
        'to': session.pid,
        'from': _selfId,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': session.sid,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  void createIdOffer(){
    print("IdOffer");
    _send('IdOffer', {
      'myName': DeviceInfo.label,
      'Id': _selfId,
    });
  }

  void createIdAnswer() {
    _send('IdAnswer', {
      'myName': DeviceInfo.label,
      'Id': _selfId,
    });
  }

  Future<void> _send(event, data) async{
    var request = Map();
    request["type"] = event;
    request["data"] = data;
    print('request = '+ request.toString());
    await writeMessage(_encoder.convert(request));
  }

  void _sendToInterval(event, data) {
    var request = Map();
    request["type"] = event;
    request["data"] = data;
    print('request = '+ request.toString());
    intervalSender.addContent(_encoder.convert(request));

  }

  Future<void> _cleanSessions() async {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }
    _sessions.forEach((key, sess) async {
      await sess.pc?.close();
      await sess.dc?.close();
    });
    _sessions.clear();
  }

  void _closeSessionByPeerId(String peerId) {
    var session;
    _sessions.removeWhere((String key, Session sess) {
      var ids = key.split('-');
      session = sess;
      return peerId == ids[0] || peerId == ids[1];
    });
    if (session != null) {
      _closeSession(session);
      onCallStateChange?.call(session, CallState.CallStateBye);
    }
  }

  Future<void> _closeSession(Session session) async {
    _localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    await _localStream?.dispose();
    _localStream = null;

    await session.pc?.close();
    await session.dc?.close();
    _senders.clear();
    _videoSource = VideoSource.Camera;
  }
}
