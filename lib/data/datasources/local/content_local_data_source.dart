import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/prayer_model.dart';
import '../../models/hadith_model.dart';

abstract class ContentLocalDataSource {
  Future<List<PrayerModel>> getPrayers();
  Future<List<HadithModel>> getHadiths();
}

class ContentLocalDataSourceImpl implements ContentLocalDataSource {
  @override
  Future<List<PrayerModel>> getPrayers() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/lutjet.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList.map((json) => PrayerModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load prayers: $e');
    }
  }

  @override
  Future<List<HadithModel>> getHadiths() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/thenie-hadithe.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList.map((json) => HadithModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load hadiths: $e');
    }
  }
}

