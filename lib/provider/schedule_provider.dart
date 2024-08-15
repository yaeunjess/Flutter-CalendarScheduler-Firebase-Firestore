import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';

import '../model/schedule_model.dart';
import '../repository/schedule_repository.dart';

// repository는 api에 대한 내용, 비즈니스 로직만 담김
// provider는 api 요청하고 caching 하고, 결론적으로는 글로벌 상태를 관리함

class ScheduleProvider extends ChangeNotifier{
  final ScheduleRepository repository; // API 요청 로직을 담은 클래스

  DateTime selectedDate = DateTime.utc( // 선택한 날짜
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  Map<DateTime, List<ScheduleModel>> cache = {}; // 일정 정보를 저장해둘 변수

  ScheduleProvider({ // 생성자
    required this.repository,
  }) : super(){
    getSchedules(date: selectedDate);
  }

  void getSchedules({
    required DateTime date,
  }) async {
    final resp = await repository.getSchedules(date: date);

    cache.update(
      date,
      (value) => resp, /// key(date)에 해당하는 값이 Map(cache)에 있을 때 실행되는 함수
      // 원래 cache에 있던 key(date)에 매칭되는 value(List<ScheduleModel>)값을 다 없애고, 서버에서 받아온 정보(List<ScheduleModel>)를 덮어쓴다.
      ifAbsent: () => resp /// key(date)에 해당하는 값이 Map(cache)에 없을 때 실행되는 함수
    );

    notifyListeners();
    /// 현재 클래스를 watch()하는 모든 위젯들의 build() 함수를 다시 실행한다. ChangeNotifier 클래스를 상속하는 이유이다. 변경된 상태에 의존하는 위젯들만 build() 한다.
  }

  void createSchedule({
    required ScheduleModel schedule,
  }) async {
    final targetDate = schedule.date;

    final uuid = Uuid();
    final tempId = uuid.v4(); // 유일한 ID 값을 생성
    final newSchedule = schedule.copyWith(id: tempId); // 임시 ID 지정

    // final savedSchedule = await repository.createSchedule(schedule: schedule);

    /// 1. 긍정적 응답, 서버에서 응답을 받기 전에 캐시를 먼저 업데이트 한다.
    // 서버에서 create를 성공할지 실패할지 아직 모르지만, 미리 cache에 create한다.
    cache.update(
      targetDate,
      (value) => [
        ...value,
        newSchedule // schedule.copyWith(id: savedSchedule,),
      ]..sort(
          (a, b) => a.startTime.compareTo(b.startTime),
      ), // cache에 있던 targetDate(key)에 해당하는 value(List<ScheduleModel>)의 값 + newSchedule을 업데이트 한다.
      ifAbsent: () => [newSchedule],
    );

    /// 2. 서버 요청 전, 캐시 업데이트 반영
    notifyListeners();

    /// 3. 서버 요청!
    try{
      final savedSchedule = await repository.createSchedule(schedule: schedule);

      // 1. 서버 응답 기반으로 캐시 업데이트
      cache.update(
        targetDate,
        (value) => value.map((e) => e.id == tempId ? e.copyWith(id: savedSchedule) : e).toList(),
      );
      // value 타입은 List<ScheduleModel>이고, e의 타입은 ScheduleModel이다.
      // map 함수는 list에 있는 값들을 순서대로 순회하면서 값을 변경할 수 있다.
      /* e의 id와 우리가 생성한 tempId가 같으면, 서버에서 받아온 id인 savedSchedule만 바꿔서 넣고
                                     다르면, 원래 있었던 e를 그대로 넣는다.*/
    } catch(e) {
      // 2. 생성 실패 시 캐시 롤백하기
      cache.update(
        targetDate,
        (value) => value.where((e) => e.id != tempId).toList(),
        // where 함수는 list에 있는 값들을 순서대로 순회하면서 특정 조건에 맞는 값만 필터링한다.
        // e의 id와 우리가 생성한 tempId가 다른 것만, list로 바꾼다.
      );
    }

    /// 4. 서버 응답 후, 캐시 업데이트 반영
    notifyListeners();
  }

  void deleteSchedule({
    required DateTime date,
    required String id,
  }) async {
    /*final resp = await repository.deleteSchedule(id: id);

    cache.update(
      date,
      (value) => value.where((e) => e.id != id).toList(), // 'date' key 값이 Map인 cache에 key로 이미 존재할때 실행
      ifAbsent: () => [], // 'date' key 값이 Map인 cache에 key로 존재하지 않을때 실행
    );*/

    final targetSchedule = cache[date]!.firstWhere((e) => e.id == id);
    // firstWhere 함수는 특정 조건을 만족하는 첫 번째 요소를 찾는 데 사용된다.

    /// 1. 긍정적 응답, 응답 전에 캐시 먼저 업데이트 한다.
    // 서버에서 delete를 성공할지 실패할지 아직 모르지만, 미리 cache에 delete한다.
    cache.update(
      date,
      (value) => value.where((e) => e.id != id).toList(),
      // 삭제하려는 schedule의 id가 아닌 schedule들만 list로 cahce에 넣는다.
      ifAbsent: () => [],
    );

    /// 2. 서버 응답 전, 캐시 업데이트 반영
    notifyListeners();

    /// 3. 서버 요청!
    try{
      // 1. 삭제 함수 실행
      await repository.deleteSchedule(id: id);
    } catch (e){
      // 2. 삭제 실패 시 캐시 롤백하기
      cache.update(
        date,
        (value) => [...value, targetSchedule]..sort((a,b) => a.startTime.compareTo(b.startTime)),
      );
    }

    /// 4. 서버 응답 후, 캐시 업데이트 반영
    notifyListeners();
  }

  void changeSelectedDate({
    required DateTime date,
  }) {
    selectedDate = date;
    notifyListeners();
  }

}