import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() => runApp(MaterialApp(debugShowCheckedModeBanner: false, home: ArabApp()));

class ArabApp extends StatefulWidget { @override _ArabAppState createState()=>_ArabAppState(); }

class _ArabAppState extends State<ArabApp> {
  File? img;
  String arabGundul = "";
  String arabHarakat = "";
  String latin = "";
  String terj = "";
  String syarah = "";
  bool load = false;
  final keyC = TextEditingController();

  final prompt = """
Anda adalah ulama pakar bahasa Arab klasik, Nahwu, Shorof, Balaghoh, penerjemah kitab kuning.

Tugas:
1. OCR teks Arab gundul dari gambar secara akurat.
2. Tampilkan teks Arab asli (gundul) dulu.
3. Berikan versi Arab DENGAN HAROKAT LENGKAP yang benar sesuai kaidah Nahwu Shorof.
4. Berikan transliterasi LATIN ARAB (sesuai ejaan pesantren/Indonesia, contoh: Bismillahirrahmanirrahim).
5. Berikan terjemahan Indonesia gaya pesantren yang luwes, kontekstual, mengalir alami.
6. Jika ada istilah fiqih/tasawuf beri syarah singkat.

FORMAT OUTPUT WAJIB PERSIS SEPERTI INI:
[TEKS_ARAB_GUNDUL]
(tulis arab asli dari gambar apa adanya)

[TEKS_ARAB_HARAKAT]
(tulis ulang teks yang sama TAPI BERI HAROKAT LENGKAP yang benar)

[TRANSLITERASI_LATIN]
(tulis latinnya, misal: Alhamdulillahi rabbil 'alamin)

[TERJEMAHAN]
(terjemah pesantren luwes)

[SYARAH_SINGKAT]
(syarah jika ada)
""";

  Future<void> pick(ImageSource s) async {
    if(keyC.text.trim().length < 10){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Isi API Key Gemini dulu!"))); return; }
    final p = await ImagePicker().pickImage(source: s, imageQuality: 85);
    if(p==null) return;
    setState((){ img = File(p.path); load = true; arabGundul="Membaca..."; arabHarakat=""; latin=""; terj=""; syarah=""; });
    try{
      final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: keyC.text.trim());
      final b = await img!.readAsBytes();
      final res = await model.generateContent([Content.multi([TextPart(prompt), DataPart('image/jpeg', b)])]);
      final full = res.text?? "";
      String get(String a, String b){ try{ return full.split(a)[1].split(b)[0].trim(); }catch(_){ return ""; } }
      setState((){
        arabGundul = get("[TEKS_ARAB_GUNDUL]", "[TEKS_ARAB_HARAKAT]");
        arabHarakat = get("[TEKS_ARAB_HARAKAT]", "[TRANSLITERASI_LATIN]");
        latin = get("[TRANSLITERASI_LATIN]", "[TERJEMAHAN]");
        terj = get("[TERJEMAHAN]", "[SYARAH_SINGKAT]");
        syarah = full.contains("[SYARAH_SINGKAT]")? full.split("[SYARAH_SINGKAT]").last.trim() : "";
        if(arabGundul.isEmpty) arabGundul = full;
        load = false;
      });
    }catch(e){ setState((){ arabGundul="Error: $e"; load=false; }); }
  }

  Widget box(String title, String isi, Color col, {TextAlign align=TextAlign.left, double size=16}){
    return Container(width: double.infinity, margin: EdgeInsets.only(bottom:10), padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)),
        SizedBox(height:6),
        Text(isi.isEmpty? "-" : isi, textAlign: align, style: TextStyle(fontSize: size, height: 1.6)),
      ]));
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text("Tarjim + Harokat + Latin"), backgroundColor: Color(0xFF0F6A43), foregroundColor: Colors.white),
      body: ListView(padding: EdgeInsets.all(14), children:[
        TextField(controller: keyC, decoration: InputDecoration(labelText: "API Key Gemini (aistudio.google.com)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.key)), obscureText: true),
        SizedBox(height:10),
        Row(children:[
          Expanded(child: ElevatedButton.icon(onPressed: ()=>pick(ImageSource.gallery), icon: Icon(Icons.photo), label: Text("Galeri"))),
          SizedBox(width:8),
          Expanded(child: ElevatedButton.icon(onPressed: ()=>pick(ImageSource.camera), icon: Icon(Icons.camera), label: Text("Kamera"))),
        ]),
        if(img!=null) Padding(padding: EdgeInsets.only(top:10), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(img!, height:180, fit: BoxFit.cover))),
        if(load) Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if(!load && arabGundul.isNotEmpty) Column(children:[
          SizedBox(height:12),
          box("1. TEKS ARAB ASLI (GUNDUL)", arabGundul, Color(0xFFFFF8E1), align: TextAlign.right, size: 22),
          box("2. TEKS ARAB BERHAROKAT", arabHarakat, Color(0xFFE8F5E9), align: TextAlign.right, size: 24),
          box("3. LATIN ARAB", latin, Color(0xFFE3F2FD), size: 16),
          box("4. TERJEMAHAN PESANTREN", terj, Colors.white, size: 16),
          if(syarah.isNotEmpty) box("5. SYARAH SINGKAT", syarah, Color(0xFFF3E5F5), size: 14),
        ])
      ]),
    );
  }
}
