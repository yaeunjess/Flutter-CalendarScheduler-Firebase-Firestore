import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import '../model/schedule.dart';
import 'package:path/path.dart' as p;

part 'drift_database.g.dart'; // part 파일 지정

@DriftDatabase( // 사용할 테이블 등록
  tables:[
    Schedules,
  ],
)

class LocalDatabase extends _$LocalDatabase {  // Code Generation으로 생성할 클래스 상속
  LocalDatabase() : super(_openConnection());

  // 일정을 불러오는 기능 SELECT
  Stream<List<Schedule>> watchSchedules(DateTime date) => // 데이터를 조회하고 변화 감지
      (select(schedules)..where((tbl) => tbl.date.equals(date))).watch();

  // 새로운 일정을 생성하는 기능 INSERT
  Future<int> createSchedule(SchedulesCompanion data) =>
      into(schedules).insert(data);

  // 일정을 삭제하는 기능 DELETE
  Future<int> removeSchedule(int id) =>
      (delete(schedules)..where((tbl) => tbl.id.equals(id))).go();

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async{
    // 데이터베이스 파일 저장할 폴더
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    return NativeDatabase(file);
  });
}