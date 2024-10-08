import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';

import 'share_screen.dart';
import 'load_screen.dart';

// import '../utils/peripheral.dart';
import '../utils/snackbar.dart';
import '../utils/extra.dart';
import '../utils/signaling.dart';

import '../widgets/scan_result_tile.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  late Signaling signaling;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  String serviceKenkyuu = "db7e2243-3a33-4ebc-944b-1814e86a6299";

  // String characteristicKenkyuuWrite = "6a4b3194-1a96-4af1-9630-bf39807743a1";
  // String characteristicKenkyuuRead = "00002A18-0000-1000-8000-00805F9B34FB";

  bool _dcConnecting = false;
  bool _inCalling = false;
  RTCDataChannel? _dataChannel;
  Session? _session;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
    }, onError: (e) {
      Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      if (mounted) {
        setState(() {});
      }
    });
    Future(() async {
      await requestPermission(Permission.bluetooth);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await requestPermission(Permission.bluetoothAdvertise);
        await requestPermission(Permission.bluetoothConnect);
        await requestPermission(Permission.bluetoothScan);
      }
      signaling = Signaling();
      await signaling.init(); //peripheral.init()が行われる
      // signaling.onDataChannel = (_, channel) {
      //   _dataChannel = channel;
      // };

      signaling.onSignalingStateChange = (SignalingState state) {
        switch (state) {
          case SignalingState.ConnectionClosed:
          case SignalingState.ConnectionError:
          case SignalingState.ConnectionOpen:
            break;
        }
      };

      signaling.onCallStateChange = (Session session, CallState state) {
        switch (state) {
          case CallState.CallStateNew:
            {
              setState(() {
                _session = session;
                _inCalling = true;
                _dcConnecting = false;
              });
              print('callState:new');
            }
            break;
          case CallState.CallStateBye:
            {
              setState(() {
                _inCalling = false;
              });
              _timer?.cancel();
              _dataChannel = null;
              _session = null;
              break;
            }
          case CallState.CallStateInvite:
          case CallState.CallStateConnected:
            print('bbbbb');
            signaling.intervalSender.stop();
          case CallState.CallStateRinging:
        }
      };
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future onScanPressed() async {
    try {
      _systemDevices = await FlutterBluePlus.systemDevices;
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("System Devices Error:", e),
          success: false);
    }
    try {
      await FlutterBluePlus.startScan(
          withServices: [Guid(serviceKenkyuu)],
          timeout: const Duration(seconds: 15));
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Start Scan Error:", e),
          success: false);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future onStopPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Stop Scan Error:", e),
          success: false);
    }
  }

  // void onConnectPressed(BluetoothDevice device) {
  //   device.connectAndUpdateStream().catchError((e) {
  //     Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
  //   });
  //   MaterialPageRoute route = MaterialPageRoute(
  //       builder: (context) => DeviceScreen(device: device), settings: RouteSettings(name: '/DeviceScreen'));
  //   Navigator.of(context).push(route);
  // }

  void onConnectPressed(BluetoothDevice device) {
    device.connectAndUpdateStream().catchError((e) {
      // Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
    });
    // MaterialPageRoute route = MaterialPageRoute(
    //     builder: (context) => ChatScreen(device: device), settings: RouteSettings(name: '/ChatScreen'));
    // Navigator.of(context).push(route);
    setState(() {
      _dcConnecting = true;
    });

    signaling.setCentral(device);
  }

  Future onRefresh() {
    if (_isScanning == false) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    }
    if (mounted) {
      setState(() {});
    }
    return Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> requestPermission(Permission permission) async {
    final status = await permission.request();
    setState(() {
      print(status);
      _permissionStatus = status;
      print(_permissionStatus);
    });
  }

  Widget buildScanButton(BuildContext context) {
    if (FlutterBluePlus.isScanningNow) {
      return FloatingActionButton(
        onPressed: onStopPressed,
        backgroundColor: Colors.red,
        child: const Icon(Icons.stop),
      );
    } else {
      return FloatingActionButton(
          onPressed: onScanPressed, child: const Text("SCAN"));
    }
  }

  // List<Widget> _buildSystemDeviceTiles(BuildContext context) {
  //   return _systemDevices
  //       .map(
  //         (d) => SystemDeviceTile(
  //       device: d,
  //       onOpen: () => Navigator.of(context).push(
  //         MaterialPageRoute(
  //           builder: (context) => DeviceScreen(device: d),
  //           settings: RouteSettings(name: '/DeviceScreen'),
  //         ),
  //       ),
  //       onConnect: () => onConnectPressed(d),
  //     ),
  //   )
  //       .toList();
  // }

  List<Widget> _buildScanResultTiles(BuildContext context) {
    return _scanResults
        .where((element) {
          print(element);
          return element.advertisementData.serviceUuids
              .contains(Guid(serviceKenkyuu));
        })
        .map(
          (r) => ScanResultTile(
            result: r,
            onTap: () => onConnectPressed(r.device),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return _dcConnecting
        ? LoadScreen() //読み込み画面にする
        : _inCalling
            ? ShareScreen(signaling: signaling, dataChannel: _dataChannel, session: _session, timer: _timer,)
            : ScaffoldMessenger(
                // key: Snackbar.snackBarKeyB,
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('Find Devices'),
                  ),
                  body: RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      children: <Widget>[
                        // ..._buildSystemDeviceTiles(context),
                        ..._buildScanResultTiles(context),
                        // ElevatedButton(onPressed: _update, child: const Text('update')),
                      ],
                    ),
                  ),
                  floatingActionButton: buildScanButton(context),
                ),
              );
  }
}
