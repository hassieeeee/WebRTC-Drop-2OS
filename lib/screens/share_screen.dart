import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

import '../utils/signaling.dart';

class ShareScreen extends StatefulWidget {
  final Signaling signaling;
  final RTCDataChannel? dataChannel;
  final Session? session;
  final Timer? timer;

  const ShareScreen(
      {super.key,
      required this.signaling,
      required this.dataChannel,
      required this.session,
      required this.timer});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> imageFiles = [];
  List<Image> viewImages = [];
  int carouselSliderNumber = 0;
  late Signaling _signaling;
  late RTCDataChannel? _dataChannel;
  late Session? _session;
  late Timer? _timer;

  List<int> receivedList = [];
  late Uint8List receivedList8;
  List<Uint8List> receivedList8List = [];
  List<XFile> receivedImageFiles = [];
  List<Image> receivedViewImages = [];
  int receivedImagesCount = 0;
  int receivedImagesNow = 0;

  late Uint8List currentSendByteData;
  int sendImagesCount = 0;
  int sendImagesNow = 0;
  int sendListLength = 0;
  int sendListNow = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    final imagePickerImplementation = ImagePickerPlatform.instance;
    if (imagePickerImplementation is ImagePickerAndroid) {
      imagePickerImplementation.useAndroidPhotoPicker = true;
    }
    _signaling = widget.signaling;
    _dataChannel = widget.dataChannel;
    _session = widget.session;
    _timer = widget.timer;

    _signaling.onDataChannel = (_, channel) {
      _dataChannel = channel;
    };

