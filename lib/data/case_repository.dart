import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/case_file.dart';

abstract class CaseRepository {
  Future<List<CaseFile>> loadCases();
}

class AssetCaseRepository implements CaseRepository {
  const AssetCaseRepository({this.path = 'assets/cases.json'});
  final String path;

  @override
  Future<List<CaseFile>> loadCases() async {
    final raw = await rootBundle.loadString(path);
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => CaseFile.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
