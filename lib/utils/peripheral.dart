import 'dart:convert';
import 'dart:typed_data';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter/foundation.dart';

class Peripheral{
  bool isAdvertising = false;
  bool isBleOn = false;
  List<String> devices = <String>[];

  String get deviceName => switch (defaultTargetPlatform) {
    TargetPlatform.android => "BleDroid",
    TargetPlatform.iOS => "BleIOS",
    TargetPlatform.macOS => "BleMac",
    TargetPlatform.windows => "BleWin",
    _ => "TestDevice"
  };

  var manufacturerData = ManufacturerData(
    manufacturerId: 0x012D,
    data: Uint8List.fromList([
      0x03,
      0x00,
      0x64,
      0x00,
      0x45,
      0x31,
      0x22,
      0xAB,
      0x00,
      0x21,
      0x60,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00
    ]),
  );

  String serviceKenkyuu = "db7e2243-3a33-4ebc-944b-1814e86a6299";
  String characteristicKenkyuuWrite = "6a4b3194-1a96-4af1-9630-bf39807743a1";
  String characteristicKenkyuuRead = "00002A18-0000-1000-8000-00805F9B34FB";

  Future<void> init() async{

    // setup callbacks
    BlePeripheral.setBleStateChangeCallback(blestateprint);

    BlePeripheral.setAdvertisingStatusUpdateCallback(
            (bool advertising, String? error) {
          isAdvertising = advertising;
          print("AdvertingStarted: $advertising, Error: $error");
        });

    BlePeripheral.setCharacteristicSubscriptionChangeCallback(
            (String deviceId, String characteristicId, bool isSubscribed) {
          print(
            "onCharacteristicSubscriptionChange: $deviceId : $characteristicId $isSubscribed",
          );
          if (isSubscribed) {
            if (!devices.any((element) => element == deviceId)) {
              devices.add(deviceId);
              print("$deviceId adding");
            } else {
              print("$deviceId already exists");
            }
          } else {
            devices.removeWhere((element) => element == deviceId);
          }
        });

    BlePeripheral.setReadRequestCallback(
            (deviceId, characteristicId, offset, value) {
          print("ReadRequest: $deviceId $characteristicId : $offset : $value");
          // return ReadRequestResult(value: utf8.encode("Hello World"));
          return ReadRequestResult(value: value!);
        });

    BlePeripheral.setWriteRequestCallback(
            (deviceId, characteristicId, offset, value) {
          print("WriteRequest: $deviceId $characteristicId : $offset : $value");
          return WriteRequestResult(value: value);
          //return null;
        });

    // Android only
    BlePeripheral.setBondStateChangeCallback((deviceId, bondState) {
      print("OnBondState: $deviceId $bondState");
    });

    // super.onInit();
    Future(() async{
      _initialize();
      await Future.delayed(const Duration(milliseconds: 1000));
      await addServices();
      startAdvertising();
    });


  }

  void blestateprint(bool isBleOn){
    if(isBleOn){
      print('blestate: true');
    }else{
      print('blestate: false');
    }
  }

  void _initialize() async {
    try {
      await BlePeripheral.initialize();
    } catch (e) {
      print("InitializationError: $e");
    }
  }

  void startAdvertising() async {
    print("Starting Advertising");
    // await Future.delayed(const Duration(milliseconds: 30));
    await BlePeripheral.startAdvertising(
      services: [serviceKenkyuu],
      localName: deviceName,
      manufacturerData: manufacturerData,
      addManufacturerDataInScanResponse: true,
    );
  }

  void stopAdvertising() async {
    await BlePeripheral.stopAdvertising();
  }

  Future<void> addServices() async {
    try {
      var notificationControlDescriptor = BleDescriptor(
        uuid: "00002908-0000-1000-8000-00805F9B34FB",
        value: Uint8List.fromList([0, 1]),
        permissions: [
          AttributePermissions.readable.index,
          AttributePermissions.writeable.index
        ],
      );


      await BlePeripheral.addService(
        BleService(
          uuid: serviceKenkyuu,
          primary: true,
          characteristics: [
            BleCharacteristic(
              uuid: characteristicKenkyuuWrite,
              properties: [
                CharacteristicProperties.read.index,
                CharacteristicProperties.notify.index,
                CharacteristicProperties.write.index,
              ],
              descriptors: [notificationControlDescriptor],
              // value: utf8.encode("Kenkyuuwrite"),
              value: null,
              permissions: [
                AttributePermissions.readable.index,
                AttributePermissions.writeable.index,
              ],
            ),

            BleCharacteristic(
              uuid: characteristicKenkyuuRead,
              properties: [
                CharacteristicProperties.read.index,
                CharacteristicProperties.notify.index,
                // CharacteristicProperties.write.index,
              ],
              descriptors: [notificationControlDescriptor],
              // value: utf8.encode("Kenkyuuread"),
              value: null,
              permissions: [
                AttributePermissions.readable.index,
                // AttributePermissions.writeable.index,
              ],
            ),
          ],
        ),

      );

      print("Services added");
    } catch (e) {
      print("Error: $e");
    }
  }

  void getAllServices() async {
    List<String> services = await BlePeripheral.getServices();
    print(services.toString());
  }

  void removeServices() async {
    await BlePeripheral.clearServices();
    print("Services removed");
  }

  /// Update characteristic value, to all the devices which are subscribed to it
  void updateCharacteristic() async {
    try {
      await BlePeripheral.updateCharacteristic(
        characteristicId: characteristicKenkyuuRead,
        value: utf8.encode("Data Changed"),
        // deviceId: devices[0],
      );
    } catch (e) {
      print("UpdateCharacteristicError: $e");
    }
  }
}
