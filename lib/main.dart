import 'package:flutter/material.dart';
import 'data.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FirstPage(),
  ));
}

class FirstPage extends StatelessWidget {
  var _categoryNameController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Material(
        color: Colors.white,
        child: Center(
          child: ListView(children: [
            Padding(
              padding: EdgeInsets.all(50.0),
            ),
            Image.asset(
              'images/photosave.png',
              width: 300.0,
              height: 300.0,
            ),
            ListTile(
              title: TextFormField(
                controller: _categoryNameController,
                decoration: InputDecoration(
                    labelText: 'Enter a Category ',
                    hintText: 'eg: dogs, bikes, cars...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0)),
                    contentPadding:
                        EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0)),
              ),
            ),
            ListTile(
              title: Material(
                color: Colors.lightBlue,
                elevation: 5.0,
                borderRadius: BorderRadius.circular(25.0),
                child: MaterialButton(
                  height: 45.0,
                  onPressed: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) {
                      return SecondPage(
                        category: _categoryNameController.text,
                      );
                    }));
                  },
                  child: Text(
                    'Search',
                    style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            )
          ]),
        ),
      ),
    );
  }
}

class SecondPage extends StatefulWidget {
  String category;
  SecondPage({this.category});

  @override
  _SecondPageState createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  String imgUrl = "";
  String name = "";

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    final android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iOS = IOSInitializationSettings();
    final initSettings = InitializationSettings(android: android, iOS: iOS);

    flutterLocalNotificationsPlugin.initialize(initSettings,
        onSelectNotification: _onSelectNotification);
  }

  Future<void> _onSelectNotification(String json) async {
    final obj = jsonDecode(json);

    if (obj['isSuccess']) {
      OpenFile.open(obj['filePath']);

      print(obj['filePath']);
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Error'),
          content: Text('${obj['error']}'),
        ),
      );
    }
  }

  Future<void> _showNotification(Map<String, dynamic> downloadStatus) async {
    final android = AndroidNotificationDetails(
        'channel id', 'channel name', 'channel description',
        priority: Priority.high, importance: Importance.max);
    final iOS = IOSNotificationDetails();
    final platform = NotificationDetails(android: android, iOS: iOS);
    final json = jsonEncode(downloadStatus);
    final isSuccess = downloadStatus['isSuccess'];

    await flutterLocalNotificationsPlugin.show(
        0, // notification id
        isSuccess ? 'Success' : 'Failure',
        isSuccess
            ? 'File has been downloaded successfully!'
            : 'There was an error while downloading the file.',
        platform,
        payload: json);
  }

  Future<void> downloadFile() async {
    Dio dio = Dio();
    Map<String, dynamic> result = {
      'isSuccess': false,
      'filePath': null,
      'error': null,
    };

    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.storage,
    ].request();

    print(statuses[Permission.location]);

    try {
      var path = await ExtStorage.getExternalStoragePublicDirectory(
          ExtStorage.DIRECTORY_PICTURES);
      print(path);
      // ignore: unnecessary_brace_in_string_interps
      final response = await dio.download(imgUrl, "${path}/${name}.jpg",
          onReceiveProgress: (rec, total) {
        print("Rec: $rec , Total: $total");
        print('${name}.jpg');
      });
      result['isSuccess'] = response.statusCode == 200;
      result['filePath'] = "${path}/${name}.jpg";
    } catch (ex) {
      result['error'] = ex.toString();
    } finally {
      await _showNotification(result);
    }

    Text("Download completed");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: Text(
          'Photo Save',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder(
          future: getPics(widget.category),
          // ignore: missing_return
          builder: (context, snapshot) {
            Map data = snapshot.data;
            if (snapshot.hasError) {
              print(snapshot.error);
              return Text('Failed to get response from  the server',
                  style: TextStyle(color: Colors.red, fontSize: 22.0));
            } else if (snapshot.hasData) {
              return Center(
                child: ListView.builder(
                  itemCount: data['hits'].length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: <Widget>[
                        Column(
                          children: [
                            Container(
                              child: InkWell(
                                child: CachedNetworkImage(
                                  imageUrl:
                                      '${data['hits'][index]['largeImageURL']}',
                                  placeholder: (context, imageUrl) =>
                                      CircularProgressIndicator(),
                                ),
                              ),
                            ),
                            Padding(
                                padding: EdgeInsets.only(
                                    top: 5,
                                    right: 20.0,
                                    left: 20.0,
                                    bottom: 5.0)),
                            Padding(
                                padding: EdgeInsets.only(
                                    top: 5,
                                    right: 20.0,
                                    left: 20.0,
                                    bottom: 5.0)),
                          ],
                        ),
                        Positioned(
                          right: 10,
                          bottom: 75,
                          child: RawMaterialButton(
                            elevation: 2,
                            child: Icon(
                              Icons.download_sharp,
                              color: Colors.white,
                            ),
                            fillColor: Colors.lightBlue,
                            padding: EdgeInsets.all(15),
                            shape: CircleBorder(),
                            onPressed: () {
                              imgUrl = data['hits'][index]['largeImageURL'];
                              name = data['hits'][index]['user'] +
                                  data['hits'][index]['tags'];
                              downloadFile();
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            } else if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
          }),
    );
  }
}

Future<Map> getPics(String category) async {
  String url =
      'https://pixabay.com/api/?key=$Apikey&q=$category&image_type=photo&pretty=true';
  http.Response response = await http.get(url);
  return json.decode(response.body);
}