    _signaling.onDataChannelMessage =
        (_, dc, RTCDataChannelMessage data) async {
      if (data.isBinary) {
        //中身がデータならtrue,メッセージならfalseへ
        if (data.binary.length == 1) {
          receivedImagesCount = data.binary.toList()[0]; //受け取る画像の枚数を確認してセット
          // await _dataChannel?.send(RTCDataChannelMessage('next'));
        } else {
          receivedList =
              receivedList + data.binary.toList(); //分割されたデータをリストにして結合
          print("receive: ${data.binary.toList().sublist(0, 10)}");
        }
        await _dataChannel?.send(RTCDataChannelMessage('next')); //送信者に次の送信を要請する
        print("send: next!");
      } else if (data.text == 'finish') {
        print("receive: finish!");
        receivedList8 =
            Uint8List.fromList(receivedList); //受け取った画像1枚分のリストをUint8listに変換
        XFile tempXFile = XFile.fromData(receivedList8); //そのUint8listをXFileに変換
        receivedImageFiles.add(tempXFile); //保存する時用にXFileのリストに追加?
        receivedList8List.add(receivedList8);//保存する時用にUint8listのリストに追加
        // receivedViewImages.add(Image.file(File(tempXFile.path))); //受信した画像のプレビュー用にImageのリストに追加
        receivedViewImages.add(Image.memory(receivedList8));
        receivedImagesNow++; //今何枚目の画像かをカウント

        if (receivedImagesCount == receivedImagesNow) {
          receivedImagesCount = 0;
          receivedImagesNow = 0;
          await _dataChannel
              ?.send(RTCDataChannelMessage('ok')); //全部の画像を受け取ったらokを送る
          print("send: ok");
          bool answer = await showDialog(
              context: context,
              builder: (_) {
                return AlertDialogSample(
                    receivedViewImages); //受け取った画像をダイアログで表示して保存するか聞く
              });
          if (answer) {
            await _saveImageList();

          }
          receivedList8List.clear();
          receivedViewImages.clear();
          receivedImageFiles.clear();
        } else {
          await _dataChannel?.send(RTCDataChannelMessage('next'));
          print("send: next");
        }
        receivedList.clear();
        // receivedList8.removeRange(0, receivedList8.length);
      } else if (data.text == 'next') {
        print("next from aite");
        if (sendListNow == 0) {
          currentSendByteData = await imageFiles[sendImagesNow].readAsBytes();
          sendListLength = currentSendByteData.length;
        }
        if (sendListNow + 250000 < sendListLength) {
          await _dataChannel?.send(RTCDataChannelMessage.fromBinary(
              currentSendByteData.sublist(sendListNow, sendListNow + 250000)));
          print(currentSendByteData.sublist(sendListNow, sendListNow + 10));
          sendListNow += 250000;
        } else if (sendListNow > sendListLength) {
          await _dataChannel?.send(RTCDataChannelMessage('finish'));
          print("finish");
          sendListNow = 0;
          if(sendImagesCount > sendImagesNow+1){
            sendImagesNow++;
          } else {
            sendImagesNow = 0;
          }

        } else {
          await _dataChannel?.send(RTCDataChannelMessage.fromBinary(
              currentSendByteData.sublist(sendListNow, sendListLength)));
          print(currentSendByteData.sublist(sendListNow, sendListNow + 10));
          sendListNow += 250000;
        }
      } else if (data.text == 'ok') {
        print("ok");
        sendImagesNow = 0;
        await showDialog(
            context: context,
            builder: (_) {
              return AlertDialogConfirm();
            });
      }
    };
  }

  void _imageSelect() async {
    var temp = await _picker.pickMultiImage(limit: 5);
    viewImages.clear();
    setState(() {
      imageFiles = temp;
      imageFiles.forEach((gazou) {
        viewImages.add(Image.file(File(gazou.path)));
      });
    });
    sendImagesCount = imageFiles.length;
  }

  void _sendImageCount() async {
    await _dataChannel?.send(RTCDataChannelMessage.fromBinary(
        Uint8List.fromList([sendImagesCount])));
  }

  Future _saveImageList() async{
    receivedList8List.forEach((buffer) async {
      await ImageGallerySaver.saveImage(buffer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Share Images"),
      ),
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          viewImages.isEmpty
              ? SizedBox(
                  height: 400,
                  width: 300,
                  child: ElevatedButton(
                    onPressed: _imageSelect,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: const Color(0xFFCFD8DC),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            color: Color(0xFF455A64),
                            size: 80,
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          Text(
                            "Upload Images!",
                            style: TextStyle(
                                fontSize: 25, color: Color(0xFF455A64)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    CarouselSlider(
                      items: viewImages,
                      options: CarouselOptions(
                          height: 400,
                          //高さ
                          initialPage: 0,
                          //最初に表示されるページ
                          autoPlay: false,
                          //自動でスライドしてくれるか
                          viewportFraction: 0.7,
                          //各カードの表示される範囲の割合
                          enableInfiniteScroll: false,
                          //最後のカードから最初のカードへの遷移
                          enlargeCenterPage: true,
                          onPageChanged: (index, reason) {
                            setState(() {
                              carouselSliderNumber = index;
                            });
                          }),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: viewImages.map((url) {
                        int index = viewImages.indexOf(url);
                        return Container(
                          width: 15,
                          height: 15,
                          margin: const EdgeInsets.symmetric(
                              vertical: 10.0, horizontal: 5.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: carouselSliderNumber == index
                                ? const Color.fromRGBO(115, 137, 187, 1)
                                : const Color.fromRGBO(115, 137, 187, 0.4),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () {
                    _imageSelect();
                  },
                  style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(Colors.deepPurple.shade100)),
                  child: const SizedBox(
                    height: 50,
                    width: 100,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.file_upload),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            "upload",
                            style: TextStyle(fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(
                width: 30,
              ),
              viewImages.isEmpty
                  ? ElevatedButton(
                      onPressed: null,
                      style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(const Color(0xFFEEEEEE))),
                      child: const SizedBox(
                        height: 50,
                        width: 100,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, color: Color(0xFF9E9E9E)),
                              SizedBox(
                                width: 10,
                              ),
                              Text(
                                "send",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  : ElevatedButton(
                      onPressed: _sendImageCount,
                      style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.pink.shade100)),
                      child: const SizedBox(
                        height: 50,
                        width: 100,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, color: Color(0xFFc62828)),
                              SizedBox(
                                width: 10,
                              ),
                              Text(
                                "send",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Color(0xFFc62828),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
            ],
          )
        ],
      )),
    );
  }
}

class AlertDialogSample extends StatelessWidget {
  // AlertDialogSample({Key? key, required Uint8List gazou}) : super(key: key);
  late List<Image> receivedImages;

  AlertDialogSample(this.receivedImages, {super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      title: Text('Image received!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 300,
            width: 300,
            child: CarouselSlider(
              items: receivedImages,
              options: CarouselOptions(

                height: 200,
                //高さ
                initialPage: 0,
                //最初に表示されるページ
                autoPlay: false,
                //自動でスライドしてくれるか
                viewportFraction: 0.7,
                //各カードの表示される範囲の割合
                enableInfiniteScroll: false,
                //最後のカードから最初のカードへの遷移
                enlargeCenterPage: true,
              ),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          const Text('Do you want to save?'),
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 50,
                width: 100,
                child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text(
                      'ignore',
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    )),
              ),
              SizedBox(
                height: 50,
                width: 100,
                child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text(
                      'save',
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    )),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class AlertDialogConfirm extends StatelessWidget {
  const AlertDialogConfirm({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      title: Text('Your Image has been sent!'),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'ok',
              style: TextStyle(
                fontSize: 15,
              ),
            )),
      ],
    );
  }
}
