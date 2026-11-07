import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../data/local_database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.language, required this.onLanguageChanged});
  final String language;
  final ValueChanged<String> onLanguageChanged;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0, refreshToken = 0;
  bool get ar => widget.language == 'ar';
  String tr(String a, String f) => ar ? a : f;
  final db = LocalDatabase.instance;
  final picker = ImagePicker();
  void refresh() => setState(() => refreshToken++);

  List<String> get labels => [
    tr('الرئيسية','Accueil'), tr('الأبناء','Enfants'), tr('المباريات','Matchs'),
    tr('البطولات','Compétitions'), tr('الجمعيات','Clubs'), tr('التدريبات','Entraînements'),
    tr('المزيد','Plus')
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      dashboard(), records('children'), records('matches'), records('competitions'),
      records('teams'), records('training_sessions'), settings()
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SLH_HAWK', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(tr('متابعة التطور الرياضي','Suivi sportif'),
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))],
      ),
      body: IndexedStack(index: tab, children: pages),
      floatingActionButton: tab >= 1 && tab <= 5
          ? FloatingActionButton.extended(
              onPressed: addRecord, icon: const Icon(Icons.add),
              label: Text(tr('إضافة','Ajouter')))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          for (int i=0;i<labels.length;i++)
            NavigationDestination(
              icon: Icon([Icons.home_outlined,Icons.person_outline,Icons.sports_soccer,
                Icons.emoji_events_outlined,Icons.shield_outlined,Icons.fitness_center,
                Icons.settings_outlined][i]), label: labels[i])
        ],
      ),
    );
  }

  Widget dashboard() => FutureBuilder<Map<String,int>>(
    key: ValueKey(refreshToken), future: db.summary(),
    builder: (context,snap) {
      final v=snap.data??{};
      return ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(20)),
          child: Text(tr('ملفات الأبناء والمباريات والتدريبات محفوظة محلياً على هذا الهاتف.',
            'Les profils, matchs et entraînements sont enregistrés localement.'),
            style: const TextStyle(color:Colors.white,fontSize:17))),
        const SizedBox(height:14),
        GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
          crossAxisCount:2,childAspectRatio:1.55,crossAxisSpacing:10,mainAxisSpacing:10,
          children:[
            _stat(tr('الأبناء','Enfants'),v['children']??0,Icons.people),
            _stat(tr('المباريات','Matchs'),v['matches']??0,Icons.sports_soccer),
            _stat(tr('البطولات','Compétitions'),v['competitions']??0,Icons.emoji_events),
            _stat(tr('التدريبات','Entraînements'),v['training']??0,Icons.fitness_center),
          ]),
        const SizedBox(height:18),
        Text(tr('آخر المباريات','Derniers matchs'),
          style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
        _recordList('matches',limit:5),
      ]);
    });

  Widget _stat(String title,int value,IconData icon)=>Card(child:Padding(
    padding:const EdgeInsets.all(14),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,
      children:[Icon(icon,color:const Color(0xFFD71920)),
        Text('$value',style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),Text(title)])));

  Widget records(String table)=>_recordList(table);
  Widget _recordList(String table,{int? limit})=>FutureBuilder<List<Map<String,Object?>>>(
    key:ValueKey('$table-$refreshToken'),
    future:db.rows(table,orderBy: table=='children'||table=='competitions'||table=='teams'
      ? 'name COLLATE NOCASE' : table=='matches'?'match_date DESC'
      : table=='training_sessions'?'session_date DESC':'id DESC'),
    builder:(context,snap){
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snap.hasError) {
        return Center(child: Text('${snap.error}'));
      }
      var list=snap.data??[];
      if (limit != null) {
        list = list.take(limit).toList();
      }
      if (list.isEmpty) {
        return Center(child: Padding(
        padding:const EdgeInsets.all(30),child:Text(
          table=='children'?tr('أضف ملف ابنك الرياضي للبدء','Ajoutez un profil pour commencer'):
          tr('لا توجد بيانات بعد. اضغط على إضافة للبدء.','Aucune donnée. Appuyez sur Ajouter.'))));
      }
      return ListView(shrinkWrap:limit!=null,
        physics:limit!=null?const NeverScrollableScrollPhysics():null,
        padding:const EdgeInsets.all(12),
        children:list.map((r)=>_tile(table,r)).toList());
    });

  Widget _tile(String table,Map<String,Object?> r){
    final isChild=table=='children', isTeam=table=='teams';
    final imagePath=(isChild?r['photo_path']:isTeam?r['logo_path']:null)?.toString();
    String title,subtitle; IconData icon;
    switch(table){
      case 'children':
        title='${r['name']}'; subtitle='${r['primary_position']??''} • ${r['preferred_foot']??''}'; icon=Icons.person;
        break;
      case 'matches':
        title='${r['opponent']}'; subtitle='${r['match_date']} • ${r['minutes']??0} ${tr('دقيقة','min')} • ${r['goals']??0} ${tr('أهداف','buts')}'; icon=Icons.sports_soccer;
        break;
      case 'competitions':
        title='${r['name']}'; subtitle='${r['season']??''} • ${r['format']??''}'; icon=Icons.emoji_events;
        break;
      case 'teams':
        title='${r['name']}'; subtitle='${r['academy']??''}'; icon=Icons.shield;
        break;
      default:
        title='${r['title']}'; subtitle='${r['session_date']} • ${r['attended']==1?tr('حاضر','Présent'):tr('غائب','Absent')}'; icon=Icons.fitness_center;
    }
    return Card(child:ListTile(
      leading:imagePath!=null&&imagePath.isNotEmpty&&File(imagePath).existsSync()
        ?CircleAvatar(backgroundImage:FileImage(File(imagePath)))
        :CircleAvatar(child:Icon(icon)),
      title:Text(title),subtitle:Text(subtitle),
      trailing:PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') {
            _form(table, row: r);
          }
          if (v == 'delete') {
            _delete(table, r['id'] as int);
          }
        },
        itemBuilder:(_)=>[
          PopupMenuItem(value:'edit',child:Text(tr('تعديل','Modifier'))),
          PopupMenuItem(value:'delete',child:Text(tr('حذف','Supprimer')))])));
  }

  Future<void> addRecord() async {
    final table=['','children','matches','competitions','teams','training_sessions',''][tab];
    if (table.isNotEmpty) {
      await _form(table);
    }
  }

  Future<String?> _pickAndStoreImage() async {
    final x=await picker.pickImage(source:ImageSource.gallery,imageQuality:88,maxWidth:1600);
    if (x == null) {
      return null;
    }
    final dir=await getApplicationDocumentsDirectory();
    final folder=Directory('${dir.path}/slh_media');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final ext=x.path.contains('.')?x.path.substring(x.path.lastIndexOf('.')):'.jpg';
    final target='${folder.path}/${DateTime.now().microsecondsSinceEpoch}$ext';
    return (await File(x.path).copy(target)).path;
  }

  Future<void> _form(String table,{Map<String,Object?>? row}) async {
    final messenger = ScaffoldMessenger.of(context);
    final children = await db.rows('children', orderBy: 'name COLLATE NOCASE');
    if (!mounted) {
      return;
    }
    final controllers = <String, TextEditingController>{};
    final imageKey=table=='children'?'photo_path':table=='teams'?'logo_path':null;
    String? imagePath=imageKey==null?null:row?[imageKey]?.toString();
    int? selectedChild=row?['child_id'] as int?;
    final fields=<_Field>[];
    Future<void> pickDate(String key) async {
      final current=DateTime.tryParse(controllers[key]?.text??'')??DateTime.now();
      final picked=await showDatePicker(context:context,initialDate:current,
        firstDate:DateTime(1950),lastDate:DateTime(2100),
        locale:Locale(widget.language));
      if (picked != null) {
        controllers[key]?.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      }
    }
    void text(String key,String label,{String initial='',bool numeric=false}) {
      controllers[key]=TextEditingController(text:initial.isNotEmpty?initial:'${row?[key]??''}');
      fields.add(_Field(key,label,numeric:numeric));
    }
    if (table == 'children') {
      text('name',tr('الاسم الكامل','Nom complet'));
      text('birth_date',tr('تاريخ الميلاد','Date de naissance'));
      text('height',tr('الطول (سم)','Taille (cm)'),numeric:true);
      text('weight',tr('الوزن (كغ)','Poids (kg)'),numeric:true);
      text('preferred_foot',tr('القدم المفضلة','Pied préféré'));
      text('primary_position',tr('المركز الأساسي','Poste principal'));
      text('secondary_positions',tr('مراكز أخرى','Autres postes'));
    } else if (table == 'teams') {
      text('name',tr('اسم الجمعية أو النادي','Nom du club / association'));
      text('academy',tr('الأكاديمية أو الفرع','Académie / section'));
      text('start_date',tr('تاريخ بداية الانتماء','Date de début'));
      text('end_date',tr('تاريخ نهاية الانتماء','Date de fin'));
    } else if (table == 'competitions') {
      text('name',tr('اسم البطولة','Nom de la compétition'));
      text('season',tr('الموسم','Saison'),initial:'2026/2027');
      text('format',tr('نظام البطولة','Format'));
    } else {
      if (children.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(tr('أضف ملف ابن أولاً', 'Ajoutez d’abord un profil enfant'))),
        );
        return;
      }
      if (table == 'matches') {
        text('opponent',tr('الفريق المنافس','Adversaire'));
        text('match_date',tr('تاريخ المباراة','Date du match'),initial:DateTime.now().toIso8601String().substring(0,10));
        text('participation',tr('المشاركة: أساسي/بديل/لم يشارك','Participation'));
        text('minutes',tr('الدقائق','Minutes'),initial:'0',numeric:true);
        text('position',tr('المركز الذي لعب فيه','Poste joué'));
        text('home_score',tr('أهداف فريق الابن','Buts de son équipe'),initial:'0',numeric:true);
        text('away_score',tr('أهداف المنافس','Buts adverses'),initial:'0',numeric:true);
        text('goals',tr('أهداف اللاعب','Buts du joueur'),initial:'0',numeric:true);
        text('assists',tr('التمريرات الحاسمة','Passes décisives'),initial:'0',numeric:true);
        text('rating',tr('تقييم من 10 (اختياري)','Note sur 10 (facultative)'),numeric:true);
        text('notes',tr('ملاحظات','Notes'));
      } else {
        text('title',tr('عنوان الحصة','Titre de la séance'));
        text('session_date',tr('تاريخ الحصة','Date de la séance'),initial:DateTime.now().toIso8601String().substring(0,10));
        text('attended',tr('الحضور (1 حاضر، 0 غائب)','Présence (1 présent, 0 absent)'),initial:'1',numeric:true);
        text('notes',tr('ملاحظات','Notes'));
      }
    }
    final formKey=GlobalKey<FormState>();
    final saved=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,setDialog)=>AlertDialog(
        title:Text(row==null?tr('إضافة سجل','Ajouter'):tr('تعديل سجل','Modifier')),
        content:SizedBox(width:440,child:SingleChildScrollView(child:Form(
          key:formKey,child:Column(mainAxisSize:MainAxisSize.min,children:[
            if (table == 'matches' || table == 'training_sessions')
              DropdownButtonFormField<int>(
                initialValue: selectedChild,
                isExpanded:true,
                decoration:InputDecoration(labelText:tr('اختر الابن','Choisir l’enfant')),
                items:children.map((c)=>DropdownMenuItem<int>(
                  value:c['id'] as int,child:Text('${c['name']}'))).toList(),
                onChanged:(v)=>setDialog(()=>selectedChild=v),
                validator:(v)=>v==null?tr('اختر الابن','Choisissez un enfant'):null),
            if (imageKey != null) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await _pickAndStoreImage();
                  if (p != null) {
                    setDialog(() => imagePath = p);
                  }
                },
                icon:const Icon(Icons.photo_library_outlined),
                label:Text(table=='children'?tr('اختيار صورة الابن','Choisir la photo'):tr('اختيار شعار الجمعية','Choisir le logo'))),
              if (imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync())
                Padding(padding:const EdgeInsets.only(bottom:10),
                  child:Image.file(File(imagePath!),height:100,fit:BoxFit.contain)),
            ],
            ...fields.map((f)=>Padding(padding:const EdgeInsets.only(bottom:10),
              child:f.key.endsWith('_date')||f.key=='birth_date'
                ?TextFormField(controller:controllers[f.key],readOnly:true,
                  decoration:InputDecoration(labelText:f.label,
                    border:const OutlineInputBorder(),suffixIcon:const Icon(Icons.calendar_month)),
                  onTap:()=>pickDate(f.key))
                :TextFormField(controller:controllers[f.key],
                  keyboardType:f.numeric?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,
                  decoration:InputDecoration(labelText:f.label,border:const OutlineInputBorder()),
                  validator:f.key=='name'||f.key=='opponent'||f.key=='title'
                    ?(v)=>(v==null||v.trim().isEmpty)?tr('هذا الحقل مطلوب','Champ obligatoire'):null:null))),
          ])))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tr('إلغاء','Annuler'))),
          FilledButton(onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, true);
            }
          },
            child:Text(tr('حفظ','Enregistrer')))])));
    if (saved != true || !mounted) {
      return;
    }
    final data=<String,Object?>{};
    if (selectedChild != null && (table == 'matches' || table == 'training_sessions')) {
      data['child_id'] = selectedChild;
    }
    for(final e in controllers.entries){
      final k=e.key,v=e.value.text.trim();
      if ({'height', 'weight', 'rating'}.contains(k)) {
        data[k] = v.isEmpty ? null : double.tryParse(v);
      } else if ({'minutes', 'home_score', 'away_score', 'goals', 'assists', 'attended'}.contains(k)) {
        data[k] = int.tryParse(v) ?? 0;
      } else {
        data[k] = v.isEmpty ? null : v;
      }
    }
    if (imageKey != null) {
      data[imageKey] = imagePath;
    }
    try{
      await db.save(table,data,id:row?['id'] as int?);
      if (mounted) refresh();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(tr('تعذر الحفظ: $e', 'Enregistrement impossible: $e'))),
        );
      }
    }finally{for(final c in controllers.values){c.dispose();}}
  }

  Future<void> _delete(String table,int id)async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(tr('تأكيد الحذف','Confirmer')),
      content:Text(tr('هل تريد حذف هذا السجل؟','Supprimer cet élément ?')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tr('إلغاء','Annuler'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(tr('حذف','Supprimer')))]));
    if (ok == true) {
      await db.remove(table, id);
      if (mounted) refresh();
    }
  }

  Widget settings()=>ListView(padding:const EdgeInsets.all(16),children:[
    Card(child:ListTile(leading:const Icon(Icons.language),
      title:Text(tr('لغة التطبيق','Langue de l’application')),
      trailing:DropdownButton<String>(value:widget.language,
        items:const[DropdownMenuItem(value:'ar',child:Text('العربية')),
          DropdownMenuItem(value:'fr',child:Text('Français'))],
        onChanged: (v) {
          if (v != null) {
            widget.onLanguageChanged(v);
          }
        }))),
    Card(child:ListTile(leading:const Icon(Icons.backup_outlined),
      title:Text(tr('النسخ الاحتياطي والمزامنة','Sauvegarde et synchronisation')),
      subtitle:Text(tr('البيانات محفوظة محلياً. ربط Google Drive غير مفعّل في هذا الإصدار.',
        'Données locales. Google Drive n’est pas activé dans cette version.')))),
    Card(child:ListTile(leading:const Icon(Icons.info_outline),
      title:Text(tr('حول التطبيق','À propos'),),
      subtitle:const Text('SLH_HAWK Parent • 1.0.5'))),
  ]);
}

class _Field{
  const _Field(this.key,this.label,{this.numeric=false});
  final String key,label;final bool numeric;
}
