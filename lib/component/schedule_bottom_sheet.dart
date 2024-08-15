import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../const/colors.dart';
import '../database/drift_database.dart';
import '../model/schedule_model.dart';
import '../provider/schedule_provider.dart';
import 'custom_text_field.dart';

class ScheduleBottomSheet extends StatefulWidget {
  final DateTime selectedDate;

  const ScheduleBottomSheet({
    required this.selectedDate,
    super.key,
  });

  @override
  State<ScheduleBottomSheet> createState() => _ScheduleBottomSheetState();
}

class _ScheduleBottomSheetState extends State<ScheduleBottomSheet> {
  final GlobalKey<FormState> formKey = GlobalKey(); // 폼 key 생성

  int? startTime;
  int? endTime;
  String? content;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery
        .of(context)
        .viewInsets
        .bottom;

    return Form(
        key: formKey,
        child: SafeArea(
          child: Container(
            height: MediaQuery
                .of(context)
                .size
                .height / 2 + bottomInset,
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.only(
                  left: 8, right: 8, top: 8, bottom: bottomInset),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: '시작 시간',
                          isTime: true,
                          onSaved: (String? val) {
                            startTime = int.parse(val!);
                          },
                          validator: timeValidator,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: CustomTextField(
                          label: '종료 시간',
                          isTime: true,
                          onSaved: (String? val) {
                            endTime = int.parse(val!);
                          },
                          validator: timeValidator,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: CustomTextField(
                      label: '내용',
                      isTime: false,
                      onSaved: (String? val) {
                        content = val;
                      },
                      validator: contentValidator,
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => onSavePressed(context),
                      // onSavePressed, drift 플러그인을 이용해 내부 데이터베이스를 쓰고 싶을때
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PRIMARY_COLOR,
                      ),
                      child: Text(
                        '저장',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
    );
  }


  void onSavePressed(BuildContext context) async {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();

      // provider를 통해 서버로 API 요청하고 싶을때
      /*context.read<ScheduleProvider>().createSchedule(
          schedule: ScheduleModel(
            id: 'new_model',
            content: content!,
            date: widget.selectedDate,
            startTime: startTime!,
            endTime: endTime!,
          ),
      );*/

      // 1. 스케줄 모델 생성하기
      final schedule = ScheduleModel(
          id: Uuid().v4(),
          content: content!,
          date: widget.selectedDate,
          startTime: startTime!,
          endTime: endTime!,
      );

      // 2. 스케줄 모델 파이어스토어에 삽입하기
      await FirebaseFirestore.instance
                            .collection('schedule')
                            .doc(schedule.id)
                            .set(schedule.toJson());

      Navigator.of(context).pop();
    }
  }

  // drift 플러그인을 이용해 내부 데이터베이스를 쓰고 싶을때
  /*
  void onSavePressed() async {
    if(formKey.currentState!.validate()){
      formKey.currentState!.save();

      await GetIt.I<LocalDatabase>().createSchedule(
        SchedulesCompanion(
          startTime: Value(startTime!),
          endTime: Value(endTime!),
          content: Value(content!),
          date: Value(widget.selectedDate),
        ),
      );

      Navigator.of(context).pop();
    }
  }
  */


  // 시간 검증 함수
  String? timeValidator(String? val) {
    if (val == null) {
      return '값을 입력해주세요';
    }

    int? number;

    try {
      number = int.parse(val);
    } catch (e) {
      return '숫자를 입력해주세요';
    }

    if (number < 0 || number > 24) {
      return '0시부터 24시 사이를 입력해주세요';
    }

    return null;
  }

  // 내용 검증 함수
  String? contentValidator(String? val) {
    if (val == null || val.length == 0) {
      return '값을 입력해주세요';
    }

    return null;
  }

}
