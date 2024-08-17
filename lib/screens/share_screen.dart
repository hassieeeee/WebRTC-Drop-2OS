import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:carousel_slider/carousel_slider.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> imageFiles = [];
  List<Image> viewImages = [];
  int carouselSliderNumber = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    final imagePickerImplementation = ImagePickerPlatform.instance;
    if (imagePickerImplementation is ImagePickerAndroid) {
      imagePickerImplementation.useAndroidPhotoPicker = true;
    }
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
  }

  void _send(){}

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
                          enableInfiniteScroll: true,
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
                      children: viewImages!.map((url) {
                        int index = viewImages!.indexOf(url);
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
              ElevatedButton(
                  onPressed: viewImages.isEmpty
                      ? null
                      : () => _send(),
                  style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(
                              viewImages.isEmpty
                              ? const Color(0xFFEEEEEE)
                              : Colors.pink.shade100
                          )
                  ),
                  child: SizedBox(
                    height: 50,
                    width: 100,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send,
                            color: viewImages.isEmpty
                                ? const Color(0xFF9E9E9E)
                                : const Color(0xFFc62828),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            "send",
                            style: TextStyle(
                              fontSize: 20,
                              color: viewImages.isEmpty
                                  ? const Color(0xFF9E9E9E)
                                  : const Color(0xFFc62828),
                            ),
                          ),


                        ],
                      ),
                    ),
                  )),
            ],
          )
        ],
      )),
    );
  }
}
