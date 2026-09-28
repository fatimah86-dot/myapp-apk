import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(MaterialApp(debugShowCheckedModeBanner:false, home: ArabApp(), theme: ThemeData(useMaterial3:true, colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF0F6A43)))));

class ArabApp extends StatefulWidget { @override _ArabAppState createState()=>_ArabAppState(); }

class _ArabAppState extends State<ArabApp> with SingleTickerProviderStateMixin {
  File? img; String gundul="", harakat="", latin="", terj="", syarah=""; bool load=false; int tab=0;
  final keyC=TextEditingController(); final ketikC=TextEditingController(); double fontArab=24;
  List<String> history=[]; late TabController tabC;

  @override void initState(){ super.initState(); tabC=TabController(length:2, vsync:this); loadHist(); }
  
Future<void> loadHist() async { 
  final p=await SharedPreferences.getInstance(); 
  setState((){
    history=p.getStringList('hist')??[];
    keyC.text=p.getString('api_key')??"";
  }); 
  keyC.addListener(() async {
    final prefs=await SharedPreferences.getInstance();
    prefs.setString('api_key', keyC.text);
  });
}

