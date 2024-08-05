import 'dart:async';
import 'dart:convert';

import 'package:cross_os_ble_demo/utils/extra.dart';
// import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Central {
  final BluetoothDevice device;
  Central({required this.device});

  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool isDiscoveringServices = false;
  bool isConnecting = false;
  bool isDisconnecting = false;
  List<int> readReceivedValue = [];
  String writeValue = '';

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;
  late BluetoothService _kenkyuuService;
  late BluetoothCharacteristic _kenkyuuCharactaristicRead;
  late BluetoothCharacteristic _kenkyuuCharacteristicWrite;

  late StreamSubscription<List<int>> _lastValueSubscription;

  String serviceKenkyuuUuid = "db7e2243-3a33-4ebc-944b-1814e86a6299";
  String characteristicKenkyuuWriteUuid = "6a4b3194-1a96-4af1-9630-bf39807743a1";
  String characteristicKenkyuuReadUuid = "00002A18-0000-1000-8000-00805F9B34FB";



  void init() {

    _connectionStateSubscription = device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _services = []; // must rediscover services
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await device.readRssi();
      }
    });

    _mtuSubscription = device.mtu.listen((value) {
      _mtuSize = value;

    });

    _isConnectingSubscription = device.isConnecting.listen((value) {
      isConnecting = value;
    });

    _isDisconnectingSubscription = device.isDisconnecting.listen((value) {
      isDisconnecting = value;
    });

    Future(() async {
      await onConnectPressed();
      await onRequestMtuPressed();
      await onDiscoverServicesPressed();
      await onSubscribePressed();

      _lastValueSubscription = _kenkyuuCharactaristicRead.lastValueStream.listen((value) {
        readReceivedValue = value;
        // print("valueeeeeeeeeee");
        print(utf8.decode(value));
      });
    });

  }

  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    _lastValueSubscription.cancel();
    // super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectPressed() async {
    try {
      await device.connectAndUpdateStream();
    } catch (e) {
      if (e is FlutterBluePlusException && e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
      }
    }
  }

  Future onCancelPressed() async {
    try {
      await device.disconnectAndUpdateStream(queue: false);
    } catch (e) {
    }
  }

  Future onDisconnectPressed() async {
    try {
      await device.disconnectAndUpdateStream();

    } catch (e) {
    }
  }

  Future onDiscoverServicesPressed() async {

    isDiscoveringServices = true;
    try {
      _services = await device.discoverServices();
    } catch (e) {
    }
    print(_services);
    _kenkyuuService = _services.firstWhere((service) => service.uuid == Guid(serviceKenkyuuUuid));
    _kenkyuuCharactaristicRead = _kenkyuuService.characteristics.firstWhere((element) => element.uuid == Guid(characteristicKenkyuuReadUuid));
    _kenkyuuCharacteristicWrite = _kenkyuuService.characteristics.firstWhere((element) => element.uuid == Guid(characteristicKenkyuuWriteUuid));

    isDiscoveringServices = false;
  }

  Future onRequestMtuPressed() async {
    try {
      await device.requestMtu(223, predelay: 0);
    } catch (e) {
    }
  }

  Future onSubscribePressed() async {
    try {
      // String op = _kenkyuuCharactaristicRead.isNotifying == false ? "Subscribe" : "Unubscribe";
      bool success = await _kenkyuuCharactaristicRead.setNotifyValue(_kenkyuuCharactaristicRead.isNotifying == false);
      if(success) {
        print("setNotifyValue success!");
      }
      else{
        print("setNotifyValue failed");
      }

      // if (_kenkyuuCharactaristicRead.properties.read) {
      //   await _kenkyuuCharactaristicRead.read();
      // }

    } catch (e) {
    }
  }

  Future onRead() async {
    try {
      await _kenkyuuCharactaristicRead.read();
    } catch (e) {
    }
  }

  Future onWrite(String text) async{
    try {
      await _kenkyuuCharacteristicWrite.write(utf8.encode(text), withoutResponse: _kenkyuuCharacteristicWrite.properties.writeWithoutResponse);
      // if (c.properties.read) {
      //   await c.read();
      // }
    } catch (e) {
    }
  }

}