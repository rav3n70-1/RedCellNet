// lib/features/educational_content/data/services/content_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/features/educational_content/data/models/content_item.dart';

class ContentService {
  static final List<ContentItem> _fallbackGuides = [
    ContentItem(
      id: '02440d04-1645-487b-9dc7-d729919181a8',
      titleEn: 'Who Can Donate Blood?',
      titleBn: 'কে রক্ত দান করতে পারেন?',
      contentEn:
          'Most healthy adults aged 18–60 weighing at least 50 kg (110 lbs) can safely donate whole blood. Ensure your hemoglobin level is at least 12.5 g/dL (female) or 13.0 g/dL (male) and you have observed at least 90 days since your last whole-blood donation. Final clinical clearance is always performed by medical staff at the blood bank.',
      contentBn:
          '১৮ থেকে ৬০ বছর বয়সী যেকোনো সুস্থ ব্যক্তি যার ওজন কমপক্ষে ৫০ কেজি, তিনি নিরাপদে রক্ত দান করতে পারেন। রক্তদানে হিমোগ্লোবিন কমপক্ষে ১২.৫ গ্রাম/ডেসিলিটার থাকা আবশ্যক এবং বিগত ৯০ দিনে রক্ত দেননি। চূড়ান্ত সিদ্ধান্ত রক্তকেন্দ্রের চিকিৎসক দ্বারা নির্ধারিত হয়।',
      category: 'Eligibility',
      order: 1,
      readTimeMinutes: 3,
      pointsValue: 5,
    ),
    ContentItem(
      id: 'cdb0339c-b264-4739-94cd-083852188de8',
      titleEn: 'Why Blood Donation Matters',
      titleBn: 'রক্তদান কেন এত গুরুত্বপূর্ণ?',
      contentEn:
          'Every two seconds, someone needs blood for surgeries, thalassemia care, cancer treatment, trauma response, or maternal emergencies. A single whole-blood donation can be separated into red cells, platelets, and plasma to support up to three patients.',
      contentBn:
          'জটিল অস্ত্রোপচার, থ্যালাসেমিয়া, ক্যানসার চিকিৎসা, দুর্ঘটনা এবং প্রসবকালীন জটিলতায় রক্ত জীবন বাঁচায়। এক ব্যাগ সম্পূর্ণ রক্ত পৃথক করে লোহিত কণিকা, প্লাটিলেট এবং প্লাজমা তৈরি করে তিনজন রোগীর চিকিৎসায় সহায়তা করা সম্ভব।',
      category: 'Health Benefits',
      order: 2,
      readTimeMinutes: 4,
      pointsValue: 5,
    ),
    ContentItem(
      id: '2c68c787-d2d4-4ba5-b5b8-0c0cde621a21',
      titleEn: 'Pre and Post Donation Care',
      titleBn: 'রক্তদানের আগের ও পরের যত্ন',
      contentEn:
          'Before donation: Drink plenty of water (500 mL), eat a balanced iron-rich meal, sleep well, and avoid fatty foods. After donation: Rest for 10–15 minutes at the center, drink fluids, avoid heavy lifting or strenuous exercise for 24 hours, and keep the sterile dressing dry for 4–6 hours.',
      contentBn:
          'রক্তদানের আগে: পর্যাপ্ত পানি পান করুন, পুষ্টিকর খাবার গ্রহণ করুন এবং পর্যাপ্ত ঘুমান। রক্তদানের পরে: কেন্দ্রে ১০–১৫ মিনিট বিশ্রাম নিন, তরল পানীয় গ্রহণ করুন, ২৪ ঘণ্টা ভারী কাজ থেকে বিরত থাকুন এবং ব্যান্ডেজ ৪–৬ ঘণ্টা শুকনো রাখুন।',
      category: 'Preparation',
      order: 3,
      readTimeMinutes: 3,
      pointsValue: 5,
    ),
    ContentItem(
      id: '4d8a1c90-9999-4a8e-ae15-3932b6bf22bf',
      titleEn: 'Component-Specific Blood Compatibility Guide',
      titleBn: 'রক্তের উপাদান ও গ্রুপের সামঞ্জস্য নির্দেশিকা',
      contentEn:
          'Compatibility depends on the transfused component: for Red Cells / Whole Blood, O- is the universal red-cell donor and AB+ is the universal recipient. For Plasma (FFP), compatibility is inverted — AB donors are universal plasma donors! Hospital laboratory cross-matching is mandatory prior to every transfusion.',
      contentBn:
          'রক্তের উপাদানের ওপর সামঞ্জস্য নির্ভর করে: লোহিত কণিকা বা সম্পূর্ণ রক্তের ক্ষেত্রে O- সর্বজনীন দাতা এবং AB+ সর্বজনীন গ্রহীতা। কিন্তু প্লাজমার ক্ষেত্রে AB গ্রুপ সর্বজনীন প্লাজমা দাতা। প্রতিটি রক্ত সঞ্চালনের আগে হাসপাতালে ল্যাব ক্রস-ম্যাচিং বাধ্যতামূলক।',
      category: 'Eligibility',
      order: 4,
      readTimeMinutes: 4,
      pointsValue: 5,
    ),
    ContentItem(
      id: '5e9b2d01-8888-4a8e-ae15-3932b6bf22c0',
      titleEn: 'Debunking Common Blood Donation Myths',
      titleBn: 'রক্তদান নিয়ে সাধারণ ভুল ধারণা ও সত্য',
      contentEn:
          'Myth 1: Donating blood causes permanent weakness. Fact: Plasma volume is restored within 24–48 hours and red blood cells within 4–8 weeks. Myth 2: You can contract an infection from donating. Fact: Licensed blood banks use sterile, single-use disposable collection kits for every donor.',
      contentBn:
          'ভুল ধারণা ১: রক্ত দিলে দীর্ঘমেয়াদী দুর্বলতা হয়। সত্য: ২৪–৪৮ ঘণ্টার মধ্যে প্লাজমা এবং কয়েক সপ্তাহের মধ্যে লোহিত কণিকা স্বাভাবিকভাবে পূরণ হয়ে যায়। ভুল ধারণা ২: রক্তদানে সংক্রমণের ঝুঁকি থাকে। সত্য: প্রতিটি দাতার জন্য সম্পূর্ণ নতুন জীবাণুমুক্ত ডিসপোজেবল ব্যাগ ও সূঁচ ব্যবহার করা হয়।',
      category: 'Myths & Facts',
      order: 5,
      readTimeMinutes: 4,
      pointsValue: 5,
    ),
    ContentItem(
      id: '6f0c3e12-7777-4a8e-ae15-3932b6bf22c1',
      titleEn: 'How Multi-Donor Fulfillment Saves Lives',
      titleBn: 'বহু-দাতা সহযোগিতার মাধ্যমে জীবন রক্ষা',
      contentEn:
          'Major surgeries, dengue platelet support, and trauma cases often require 2 to 6 units. Through RedCellNet multi-donor partial fulfillment, multiple verified volunteers can each pledge 1 unit toward a single hospital request until every required unit is safely fulfilled.',
      contentBn:
          'বড় অস্ত্রোপচার, ডেঙ্গু প্লাটিলেট সহায়তা বা দুর্ঘটনায় প্রায়ই ২ থেকে ৬ ব্যাগ রক্তের প্রয়োজন হয়। রেডসেলনেট মাল্টি-ডোনার ব্যবস্থায় একাধিক স্বেচ্ছাসেবী ১ ব্যাগ করে রক্ত দিয়ে রোগীর সম্পূর্ণ চাহিদা নিরাপদে পূরণ করতে পারেন।',
      category: 'Preparation',
      order: 6,
      readTimeMinutes: 3,
      pointsValue: 5,
    ),
  ];

