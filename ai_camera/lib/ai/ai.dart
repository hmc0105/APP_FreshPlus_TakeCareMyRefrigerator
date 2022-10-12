import 'dart:collection';
import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '/firebase/repository/user_repository.dart';
import '/firebase/repository/user_box_repository.dart';
import '/firebase/repository/fridge_repository.dart';
import '/firebase/repository/item_repository.dart';
List<String> name_list = ['activia','appleade','bananamilk','beanmilk',
  'berrymilk','cheese','chicken','egg','idh','picnic'];

Future<String> _getModel(String assetPath) async {
  if (io.Platform.isAndroid) {
    return 'flutter_assets/$assetPath';
  }
  final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
  await io.Directory(dirname(path)).create(recursive: true);
  final file = io.File(path);
  if (!await file.exists()) {
    final byteData = await rootBundle.load(assetPath);
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  }
  return file.path;
}

Future<HashMap<String,int>> detectionNumList(String path) async {
  final imagePath = await _getModel('assets/test.jpg');
  final inputImage=InputImage.fromFilePath(imagePath);
  final modelPath = await _getModel('assets/ml/object_labeler.tflite');
  final options = LocalObjectDetectorOptions(
    mode:DetectionMode.single,
    modelPath: modelPath,
    classifyObjects: true,
    multipleObjects: true,
  );
  final objectDetector = ObjectDetector(options:options);
  final List<DetectedObject> objects= await objectDetector.processImage(inputImage);
  HashMap<String,int> map = HashMap();
  for(var object in objects){
    String label = object.labels.first.text;
    if(map.containsKey(label)==true){
      map[label] = map[label]!+1;
    }
    else{
      map[label] = 0;
    }
  }
  return map;
}

Future<HashMap<String,int>> firebaseNumList(String unitID, String fridgeID) async {
  await UserRepository().requestLogIn('admin@admin.io','adminadmin');
  var fridgeRepo = FridgeRepository(unitID);
  fridgeRepo.init();
  var userBoxRepo = UserBoxRepository(unitID,fridgeID);
  userBoxRepo.init();
  var users =(await fridgeRepo.getFridge(fridgeID)).users;
  HashMap<String,int> map = HashMap();
  users.forEach((user) async {
    var items =(await userBoxRepo.getUserBox(user)).items;
    var itemRepo = ItemRepository(unitID,fridgeID,user);
    items.forEach((item)async{
      var label =(await itemRepo.getItem(item)).itemName;
      if(map.containsKey(label)==true){
        map[label] = map[label]!+1;
      }
      else{
        map[label] = 0;
      }
    });
  });
  await UserRepository().requestLogOut();
  return map;
}
List<int> calMargin(List<int> nameList,
  HashMap<String,int> detectList, HashMap<String,int> fireList){
  var margin = List.generate(nameList.length,(int index)=>0);
  for(int i=0; i<margin.length;i++){
    int detect = 0;
    if(detectList.containsKey(nameList[i])){
      detect = detectList[nameList[i]]!;
    }
    int fire = 0;
    if(fireList.containsKey(nameList[i])){
      fire = fireList[nameList[i]]!;
    }
    margin[i]=detect-fire;
  }
  return margin;
}

Future<void> updateState(String unitID, String fridgeID, List<String> nameList,List<int> margin)async{
  await UserRepository().requestLogIn('admin@admin.io','adminadmin');
  var uid ="";
  var itemRepo = ItemRepository(unitID,fridgeID,uid);
  itemRepo.init();
  for(int i =0;i<margin.length;i++){
    if(margin[i]>0){
      await itemRepo.addRealItems(nameList[i],margin[i]);
    }
    else if(margin[i]<0){
      //for all user
      //querySearch
      //
      await itemRepo.deleteRealItems(nameList[i],margin[i]);
    }
  }


  await UserRepository().requestLogOut();
}

