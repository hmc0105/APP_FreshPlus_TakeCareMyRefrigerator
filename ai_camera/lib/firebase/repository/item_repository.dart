import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemType {ok, lost, noHost, warning, trash}

class Item{
  String itemID;
  String itemName;
  String uid;
  DateTime inDate;
  DateTime dueDate;
  ItemType type;
  Item(this.itemID,this.itemName,this.uid,this.inDate,this.dueDate,this.type);
}

class ItemRepositoryException{
  String code;
  ItemRepositoryException(this.code);
}

class ItemRepository{
  String unitID;
  String fridgeID;
  String uid;
  CollectionReference? itemsRef;
  ItemRepository(this.unitID, this.fridgeID,this.uid);

  void init(){
    itemsRef = FirebaseFirestore.instance
      .collection('unit')
      .doc(unitID)
      .collection('fridges')
      .doc(fridgeID)
      .collection('userBoxes')
      .doc(uid)
      .collection('items');
    if(itemsRef==null) throw ItemRepositoryException("null-items");
  }
  Future<void> addItem(Item item) async{
    //itemID자율배정입니다.
    var itemDoc={
      'itemID':"",
      'itemName':item.itemName,
      'uid':item.uid,
      'inDate':Timestamp.fromDate(item.inDate),
      'dueDate':Timestamp.fromDate(item.dueDate),
    };
    switch(item.type){
      case(ItemType.ok):
        itemDoc['itemType']='ok';
        break;
      case(ItemType.lost):
        itemDoc['itemType']='lost';
        break;
      case(ItemType.noHost):
        itemDoc['itemType']='noHost';
        break;
      case(ItemType.trash):
        itemDoc['itemType']='trash';
        break;
      case(ItemType.warning):
        itemDoc['itemType']='warning';
        break;  
    }
    DocumentReference docRef = await itemsRef!.add(itemDoc);
    await docRef.update({'itemID':docRef.id});
    print(docRef.id);
  }
  Future<void> deleteItem(String itemID)async {
    //check it is null?
    DocumentReference itemRef = itemsRef!.doc(itemID);
    itemRef.delete();
    
  }
  Future<void> editItemName(String itemID, String itemName) async{
    DocumentSnapshot itemSnapshot = await itemsRef!.doc(itemID).get();
    if(itemSnapshot.exists==false) throw ItemRepositoryException('no-item');
    await itemsRef!.doc(itemID).update({'itemName':itemName});
  }
  Future<void> editDueDate(String itemID, DateTime dueDate) async{
    DocumentSnapshot itemSnapshot = await itemsRef!.doc(itemID).get();
    if(itemSnapshot.exists==false) throw ItemRepositoryException('no-item');
    await itemsRef!.doc(itemID).update({'dueDate':Timestamp.fromDate(dueDate)});
  }
  Future<void> editType(String itemID, ItemType type)async{
    DocumentSnapshot itemSnapshot = await itemsRef!.doc(itemID).get();
    if(itemSnapshot.exists==false) throw ItemRepositoryException('no-item');
    String typeStr="ok";
    switch(type){
      case(ItemType.ok):
        typeStr='ok';
        break;
      case(ItemType.lost):
        typeStr='lost';
        break;
      case(ItemType.noHost):
        typeStr='noHost';
        break;
      case(ItemType.trash):
        typeStr='trash';
        break;
      case(ItemType.warning):
        typeStr='warning';
        break;  
    }
    await itemsRef!.doc(itemID).update({'type':typeStr});
  }
  Future<Item> getItem(String itemID) async{
    DocumentSnapshot itemSnapshot = 
      await itemsRef!
        .doc(itemID)
        .get();
      if(itemSnapshot.exists==false) throw ItemRepositoryException('no-item');
    DateTime inDate = itemSnapshot.get('inDate').toDate();
    DateTime dueDate = itemSnapshot.get('dueDate').toDate();
    ItemType type = ItemType.ok;
    switch(itemSnapshot.get('type')){
      case('lost'):
        type = ItemType.lost;
        break;
      case('noHost'):
        type = ItemType.noHost;
        break;
      case('trash'):
        type = ItemType.trash;
        break;
      case('warning'):
        type = ItemType.warning;
        break;
    }
    return Item(
      itemSnapshot.get('itemID'),
      itemSnapshot.get('itemName'),
      itemSnapshot.get('uid'),
      inDate,
      dueDate,
      type
    );
  }
  Future<void> addRealItems(String name, int num) async {
    var query = itemsRef!.where("itemName",isEqualTo:name).where("type",isEqualTo:"noHost");
    var snap = await query.get();
    snap.docs.forEach((value) async {
      await editType(value.id,ItemType.ok);
    });
    if((num-snap.size)>0){
      for(int i=0;i<(num-snap.size);i++){
        await addItem(Item("", name, 
        uid, DateTime.now(), DateTime.now(), ItemType.ok)
        );
      }
    }

  }

  Future<void> deleteRealItems(String name, int num) async {
    var query = itemsRef!.where("itemName",isEqualTo:name).where("type",isEqualTo:"ok");
    var snap = await query.get();
    var docs =snap.docs;
    int i=0;
    for (var doc in docs){
      if(i==num) break;
      await editType(doc.id,ItemType.lost);
      i++;
    }
  }
}