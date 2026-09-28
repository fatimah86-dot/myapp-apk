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
  Future<void> saveHist(String t) async { final p=await SharedPreferences.getInstance(); history.insert(0, t.substring(0, t.length>50?50:t.length)); if(history.length>20) history=history.sublist(0,20); await p.setStringList('hist', history); setState((){}); }

  final promptGambar="""
Anda ulama pakar Nahwu Shorof. OCR teks Arab gundul dari gambar, output WAJIB format:
[TEKS_ARAB_GUNDUL]
[TEKS_ARAB_HARAKAT]
[TRANSLITERASI_LATIN]
[TERJEMAHAN]
[SYARAH_SINGKAT]
""";
  final promptTeks="""
Anda ulama pakar Nahwu Shorof. Dari teks Arab gundul ini, beri harokat, latin, terjemah pesantren. Format sama:
[TEKS_ARAB_GUNDUL]
(teks asli)
[TEKS_ARAB_HARAKAT]
[TRANSLITERASI_LATIN]
[TERJEMAHAN]
[SYARAH_SINGKAT]
Teks:
""";

  Future<void> proses({File? file, String? teksManual}) async {
    if(keyC.text.trim().length<10){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text("Isi API Key aistudio.google.com dulu!"))); return; }
    setState((){ load=true; gundul="Memproses kitab..."; harakat=""; latin=""; terj=""; syarah=""; });
    try{
      final model=GenerativeModel(model:'gemini-1.5-flash', apiKey:keyC.text.trim());
      GenerateContentResponse res;
      if(teksManual!=null){
        res=await model.generateContent([Content.text(promptTeks+teksManual)]);
      } else {
        final b=await file!.readAsBytes(); res=await model.generateContent([Content.multi([TextPart(promptGambar), DataPart('image/jpeg', b)])]);
      }
      final full=res.text??""; String get(String a,String b){ try{ return full.split(a)[1].split(b)[0].trim(); }catch(_){ return ""; } }
      setState((){
        gundul=teksManual!=null?teksManual:get("[TEKS_ARAB_GUNDUL]", "[TEKS_ARAB_HARAKAT]");
        harakat=get("[TEKS_ARAB_HARAKAT]", "[TRANSLITERASI_LATIN]"); latin=get("[TRANSLITERASI_LATIN]", "[TERJEMAHAN]"); terj=get("[TERJEMAHAN]", "[SYARAH_SINGKAT]");
        syarah=full.contains("[SYARAH_SINGKAT]")?full.split("[SYARAH_SINGKAT]").last.trim():""; if(gundul.isEmpty) gundul=full; load=false;
      });
      saveHist(gundul.isNotEmpty?gundul:terj);
    }catch(e){ setState((){ gundul="Error: $e"; load=false; }); }
  }

  Future<void> pick(ImageSource s) async { final p=await ImagePicker().pickImage(source:s, imageQuality:70, maxWidth:1200); if(p==null) return; setState(()=>img=File(p.path)); await proses(file: img); }
  Future<void> pickFile() async { final r=await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions:['pdf','jpg','png','jpeg']); if(r==null) return; setState(()=>img=File(r.files.single.path!)); await proses(file: img); }
  void pasteClipboard() async { final d=await Clipboard.getData('text/plain'); if(d?.text!=null){ ketikC.text=d!.text!; } }

  Widget box(String t,String isi,Color c,{double fs=16, TextAlign a=TextAlign.left}){
    if(isi.isEmpty) return SizedBox();
    return Container(width:double.infinity, margin:EdgeInsets.only(bottom:10), padding:EdgeInsets.all(12), decoration:BoxDecoration(color:c, borderRadius:BorderRadius.circular(12), border:Border.all(color:Colors.black12)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Row(children:[Expanded(child:Text(t, style:TextStyle(fontWeight:FontWeight.bold, fontSize:12))), IconButton(icon:Icon(Icons.copy, size:18), onPressed:(){ Clipboard.setData(ClipboardData(text:isi)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text("$t di-copy!"))); }, tooltip:"Copy")]),
        SelectableText(isi, textAlign:a, style:TextStyle(fontSize:t.contains("ARAB")?fontArab:fs, height:1.7))
      ]));
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title:Text("Tarjim + Harokat + Latin"), backgroundColor:Color(0xFF0F6A43), foregroundColor:Colors.white, bottom: tab==0?TabBar(controller:tabC, labelColor:Colors.white, tabs:[Tab(text:"FOTO KITAB"), Tab(text:"KETIK MANUAL")]):null),
      bottomNavigationBar: NavigationBar(selectedIndex:tab, onDestinationSelected:(i)=>setState(()=>tab=i), destinations:[NavigationDestination(icon:Icon(Icons.translate), label:"Terjemah"), NavigationDestination(icon:Icon(Icons.history), label:"History"), NavigationDestination(icon:Icon(Icons.settings), label:"Atur")]),
      body: tab==0?TabBarView(controller:tabC, children:[_buildFoto(), _buildKetik()]):tab==1?_buildHistory():_buildSetting()
    );
  }
  Widget _buildFoto()=>ListView(padding:EdgeInsets.all(14), children:[
    TextField(controller:keyC, obscureText:true, decoration:InputDecoration(labelText:"API Key Gemini (aistudio.google.com) - auto save", border:OutlineInputBorder(), prefixIcon:Icon(Icons.key))),
    SizedBox(height:12),
    Wrap(spacing:8, runSpacing:8, children:[
      ElevatedButton.icon(onPressed:()=>pick(ImageSource.gallery), icon:Icon(Icons.photo), label:Text("Galeri")),
      ElevatedButton.icon(onPressed:()=>pick(ImageSource.camera), icon:Icon(Icons.camera), label:Text("Kamera")),
      ElevatedButton.icon(onPressed:pickFile, icon:Icon(Icons.picture_as_pdf), label:Text("File PDF/Gambar")),
    ]),
    if(img!=null) Padding(padding:EdgeInsets.only(top:12), child:ClipRRect(borderRadius:BorderRadius.circular(8), child:Image.file(img!, height:180, fit:BoxFit.cover))),
    if(load) Padding(padding:EdgeInsets.all(20), child:Center(child:CircularProgressIndicator())),
    if(!load && gundul.isNotEmpty && gundul!="Memproses kitab...")...[
      SizedBox(height:12),
      box("1. TEKS ARAB ASLI (GUNDUL)", gundul, Color(0xFFFFF8E1), a:TextAlign.right),
      box("2. TEKS ARAB BERHAROKAT", harakat, Color(0xFFE8F5E9), a:TextAlign.right),
      box("3. LATIN ARAB", latin, Color(0xFFE3F2FD)),
      box("4. TERJEMAHAN PESANTREN", terj, Colors.white),
      box("5. SYARAH SINGKAT", syarah, Color(0xFFF3E5F5)),
      ElevatedButton.icon(onPressed:(){ final all="$gundul\n\n$harakat\n\n$latin\n\n$terj"; Clipboard.setData(ClipboardData(text:all)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text("Semua di-copy!"))); }, icon:Icon(Icons.copy_all), label:Text("Copy Semua Hasil"))
    ]
  ]);
  Widget _buildKetik()=>ListView(padding:EdgeInsets.all(14), children:[
    Row(children:[Expanded(child:Text("Ketik Arab Gundul manual:", style:TextStyle(fontWeight:FontWeight.bold))), IconButton(onPressed:pasteClipboard, icon:Icon(Icons.paste), tooltip:"Paste")]),
    TextField(controller:ketikC, maxLines:6, textAlign:TextAlign.right, decoration:InputDecoration(hintText:"مثال: اذا اردت اظهار شيء...", border:OutlineInputBorder())),
    SizedBox(height:10),
    ElevatedButton.icon(onPressed:load?null:(){ if(ketikC.text.trim().isEmpty) return; proses(teksManual:ketikC.text.trim()); }, icon:Icon(Icons.auto_fix_high), label:Text("Proses Harokat + Latin + Terjemah")),
    if(load) Padding(padding:EdgeInsets.all(20), child:Center(child:CircularProgressIndicator())),
  ]);
  Widget _buildHistory()=>ListView(padding:EdgeInsets.all(14), children:[
    Text("History Terjemahan", style:TextStyle(fontWeight:FontWeight.bold, fontSize:18)),
    if(history.isEmpty) Padding(padding:EdgeInsets.only(top:20), child:Text("Belum ada history")),
  ...history.map((h)=>Card(child:ListTile(title:Text(h, maxLines:2, overflow:TextOverflow.ellipsis, textAlign:TextAlign.right), trailing:IconButton(icon:Icon(Icons.copy), onPressed:(){ ketikC.text=h; setState(()=>tab=0); tabC.animateTo(1); }))))
  ]);
  Widget _buildSetting()=>ListView(padding:EdgeInsets.all(20), children:[
    Text("Atur Tampilan", style:TextStyle(fontWeight:FontWeight.bold, fontSize:18)),
    SizedBox(height:10),
    Text("Ukuran Huruf Arab: ${fontArab.toInt()}"),
    Slider(value:fontArab, min:18, max:36, onChanged:(v)=>setState(()=>fontArab=v)),
  ]);
}