  List<ContentItem> _applyFilter(List<ContentItem> items, String? categoryFilter) {
    if (categoryFilter == null || categoryFilter.isEmpty || categoryFilter == 'All') {
      return items;
    }
    return items
        .where((i) => i.category.toLowerCase().contains(categoryFilter.toLowerCase()))
        .toList();
  }

  Stream<List<ContentItem>> getContentStream({String? categoryFilter}) {
    return _getContentStreamImpl(categoryFilter: categoryFilter).asBroadcastStream();
  }

  Stream<List<ContentItem>> _getContentStreamImpl({String? categoryFilter}) async* {
    if (!SupabaseConfig.isInitialized) {
      yield _applyFilter(_fallbackGuides, categoryFilter);
      return;
    }

    try {
      final rows = await supabase
          .from('educational_content')
          .select()
          .order('order', ascending: true);

      if (rows.isNotEmpty) {
        final items = rows.map((r) => ContentItem.fromMap(r)).toList();
        yield _applyFilter(items, categoryFilter);
      } else {
        yield _applyFilter(_fallbackGuides, categoryFilter);
      }
    } catch (e) {
      debugPrint("Educational content REST notice: $e");
      yield _applyFilter(_fallbackGuides, categoryFilter);
    }

    try {
      final stream = supabase
          .from('educational_content')
          .stream(primaryKey: ['id'])
          .order('order', ascending: true)
          .handleError((e) {
            debugPrint("Handled educational content realtime stream error: $e");
          });

      await for (final rows in stream) {
        if (rows.isNotEmpty) {
          final items = rows.map((r) => ContentItem.fromMap(r)).toList();
          yield _applyFilter(items, categoryFilter);
        } else {
          yield _applyFilter(_fallbackGuides, categoryFilter);
        }
      }
    } catch (e) {
      debugPrint("Educational content realtime subscription fallback: $e");
    }
  }

  Future<ContentItem?> getContentItem(String docId) async {
    if (SupabaseConfig.isInitialized) {
      try {
        final res = await supabase
            .from('educational_content')
            .select()
            .eq('id', docId)
            .maybeSingle();

        if (res != null) {
          return ContentItem.fromMap(res);
        }
      } catch (e) {
        debugPrint("Error fetching content item $docId: $e");
      }
    }

    final fallback = _fallbackGuides.where((i) => i.id == docId);
    if (fallback.isNotEmpty) return fallback.first;
    return null;
  }

  /// Staff CRUD for Educational Content
  Future<void> saveContentItem({
    String? id,
    required String titleEn,
    required String titleBn,
    required String contentEn,
    required String contentBn,
    required String category,
    int order = 1,
    int readTimeMinutes = 3,
    int pointsValue = 5,
    String? imageUrl,
    String? sourceAttribution,
  }) async {
    final payload = <String, dynamic>{
      'title_en': titleEn.trim(),
      'title_bn': titleBn.trim(),
      'content_en': contentEn.trim(),
      'content_bn': contentBn.trim(),
      'category': category.trim(),
      'order': order,
      'read_time_minutes': readTimeMinutes,
      'points_value': pointsValue,
      'points': pointsValue,
      'image_url': imageUrl?.trim(),
      if (sourceAttribution != null && sourceAttribution.trim().isNotEmpty)
        'source_attribution': sourceAttribution.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (id != null && id.trim().isNotEmpty) {
      await supabase
          .from('educational_content')
          .update(payload)
          .eq('id', id.trim());
    } else {
      await supabase.from('educational_content').insert(payload);
    }

    try {
      await supabase.rpc('record_admin_log', params: {
        'p_action_type': id != null ? 'update_content' : 'create_content',
        'p_target_type': 'educational_content',
        'p_target_id': id,
        'p_details': {'title_en': titleEn.trim(), 'category': category.trim()},
      });
    } catch (_) {}
  }

  Future<void> deleteContentItem(String id) async {
    await supabase.from('educational_content').delete().eq('id', id);
    try {
      await supabase.rpc('record_admin_log', params: {
        'p_action_type': 'delete_content',
        'p_target_type': 'educational_content',
        'p_target_id': id,
      });
    } catch (_) {}
  }
}
